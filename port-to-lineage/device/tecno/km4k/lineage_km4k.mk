#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# TECNO SPARK 40C (KM4k) — продукт LineageOS.
#
# Образец: LineageOS/android_device_motorola_lamu (lineage-24.0), тот же SoC MT6768.

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit from device makefile.
$(call inherit-product, device/tecno/km4k/device.mk)

# Inherit some common LineageOS stuff.
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

PRODUCT_NAME := lineage_km4k
PRODUCT_DEVICE := km4k
PRODUCT_MANUFACTURER := tecno
PRODUCT_BRAND := tecno
PRODUCT_MODEL := TECNO SPARK 40C

PRODUCT_GMS_CLIENTID_BASE := android-tecno

# ВНИМАНИЕ: значения ниже — из стоковой прошивки. Возьмите точные:
#   adb shell getprop ro.build.fingerprint
#   adb shell getprop ro.build.version.incremental
PRODUCT_BUILD_PROP_OVERRIDES += \
    BuildDesc="km4k-user 15 UP1A.231005.007 1234567 release-keys" \
    BuildFingerprint=tecno/km4k/km4k:15/UP1A.231005.007/1234567:user/release-keys \
    DeviceProduct=km4k \
    SystemName=km4k
