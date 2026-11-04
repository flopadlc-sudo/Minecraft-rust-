#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# TECNO SPARK 40C (KM4k) — общие куски для всех SKU.
#
# Этот файл подключается через lineage_km4k.mk и используется, когда у устройства
# несколько вариантов (памяти/SIM). Для одной конфигурации он может остаться пустым,
# но подключение из lineage_km4k.mk уберите.

# Пример для будущих SKU:
#
# PRODUCT_COPY_FILES += \
#     $(call find-copy-subdir-files,*,$(LOCAL_PATH)/sku/sku_a,$(TARGET_COPY_OUT_PRODUCT)/etc/prop)
#
# PRODUCT_PROPERTY_OVERRIDES += \
#   ro.boot.hardware.sku=sku_a
