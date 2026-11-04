#!/usr/bin/env bash
# Тестовый стенд: подменяет adb имитацией телефона TECNO KM4k.
# Используется только для проверки логики скриптов комплекта, телефон не нужен.
set -uo pipefail

MOCK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/mock-bin"
mkdir -p "$MOCK_DIR"

cat > "$MOCK_DIR/adb" <<'MOCK'
#!/usr/bin/env bash
# Имитация adb: отвечает на getprop/shell-команды как телефон TECNO SPARK 40C.
STATE_DIR="${MOCK_STATE_DIR:-/tmp/mock-adb-state}"
mkdir -p "$STATE_DIR"

case "${1:-}" in
  devices)
    printf 'List of devices attached\nKM4K123456\tdevice\n\n'
    exit 0
    ;;
  -s) shift 2 ;;
esac

args=()
for a in "$@"; do args+=("$a"); done

# Лог всех вызовов — чтобы тесты могли проверить, что именно уходит на телефон.
if [[ -n "${MOCK_LOG:-}" ]]; then
    printf '%s\n' "$*" >> "$MOCK_LOG"
fi

# shell <команда>
if [[ "${args[0]:-}" == "shell" ]]; then
    cmd="${args[*]:1}"
    case "$cmd" in
      *"getprop ro.product.model"*)            echo "TECNO KM4k" ;;
      *"getprop ro.product.device"*)           echo "KM4k" ;;
      *"getprop ro.product.manufacturer"*)     echo "TECNO" ;;
      *"getprop ro.build.version.release"*)    echo "15" ;;
      *"getprop ro.build.version.sdk"*)        echo "35" ;;
      *"getprop ro.board.platform"*)           echo "mt6768" ;;
      *"getprop ro.hardware"*)                 echo "mt6768" ;;
      *"getprop ro.treble.enabled"*)           echo "true" ;;
      *"getprop ro.product.cpu.abi"*)          echo "arm64-v8a" ;;
      *"getprop ro.product.cpu.abilist"*)      echo "arm64-v8a,armeabi-v7a,armeabi" ;;
      *"getprop ro.boot.dynamic_partitions"*)  echo "true" ;;
      *"getprop ro.vndk.version"*)             echo "34" ;;
      *"getprop ro.vendor.build.version.sdk"*) echo "35" ;;
      *"getprop ro.boot.flash.locked"*)        echo "0" ;;
      *"getprop ro.boot.verifiedbootstate"*)   echo "orange" ;;
      *"getprop ro.build.version.security_patch"*) echo "2026-08-05" ;;
      *"getprop ro.build.display.id"*)         echo "KM4k-user 15 UP1A.231005.007" ;;
      *"getprop ro.vendor.build.display.id"*)  echo "KM4k-user 15 UP1A.231005.007" ;;
      *"getprop ro.system.build.version.sdk"*)  echo "35" ;;
      *"getprop ro.product.property_source_order"*) echo "odm,product,vendor,system_ext,system" ;;
      *"getprop "*)
        # Один конкретный ключ: getprop <key> -> значение или пусто.
        KEY="${cmd##*getprop }"
        KEY="${KEY// /}"
        case "$KEY" in
          ro.boot.flash.locked)          echo "0" ;;
          ro.boot.verifiedbootstate)     echo "orange" ;;
          ro.boot.dynamic_partitions)    echo "true" ;;
          ro.build.display.id)           echo "KM4k-user 15 UP1A.231005.007" ;;
          ro.build.version.release)      echo "15" ;;
          ro.build.version.sdk)          echo "35" ;;
          ro.build.version.security_patch) echo "2026-08-05" ;;
          ro.treble.enabled)             echo "true" ;;
          ro.product.cpu.abi)            echo "arm64-v8a" ;;
          ro.product.device)             echo "KM4k" ;;
          ro.product.manufacturer)       echo "TECNO" ;;
          ro.product.model)              echo "TECNO KM4k" ;;
          ro.board.platform)             echo "mt6768" ;;
          ro.hardware)                   echo "mt6768" ;;
          ro.vndk.version)               echo "34" ;;
          ro.vendor.build.version.sdk)   echo "35" ;;
          *)                             echo "" ;;
        esac
        ;;
      *"getprop"*)
        cat <<'PROPS'
[ro.boot.flash.locked]: [0]
[ro.boot.verifiedbootstate]: [orange]
[ro.boot.dynamic_partitions]: [true]
[ro.build.display.id]: [KM4k-user 15 UP1A.231005.007]
[ro.build.version.release]: [15]
[ro.build.version.sdk]: [35]
[ro.build.version.security_patch]: [2026-08-05]
[ro.treble.enabled]: [true]
[ro.product.cpu.abi]: [arm64-v8a]
[ro.product.device]: [KM4k]
[ro.product.manufacturer]: [TECNO]
[ro.product.model]: [TECNO KM4k]
[ro.board.platform]: [mt6768]
[ro.hardware]: [mt6768]
[ro.vndk.version]: [34]
[ro.vendor.build.version.sdk]: [35]
PROPS
        ;;
      *"ld.config.version_identifier.txt"*)    printf '[vendor]\nnamespace.default.isolated=true\n' ;;
      *"getconf PAGE_SIZE"*)                   echo "4096" ;;
      *"uname -a"*)                            echo "Linux localhost 5.10.198-android13-4-00001-g1234567-ab12345678 #1 SMP PREEMPT aarch64 Toybox" ;;
      *"df -k /data"*)                         printf 'Filesystem 1K-blocks Used Available Use%% Mounted on\n/dev/block/datasd 111000000 20000000 91000000 18%% /data\n' ;;
      *"gsi_tool status"*)                     printf 'installed\nenabled\n' ;;
      *"setprop"*)                             echo "" ;;
      *"dumpsys media.camera"*)                printf 'Number of camera devices: 2\n  Camera ID 0: back\n  Camera ID 1: front\n' ;;
      *"dumpsys fingerprint"*)                 echo "Fingerprint Service: 0 clients" ;;
      *"dumpsys telephony.registry"*)          echo "mServiceState={mVoiceRegState=0}" ;;
      *"dumpsys sensorservice"*)               echo "Sensor List: 12 sensors" ;;
      *"dumpsys media.audio_flinger"*)         echo "Output thread: active" ;;
      *"dumpsys audio"*)                       echo "STREAM_MUSIC" ;;
      *"dumpsys wifi"*)                        echo "Wi-Fi is enabled" ;;
      *"dumpsys bluetooth_manager"*)           echo "enabled: true" ;;
      *"dumpsys display"*)                     echo "mBrightness=128" ;;
      *"pm list features"*fingerprint*)         echo "android.hardware.fingerprint" ;;
      *"pm list features"*camera*)              echo "android.hardware.camera" ;;
      *"pm list features"*)                     echo "" ;;
      *"pm list packages"*)                    echo "com.android.camera" ;;
      *"lshal"*)                               echo "android.hardware.fingerprint.IFingerprintService/default" ;;
      *"logcat"*)                              echo "I/Test: sample log line" ;;
      *"df -h"*)                               printf 'Filesystem Size Used Avail Use%%\n/dev/block/datasd 106G 19G 87G 18%% /data\n' ;;
      *)                                       echo "" ;;
    esac
    exit 0
fi

case "${args[0]:-}" in
  push)
    echo "$3: 1 file pushed."
    exit 0
    ;;
  reboot)
    echo "rebooting"
    exit 0
    ;;
esac
exit 0
MOCK
chmod +x "$MOCK_DIR/adb"
echo "mock adb создан: $MOCK_DIR/adb"
