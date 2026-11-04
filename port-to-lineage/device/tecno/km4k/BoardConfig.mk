#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# TECNO SPARK 40C (KM4k) — параметры конкретного устройства.
#
# Образец: LineageOS/android_device_motorola_lamu (lineage-24.0), тот же SoC MT6768.

DEVICE_PATH := device/tecno/km4k
KERNEL_PATH := $(DEVICE_PATH)-kernels

# DTBO
BOARD_KERNEL_SEPARATED_DTBO := true

# Partitions
# ВНИМАНИЕ: размер super-раздела TECNO может отличаться. Проверьте:
#   fastboot getvar super_partition_size   (или из стоковой прошивки)
BOARD_SUPER_PARTITION_SIZE := 8589934592

# Inherit from common tree
include device/tecno/mt6768-common/BoardConfigCommon.mk

# Display
# 720×1600, 263 ppi → системная плотность 320 (xhdpi) → 360×800 dp
TARGET_SCREEN_DENSITY := 320

# Kernel
# ВНИМАНИЕ: значения ниже — из дерева Motorola (moto g15). Для KM4k имена файлов
# берите из стоковой прошивки (boot.img, dtbo.img, список .ko).
TARGET_KERNEL_DEVICE := km4k
TARGET_KERNEL_DIR := $(KERNEL_PATH)/6.6
TARGET_KERNEL_PLATFORM_SOURCE := tecno_km4k
TARGET_PROVIDES_STATIC_MODULE_LISTS := true

BOARD_SYSTEM_KERNEL_MODULES_LOAD := $(strip $(shell cat $(TARGET_KERNEL_DIR)/system_dlkm.modules.load))
BOARD_VENDOR_KERNEL_MODULES_LOAD := $(strip $(shell cat $(TARGET_KERNEL_DIR)/vendor_dlkm.modules.load))
BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD := $(strip $(shell cat $(TARGET_KERNEL_DIR)/vendor_ramdisk.modules.load))
BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD := $(strip $(shell cat $(TARGET_KERNEL_DIR)/vendor_ramdisk.modules.load.recovery))

BOARD_KERNEL_MODULE_DIR := $(TARGET_KERNEL_DIR)
BOARD_PREBUILT_DTBIMAGE_DIR := $(TARGET_KERNEL_DIR)
BOARD_PREBUILT_DTBOIMAGE := $(TARGET_KERNEL_DIR)/dtbo.img
TARGET_PREBUILT_KERNEL := $(TARGET_KERNEL_DIR)/$(BOARD_KERNEL_IMAGE_NAME)
TARGET_PREBUILT_KERNEL_HEADERS := $(TARGET_KERNEL_DIR)/kernel-uapi-headers.tar.gz

ALL_VENDOR_RAMDISK_MODULES := $(sort $(BOARD_VENDOR_RAMDISK_KERNEL_MODULES_LOAD) $(BOARD_VENDOR_RAMDISK_RECOVERY_KERNEL_MODULES_LOAD))
BOARD_SYSTEM_KERNEL_MODULES := $(addprefix $(BOARD_KERNEL_MODULE_DIR)/,$(BOARD_SYSTEM_KERNEL_MODULES_LOAD))
BOARD_VENDOR_KERNEL_MODULES := $(addprefix $(BOARD_KERNEL_MODULE_DIR)/,$(BOARD_VENDOR_KERNEL_MODULES_LOAD))
BOARD_VENDOR_RAMDISK_KERNEL_MODULES := $(addprefix $(BOARD_KERNEL_MODULE_DIR)/,$(ALL_VENDOR_RAMDISK_MODULES))

# Модули из стоковой прошивки KM4k (список уточните по `lsmod` на телефоне).
BOARD_VENDOR_KERNEL_MODULES += \
    $(BOARD_KERNEL_MODULE_DIR)/fmradio_drv_mt6631.ko \
    $(BOARD_KERNEL_MODULE_DIR)/gps_drv_stp.ko \
    $(BOARD_KERNEL_MODULE_DIR)/wlan_drv_gen4m_6768.ko \
    $(BOARD_KERNEL_MODULE_DIR)/wmt_chrdev_wifi.ko \
    $(BOARD_KERNEL_MODULE_DIR)/wmt_drv.ko

# Properties
TARGET_PRODUCT_PROP += $(DEVICE_PATH)/product.prop
TARGET_ODM_PROP += $(DEVICE_PATH)/odm.prop
TARGET_VENDOR_PROP += $(DEVICE_PATH)/vendor.prop

# Recovery
TARGET_RECOVERY_DENSITY := xhdpi

# Inherit the proprietary files
include vendor/tecno/km4k/BoardConfigVendor.mk
