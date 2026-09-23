LOCAL_PATH := device/eebbk/t1

# Runtime overlay files that must land in the recovery ramdisk
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/init.recovery.qcom.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.qcom.rc \
    $(LOCAL_PATH)/recovery/root/system/etc/twrp.flags:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/twrp.flags

# ---------------------------------------------------------------------------
# ★★ CRITICAL — the recovery ramdisk must be SELF-CONSISTENT ★★
#
# TWRP-11's generated system/etc/init/hw/init.rc has SEVEN `import` lines:
#
#     import /init.recovery.logd.rc
#     import /init.recovery.ldconfig.rc
#     import /init.recovery.mksh.rc
#     import /init.recovery.usb.rc
#     import /init.recovery.service.rc
#     import /init.recovery.vold_decrypt.rc
#     import /init.recovery.${ro.hardware}.rc
#
# AOSP init's parser treats an unreadable `import` as a FATAL parse error and
# calls init.abort(); the init binary here even carries the literal string
# "Could not import directory '%s'". The failure chain is:
#
#     init aborts -> kernel panic ("Attempted to kill init!")
#     -> bootloader watchdog resets after ~8 s -> endless loop / fastboot
#
# The minimal manifest used by .github/workflows/build-twrp.yml
# (platform_manifest_twrp_aosp / twrp-11) only ships SOME of those files, so
# the build used to depend on luck. We now ship ALL of them from the device
# tree so the ramdisk is self-consistent no matter which manifest is used.
#
# The only file that also comes from TWRP is init.recovery.hlthchrg.rc (not
# imported by init.rc, so it does not matter either way) - we ship it too.
#
# Verify any built image with:
#     python tools/extract_rd.py <recovery.img> /tmp/rd.pkl
#     python tools/rc_import_check.py /tmp/rd.pkl      # must print 7/7 OK
# The CI workflow runs exactly this and fails the build on a MISSING import.
#
# NOTE ON CONTENT: the four files below are intentionally near-EMPTY (comments
# only). An empty .rc is valid and adds no behaviour. They exist purely to
# satisfy the imports. See each file's header for the reasoning.
# ---------------------------------------------------------------------------
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/init.recovery.logd.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.logd.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.mksh.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mksh.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.usb.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.usb.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.vold_decrypt.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.vold_decrypt.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.ldconfig.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.ldconfig.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.service.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.service.rc \
    $(LOCAL_PATH)/recovery/root/init.recovery.hlthchrg.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.hlthchrg.rc

# ---------------------------------------------------------------------------
# 不要设置 PRODUCT_USE_DYNAMIC_PARTITIONS / PRODUCT_BUILD_SUPER_PARTITION！
#
# 实测（2026-09 GitHub Actions）：
#   一旦设为 true，AOSP 会把 /vendor 当成独立分区，并在 boot ramdisk 根目录
#   创建 `vendor` 软链。而 TWRP 自己的预编译 HAL 已经把 recovery 根目录下的
#   vendor/ 建成了非空目录：
#       bootable/recovery/prebuilt/Android.mk:399: vendor_hw: relink.sh .../recovery/root/vendor/bin/hw
#       Install: .../recovery/root/vendor/etc/vintf/manifest/android.hardware.health@2.1.xml
#   组装 ramdisk 时执行
#       rsync -a ... out/target/product/t1/root out/target/product/t1/recovery
#   就报：
#       could not make way for new symlink: root/vendor
#       cannot delete non-empty directory: root/vendor
#       rsync error: ... (code 23)
#       FAILED: out/target/product/t1/ramdisk-recovery.cpio
#
# TWRP 在运行时用 liblp 自己读 /dev/block/by-name/super 来映射 logical 分区，
# 构建期根本不需要这两个变量。
# ---------------------------------------------------------------------------

# Device props used by the recovery UI / adb
PRODUCT_PROPERTY_OVERRIDES += \
    ro.hardware=qcom \
    ro.board.platform=sm6150

# ---------------------------------------------------------------------------
# 参考 EEBBK S6 (device/eebbk/sm6150/device.mk) —— 同 sm6150 的 TWRP 树
#
# S6 的 device.mk 只做一件事：把 bootctrl HAL 和 update_engine 相关包塞进去。
# 对 A-only + dynamic partitions 的设备，recovery 里没有 bootctrl 会导致
# TWRP 无法读取/切换 slot 信息（A/B 设备必需；A-only 上影响较小，但 TWRP
# 的 boot 分区操作、A/B 探测、以及 fastbootd 的某些路径会用到）。
# update_engine/update_verifier 是 TWRP 做 OTA sideload 的依赖。
#
# 下面按 S6 原样列出，并用 ALLOW_MISSING_DEPENDENCIES=true 兜底
# （BoardConfig 里已设），个别包在精简 manifest 上不存在也不会中断构建。
# ---------------------------------------------------------------------------
PRODUCT_PACKAGES += \
    android.hardware.boot@1.1-impl \
    android.hardware.boot@1.1-service \
    android.hardware.boot@1.1.recovery \
    bootctrl.sm6150 \
    bootctrl.sm6150.recovery \
    bootctrl

PRODUCT_PACKAGES += \
    update_engine \
    update_engine_sideload \
    update_verifier \
    checkpoint_gc
