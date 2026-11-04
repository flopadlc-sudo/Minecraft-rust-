#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# TECNO SPARK 40C (KM4k) — общие параметры платы.
#
# За основу взят LineageOS/android_device_motorola_mt6768-common (lineage-24.0):
# тот же SoC MT6768. Всё, что специфично для Motorola (имена разделов, SKU, bootloader),
# заменено на TECNO — по фактическим данным из стоковой прошивки KM4k.
#
# ВНИМАНИЕ: значения ниже — стартовые. Перед первой сборкой сверьте их с `fastboot getvar all`
# и с разделом, вытащенным из заводской прошивки KM4k.

COMMON_PATH := device/tecno/mt6768-common

# A/B
AB_OTA_UPDATER := true
# ВНИМАНИЕ: список разделов у TECNO может отличаться (имена Transsion). Сверьте с fastboot.
AB_OTA_PARTITIONS := \
    boot \
    dtbo \
    init_boot \
    odm \
    odm_dlkm \
    product \
    system \
    system_dlkm \
    system_ext \
    vbmeta \
    vbmeta_system \
    vbmeta_vendor \
    vendor \
    vendor_boot \
    vendor_dlkm

# Architecture
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-2a-dotprod
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a75

# Boot Image
BOARD_KERNEL_BASE              := 0x40078000
BOARD_KERNEL_OFFSET            := 0x00008000
BOARD_KERNEL_PAGESIZE          := 4096
BOARD_RAMDISK_OFFSET           := 0x07c08000
BOARD_KERNEL_TAGS_OFFSET       := 0x0bc08000
BOARD_DTB_OFFSET               := 0x0bc08000
BOARD_BOOT_HEADER_VERSION      := 4
BOARD_INIT_BOOT_HEADER_VERSION := $(BOARD_BOOT_HEADER_VERSION)

BOARD_KERNEL_IMAGE_NAME := Image.gz

BOARD_INCLUDE_DTB_IN_BOOTIMG := true

BOARD_RAMDISK_USE_LZ4 := true
BOARD_USES_GENERIC_KERNEL_IMAGE := true
BOARD_MOVE_GSI_AVB_KEYS_TO_VENDOR_BOOT := true

BOARD_MKBOOTIMG_ARGS := --base $(BOARD_KERNEL_BASE)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --pagesize $(BOARD_KERNEL_PAGESIZE)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)

BOARD_MKBOOTIMG_INIT_ARGS += --header_version $(BOARD_INIT_BOOT_HEADER_VERSION)

# ВНИМАНИЕ: командная строка ядра — из стоковой прошивки KM4k.
# Взять: fastboot boot boot.img && adb shell cat /proc/cmdline
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2
BOARD_KERNEL_CMDLINE += androidboot.serialconsole=0

# Bootloader
BOARD_VENDOR := tecno
TARGET_BOOTLOADER_BOARD_NAME := mt6768
TARGET_NO_BOOTLOADER := true

# Display
TARGET_USES_VULKAN := true

# HIDL
DEVICE_MANIFEST_FILE := $(COMMON_PATH)/manifest.xml

# ODM
# SKU-наборы TECNO: заполните по фактическим SKU (см. product.prop и /vendor/etc/prop/).
ODM_MANIFEST_SKUS := \
    dsds \
    ss \
    nonfc_dsds \
    nonfc_ss

ODM_MANIFEST_DSDS_FILES       := $(COMMON_PATH)/odm/manifest_dsds.xml
ODM_MANIFEST_SS_FILES         := $(COMMON_PATH)/odm/manifest_ss.xml
ODM_MANIFEST_NONFC_DSDS_FILES := $(COMMON_PATH)/odm/manifest_dsds.xml $(COMMON_PATH)/odm/manifest_nonfc.xml
ODM_MANIFEST_NONFC_SS_FILES   := $(COMMON_PATH)/odm/manifest_ss.xml $(COMMON_PATH)/odm/manifest_nonfc.xml

# Partitions
BOARD_FLASH_BLOCK_SIZE := 262144 # (BOARD_KERNEL_PAGESIZE * 64)
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864

BOARD_TECNO_DYNAMIC_PARTITIONS_PARTITION_LIST := odm odm_dlkm product system system_dlkm system_ext vendor vendor_dlkm
BOARD_TECNO_DYNAMIC_PARTITIONS_SIZE :=  $(shell expr $(BOARD_SUPER_PARTITION_SIZE) - 4194304) # (минус 4 МиБ на накладные расходы)
BOARD_SUPER_PARTITION_GROUPS := tecno_dynamic_partitions

BOARD_ODMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs

TARGET_COPY_OUT_ODM := odm
TARGET_COPY_OUT_ODM_DLKM := odm_dlkm
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_SYSTEM_DLKM := system_dlkm
