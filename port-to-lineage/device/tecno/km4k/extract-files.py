#!/usr/bin/env -S PYTHONPATH=../../../tools/extract-utils python3
#
# SPDX-FileCopyrightText: The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#
# Вытягивание проприетарных блобов TECNO SPARK 40C (KM4k) с телефона.
#
# Как пользоваться (нужен разблокированный загрузчик и root через adb):
#   1. Включите на телефоне «Для разработчиков» → «Отладка по USB».
#   2. Подключите телефон, подтвердите доверие, проверьте: adb devices
#   3. Скопируйте этот файл в device/tecno/km4k/extract-files.py
#   4. Заполните proprietary-files.txt (шаблон лежит рядом).
#   5. Запустите из корня исходников:
#          ./device/tecno/km4k/extract-files.py
#      Файлы появятся в vendor/tecno/km4k/.
#
# ВАЖНО: блобы — проприетарные файлы TECNO. Для личного использования это обычная
# практика LineageOS, но публиковать их в публичном репозитории нельзя.

from extract_utils.fixups_blob import (
    blob_fixup,
    blob_fixups_user_type,
)
from extract_utils.main import (
    ExtractUtils,
    ExtractUtilsModule,
)

namespace_imports = [
    'device/tecno/km4k',
    'hardware/mediatek',
    'hardware/mediatek/libion_mtk',
    'vendor/tecno/mt6768-common',
]

# Фиксы блобов: подставляются по мере того, как выясняется, что не собирается.
# Образец из LineageOS/android_device_motorola_lamu (lineage-24.0) — тот же SoC,
# поэтому часть фиксов скорее всего понадобится и здесь.
blob_fixups: blob_fixups_user_type = {
    'vendor/lib64/hw/audio.primary.mt6768.so': blob_fixup()
        .replace_needed('libtinyxml2.so', 'libtinyxml2-v34.so')
        .binary_regex_replace(b'A2dpsuspendonly', b'A2dpSuspended\x00\x00')
        .binary_regex_replace(b'BTAudiosuspend', b'A2dpSuspended\x00'),
    'vendor/lib64/libBSTSWAD.so': blob_fixup()
        .clear_symbol_version('AHardwareBuffer_allocate')
        .clear_symbol_version('AHardwareBuffer_describe')
        .clear_symbol_version('AHardwareBuffer_lock')
        .clear_symbol_version('AHardwareBuffer_lockPlanes')
        .clear_symbol_version('AHardwareBuffer_release')
        .clear_symbol_version('AHardwareBuffer_unlock'),
    (
        'vendor/lib64/vendor.mediatek.hardware.camera.isphal-V1-ndk.so',
        'vendor/lib64/libmtkcam_grallocutils.so'
    ): blob_fixup()
        .replace_needed('android.hardware.graphics.common-V5-ndk.so', 'android.hardware.graphics.common-V7-ndk.so'),
    'vendor/lib64/libmtkcam_hal_aidl_common.so': blob_fixup()
        .replace_needed('android.hardware.camera.common-V2-ndk.so', 'android.hardware.camera.common-V1-ndk.so'),
    'vendor/lib64/libcam.utils.sensorprovider.so': blob_fixup()
        .replace_needed('android.hardware.sensors-V2-ndk.so', 'android.hardware.sensors-V3-ndk.so'),
}  # fmt: skip

module = ExtractUtilsModule(
    'km4k',
    'tecno',
    blob_fixups=blob_fixups,
    namespace_imports=namespace_imports,
    add_firmware_proprietary_file=True,
)

if __name__ == '__main__':
    utils = ExtractUtils.device_with_common(
        module, 'mt6768-common', module.vendor
    )
    utils.run()
