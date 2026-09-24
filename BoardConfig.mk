#
# TWRP BoardConfig for 小天才 (EEBBK) T1 平板
# Platform: Qualcomm SM6150 / sdmmagpie, Android 11, A-only + Dynamic Partitions
# Derived from stock boot.img / recovery.img headers (header_version 2, page 4096)
#
DEVICE_PATH := device/eebbk/t1

# ---------------- Architecture ----------------
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := kryo
TARGET_CPU_VARIANT_RUNTIME := kryo
TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv8-a
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := kryo
TARGET_2ND_CPU_VARIANT_RUNTIME := kryo
TARGET_USES_64_BIT_BINDER := true
TARGET_SUPPORTS_64_BIT_APPS := true
TARGET_BOARD_PLATFORM := sm6150
TARGET_BOOTLOADER_BOARD_NAME := sm6150
TARGET_BOARD_SUFFIX := _64
TARGET_OTA_ASSERT_DEVICE := t1,sm6150

# ---------------- 参考 EEBBK S6 (同 sm6150) 的 TWRP 设备树 ----------------
#
# 仓库：EEBBK-QMUR-Devs/android_device_eebbk_s6-TWRP  分支 twrp-11.0
#       DEVICE_PATH := device/eebbk/sm6150
#       TARGET_BOARD_PLATFORM := sm6150        ← 与本机同一颗 SoC
#
# 它的 BOARD_KERNEL_CMDLINE 与本机原厂**逐字节相同**，只有末尾一处差别：
#       S6   : ... loop.max_part=7 buildvariant=eng
#       T1   : ... loop.max_part=7 buildvariant=user
#
# ⚠️ 关于 buildvariant：S6 用 eng，但**下面保留 user**，原因如下——
#
#   唯一"能过 BL、进到内核"的实测镜像是 out/twrp_fix_small_avb.img，
#   它的 cmdline 是 **buildvariant=user**（与原厂一致）。
#   改成 eng 是我根据 S6 推断的**未经实测的改动**，会改变 cmdline，
#   而 cmdline 是唯一有实测依据的部分。**没有证据支持改它，就不改。**
#
#   （S6 能启动不一定是因为 eng；它的 kernel/AVB/包集/树都不同。
#    若将来确认需要 permissive，再单独验证，不要混在设备树里一起变。）
ALLOW_MISSING_DEPENDENCIES := true
OVERRIDE_TARGET_FLATTEN_APEX := true

# ---------------- Boot image format (from stock header) ----------------
# 原厂 cmdline（逐字节来自 in/recovery.img 的 boot header 0x40..0x240），
# 仅把末尾 buildvariant 从 user 改成 eng（对齐同 SoC 的 EEBBK S6 TWRP 树）。
# ⚠️ 这是**有意偏离**基准镜像（基准是 user）——用户明确要求保持 eng。
BOARD_KERNEL_CMDLINE := console=ttyMSM0,921600n8 androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 swiotlb=1 androidboot.usbcontroller=a600000.dwc3 earlycon=msm_geni_serial,0x880000 loop.max_part=7 buildvariant=eng

# ★★★ cmdline 追加项（按用户要求保留）★★★
#
# 注意：基准镜像 out/twrp_fix_small_avb.img 的 cmdline 是 buildvariant=user
# 且**没有**下面两项，所以这两项属于**有意偏离基准**的改动。
# 保留它们的理由：S6（同 sm6150）与 H7000/H110 三棵参考树都用了 permissive，
# 且 user 构建下 init 可能忽略它 —— 配合 buildvariant=eng 一起才有意义。
#
# 1) androidboot.selinux=permissive
#    本机 system/bin/init 里确有 `androidboot.selinux` 字符串，说明它会读这个
#    boot 参数；AOSP 里 permissive 通常还要求 init 编译期打开 SELINUX_DEVELOP
#    （userdebug/eng 才有）—— 这正是同时设 buildvariant=eng 的原因。
BOARD_KERNEL_CMDLINE += androidboot.selinux=permissive
#
# 2) androidboot.init_fatal_reboot_target=recovery
#    AOSP init 在 system/core/init/reboot_utils.cpp: GetFatalRebootTarget()
#    读它；默认是 reboot（→ bootloader/fastboot），正对应"刷完就回 bl"。
#    设成 recovery 让致命失败留在 recovery 侧，便于观察。
BOARD_KERNEL_CMDLINE += androidboot.init_fatal_reboot_target=recovery

BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x01000000
BOARD_KERNEL_TAGS_OFFSET := 0x00000100
# ⚠️ DTB 地址保持原厂的 0x01f00000，但 ramdisk 必须压到 15 MB 以下！
#
# 实测（2026-09）：
#   ramdisk_addr = 0x01000000，dtb_addr = 0x01f00000，两者相距
#   0xf00000 = 15,728,640 字节。
#   TWRP 的 ramdisk 原本压缩后 17,097,595 字节，从 0x01000000 排到
#   0x0204E37B（32.3 MB），把 0x01f00000（31.0 MB）包在里面 —— 重叠 1.31 MB。
#   ABL 装载 ramdisk 后会把 DTB memmove 到 dtb_addr（实测它忽略 header 里
#   改过的 dtb_addr，硬用 0x1f00000），于是覆盖 ramdisk 尾部，gzip 流损坏
#   → 内核解包 initramfs 失败 → panic → ABL 看门狗超时 → 回 bootloader
#   （现象：闪一下 logo 就进 bootloader）。原厂 ramdisk 只 8.4 MB，碰不到。
#
# 结论：不要改 dtb_addr（改了没用），而是把 ramdisk 压到 15 MB 以内。
#   配合下面的 TW_EXTRA_LANGUAGES := false / TW_EXCLUDE_BASH := true 实现。
#   刷机前务必用 tools/check_ramdisk.py 复核体积。
BOARD_DTB_OFFSET := 0x01f00000
BOARD_BOOTIMG_HEADER_VERSION := 2
BOARD_MKBOOTIMG_ARGS += --header_version 2
BOARD_MKBOOTIMG_ARGS += --base 0x00000000 --kernel_offset 0x00008000
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset 0x01000000 --tags_offset 0x00000100
BOARD_MKBOOTIMG_ARGS += --dtb_offset 0x01f00000 --pagesize 4096

# ---------------- Kernel / DTB / DTBO (prebuilt, stock) ----------------
# DTB 写法对齐 EEBBK S6（device/eebbk/sm6150）：
#     TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
#     TARGET_PREBUILT_DTB    := $(DEVICE_PATH)/prebuilt/dtb.img
#     BOARD_MKBOOTIMG_ARGS  += --dtb $(TARGET_PREBUILT_DTB)
#     BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img
# 这样 dtb 由 mkbootimg 显式拼进 boot 镜像，而不是靠 BOARD_PREBUILT_DTBIMAGE_DIR
# 的目录拼接（后者在不同 manifest 上行为不一致，且 S6 用的是前者）。
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilt/dtb.img
BOARD_MKBOOTIMG_ARGS += --dtb $(TARGET_PREBUILT_DTB)
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img
BOARD_INCLUDE_RECOVERY_DTBO := true
BOARD_KERNEL_IMAGE_NAME := Image.gz

# ---------------- Partition sizes (from stock dumps) ----------------
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 100663296
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_USES_METADATA_PARTITION := true
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs

# Dynamic partitions —— 构建期全部注释掉！
# 实测：只要它们生效，AOSP 就会在 boot ramdisk 根目录创建 `vendor` 软链，
# 与 TWRP 预编译 HAL 已占用的 recovery/root/vendor 目录冲突，导致
#   FAILED: out/target/product/t1/ramdisk-recovery.cpio
#   could not make way for new symlink: root/vendor
# TWRP 运行时用 liblp 直接读 /dev/block/by-name/super，构建期不需要这些值。
# 设备实测值（备查）：super = 0x180000000 = 6442450944
#BOARD_SUPER_PARTITION_SIZE := 6442450944
#BOARD_SUPER_PARTITION_GROUPS := qti_dynamic_partitions
#BOARD_QTI_DYNAMIC_PARTITIONS_SIZE := 6438256640
# 分区列表里含 vendor 正是让 AOSP 造 vendor 软链的元凶，一并注释
#BOARD_QTI_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext product vendor

# ---------------- AVB ----------------
# ★ 开启 AVB —— 对齐唯一"能过 BL"的基准镜像 out/twrp_fix_small_avb.img ★
#
# 实测逐字节对比（tools/diff_vs_baseline.py）显示，我们的构建与那个能过 BL 的
# 基准之间，**唯一的实质结构差异**就是 AVB：
#
#   A（我们的，BOARD_AVB_ENABLE=false）
#       尾部没有 AVBf；全镜像找不到任何 AVB0
#   B（能过 BL 的基准）
#       尾部 @0x5ffffc0 有 AVBf footer
#       且 @0x1854000 (= 25 509 888) 内嵌着完整的 AVB0 vbmeta 结构
#       —— 正是 footer 里 vbmeta_offset 指向的位置
#
# ABL 读 AVB footer 后会按 vbmeta_offset 去读 vbmeta 结构。B 提供了一个它能
# 正确解析的内嵌结构；A 什么都没有。这就是差别。
#
# 所以必须让**构建自己产出**这个结构（不能手工塞原厂 footer：我们的 ramdisk
# 更大，footer/vbmeta 的位置会随之改变，必须由 avbtool 重新计算）。
#
# 参数照搬同 SoC 的 EEBBK S6 TWRP 树（device/eebbk/sm6150）：
#     BOARD_AVB_ENABLE := true
#     BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
#     BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
#     BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
#     BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1
#
# 副作用（都是我们要的）：
#   1) 构建会把 recovery.img pad 到分区大小 100663296（我们手工 pad 过，
#      但由构建做更可靠）
#   2) 会在分区尾写出合法的 AVB footer + 内嵌 vbmeta
#
# 注意：这里**不设** BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3。
# S6 写了这一条，但 AOSP avbtool 把 HASHTREE_DISABLED|VERIFICATION_DISABLED
# (0x3) 判定为非法组合；我们保持默认 flags=0。
BOARD_AVB_ENABLE := true
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA4096
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1
# boot/vbmeta 也用同一把测试密钥，避免只有 recovery 单独启用时参数不完整
BOARD_AVB_KEY_PATH := external/avb/test/data/testkey_rsa4096.pem
BOARD_AVB_ALGORITHM := SHA256_RSA4096
BOARD_AVB_ROLLBACK_INDEX := 1
# 不要再手工 pad：BOARD_AVB_ENABLE=true 时构建自己会 pad 到分区大小
# （手工 pad 过再让 avbtool 加 footer 会得到错位的结构）

# ---------------- Recovery ----------------
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := "RGBX_8888"
TARGET_RECOVERY_DEVICE_MODULES :=
TARGET_USES_MKE2FS := true
TARGET_RECOVERY_UI_MARGIN_HEIGHT := 0
BOARD_USES_RECOVERY_AS_BOOT := false
BOARD_BUILD_SYSTEM_ROOT_IMAGE := false

# ---------------- TWRP ----------------
# TWRP-11 只内置这 5 套主题：landscape_hdpi / landscape_mdpi / portrait_hdpi /
# portrait_mdpi / watch_mdpi。写 portrait_xhdpi 会直接让 soong 报：
#   Could not find ui.xml for TW_THEME: portrait_xhdpi
# 面板是 2176x1600 横屏资产，竖屏 framebuffer 为 1600x2176，
# 高度 >= 1920 走 hdpi 主题；同时给出 TARGET_SCREEN_* 让 TWRP 自动判定。
TW_THEME := portrait_hdpi
TARGET_SCREEN_WIDTH := 1600
TARGET_SCREEN_HEIGHT := 2176
DEVICE_RESOLUTION := 1600x2176
TW_ROTATION := 0
TW_BRIGHTNESS_PATH := /sys/class/backlight/panel0-backlight/brightness
TW_MAX_BRIGHTNESS := 3925
TW_DEFAULT_BRIGHTNESS := 1950
TW_SCREEN_BLANK_ON_BOOT := true
TW_NO_SCREEN_TIMEOUT := true
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_TOOLBOX := true
TW_EXCLUDE_TWRPAPP := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_EXCLUDE_APEX := true
TW_EXCLUDE_BASH := true
# ★ 必须关掉！开启后会塞进 3.7MB 的 DroidSansFallback 字体和一堆语言包，
#   ramdisk 压缩后冲到 17MB > 15,728,640 上限，尾部会被 DTB 覆盖 → 必 panic。
#   中文显示由 twres/fonts/NotoSansCJKjp-Regular.ttf 兜底。
TW_EXTRA_LANGUAGES := false
TW_HAS_EDL_MODE := true
TW_USE_MODEL_HARDWARE_ID_FOR_DEVICE_ID := true
TW_DEVICE_VERSION := eebbk-t1
TW_SKIP_ADDITIONAL_FSTAB := false
RECOVERY_SDCARD_ON_DATA := true

# Extra partition names TWRP should know about even if unmounted
# （已删除重复的 TW_EXTRA_LANGUAGES := true —— 它会覆盖上面的 false 并让 ramdisk 超限）

# Kernel modules: recovery needs none (kernel is monolithic; stock recovery has no .ko)
