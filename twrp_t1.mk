#
# TWRP product definition — 小天才 T1 (EEBBK / sm6150 / sdmmagpie) — Android 11
#
# 关键教训（2026-09 实测）：
#   1) 直接 inherit embedded.mk 会在 lunch 阶段报
#        "build/make/target/product/embedded.mk" does not exist
#      因为该文件在较新的 AOSP 里已被删除。
#   2) 但如果为了绕开 1) 而把 base.mk / core_64_bit.mk 一起删掉，
#      PRODUCT_PACKAGES 的基线就没了 —— recovery ramdisk 会变成一个
#      **只有 twres 主题和 PNG、没有任何二进制**的空壳（system/bin/init
#      都不存在），烧进去后内核找不到 init → panic → ABL 回退 fastboot。
#
# 参考同类设备树后的修正（见 REFERENCE_TREES.md）：
#
#   ★ EEBBK S6 (同 sm6150) — EEBBK-QMUR-Devs/android_device_eebbk_s6-TWRP
#                            device/eebbk/sm6150/twrp_sm6150.mk
#         inherit-product core_64_bit.mk
#         inherit-product full_base_telephony.mk
#         inherit-product vendor/twrp/config/common.mk
#         inherit-product device/eebbk/sm6150/device.mk
#
#   EEBBK H110 (twrp-11)     → full_base_telephony.mk + core_64_bit.mk
#   EEBBK S5/H7000 (lineage) → full_base.mk + core_64_bit.mk
#
# 三棵参考树全部用 **full_base***，本树原先是 base.mk。这不是小事：
# full_base.mk 在 base 之外还拉进 AOSP 的完整核心包集（recovery 侧需要的
# 若干 HAL/服务/工具），base.mk 只是一小撮最基础的东西。
#
# 这里直接对齐 S6（同为 sm6150 的 TWRP 树），用 full_base_telephony.mk。
# 保留 inherit-product-if-exists 作为兜底，防止某些 manifest 缺文件时 lunch 报错。
$(call inherit-product-if-exists, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product-if-exists, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)
$(call inherit-product-if-exists, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product-if-exists, $(SRC_TARGET_DIR)/product/base.mk)
$(call inherit-product-if-exists, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, vendor/twrp/config/common.mk)
$(call inherit-product, device/eebbk/t1/device.mk)

# 保险：把 recovery ramdisk 必需的几个核心模块显式列出来。
# 即使上面的 base 继承链在某些 manifest 上不完整，也不会再出现空 ramdisk。
PRODUCT_PACKAGES += \
    init \
    recovery \
    toolbox \
    toybox \
    linker \
    linker64 \
    adbd.recovery \
    libc \
    libc++ \
    libbase \
    libcutils \
    libutils \
    liblog \
    libselinux \
    mke2fs \
    e2fsdroid

PRODUCT_DEVICE := t1
PRODUCT_NAME := twrp_t1
PRODUCT_BRAND := EEBBK
PRODUCT_MODEL := T1
PRODUCT_MANUFACTURER := EEBBK
PRODUCT_RELEASE_NAME := T1
