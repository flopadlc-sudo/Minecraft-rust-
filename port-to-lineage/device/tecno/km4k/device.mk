#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# TECNO SPARK 40C (KM4k) — продукт.
#
# Образец: LineageOS/android_device_motorola_lamu (lineage-24.0), тот же SoC MT6768.

# Display
TARGET_SCREEN_WIDTH := 720
TARGET_SCREEN_HEIGHT := 1600

# Overlays
# ВНИМАНИЕ: имена оверлеев — из дерева Motorola. Под TECNO свои:
#   device/tecno/km4k/rro_overlays/…
# PRODUCT_PACKAGES += \
#     FrameworkOverlayKm4k \
#     SystemUIOverlayKm4k

# Shipping API Level
BOARD_SHIPPING_API_LEVEL := 202508
PRODUCT_SHIPPING_API_LEVEL := 35

# SKU properties
PRODUCT_COPY_FILES += \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/sku/product,$(TARGET_COPY_OUT_PRODUCT)/etc/prop) \
    $(call find-copy-subdir-files,*,$(LOCAL_PATH)/sku/odm,$(TARGET_COPY_OUT_ODM)/etc/prop)

# Soong namespaces
PRODUCT_SOONG_NAMESPACES += \
    $(LOCAL_PATH)

# SPL
BOOT_SECURITY_PATCH := 2026-08-05
INIT_BOOT_SECURITY_PATCH := $(BOOT_SECURITY_PATCH)
VENDOR_SECURITY_PATCH := $(BOOT_SECURITY_PATCH)

# Inherit from common tree
$(call inherit-product, device/tecno/mt6768-common/mt6768.mk)

# Inherit the proprietary files
$(call inherit-product, vendor/tecno/km4k/km4k-vendor.mk)
