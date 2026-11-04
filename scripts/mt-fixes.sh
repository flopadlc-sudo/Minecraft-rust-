#!/usr/bin/env bash
# mt-fixes.sh — MediaTek-фиксы и диагностика для BlueOS GSI на TECNO (MT6768).
#
# Что делает:
#   • ставит persist-свойства, которые MediaTek-GSI обычно требует;
#   • печатает состояние камеры, звука, отпечатка, SIM и датчиков;
#   • честно делит проблемы на «лечится тут» и «нужна правка в образе».
#
# Использование:
#   ./mt-fixes.sh              # применить фиксы и показать диагностику
#   ./mt-fixes.sh --diagnose   # только диагностика, ничего не менять
#   ./mt-fixes.sh --list       # показать, какие свойства будут выставлены
#
# Выход: 0 — успех; 1 — нет связи с телефоном.

set -uo pipefail

ADB="${ADB:-adb}"
MODE=apply

RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; CYN=$'\033[36m'; RST=$'\033[0m'
[[ -t 1 ]] || { RED=''; GRN=''; YLW=''; CYN=''; RST=''; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --diagnose) MODE=diagnose; shift ;;
        --list)     MODE=list; shift ;;
        -h|--help)  sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Неизвестный аргумент: $1" >&2; exit 1 ;;
    esac
done

# Свойства: имя|описание|почему
PROPS=(
    "persist.sys.phh.virtual_sensors_are_real=1|Отпечаток: «считать виртуальные датчики настоящими»|На MediaTek-GSI датчик отпечатка часто не появляется без этого флага (он же включается в treble_app: Miscellaneous → Treat virtual sensors as real)"
    "persist.qfp=false|Отпечаток: отключить Qualcomm-режим qfp|Обход конфликта HAL-ов отпечатка; на MTK-вендоре мешает конфликту имён"
    "persist.camera.HAL3.enabled=1|Камера: включить HAL3 в системной части|На части MTK-вендоров на GSI камера молчит без этого флага (штатный фикс из XDA-гайдов по GSI-камере)"
    "persist.vendor.camera.HAL3.enabled=1|Камера: включить HAL3 в vendor-части|Пара к предыдущему: вендорный HAL читает именно это свойство"
    "persist.vendor.camera.eis.enabled=1|Камера: включить EIS|Часто требуется, чтобы вендорный HAL3-стек полностью поднялся"
)

# --list работает без телефона: только печатает список свойств.
if [[ "$MODE" == "list" ]]; then
    echo "Свойства, которые ставит скрипт:"
    for p in "${PROPS[@]}"; do
        IFS='|' read -r kv desc why <<<"$p"
        printf '  %-52s %s\n    %s\n' "$kv" "$desc" "$why"
    done
    exit 0
fi

command -v "$ADB" >/dev/null 2>&1 || { echo "adb не найден в PATH." >&2; exit 1; }
DEVICES=$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}')
[[ -z "$DEVICES" ]] && { echo "Нет подключённого телефона." >&2; exit 1; }
SERIAL="${ADB_SERIAL:-$(printf '%s' "$DEVICES" | head -1)}"
A=("$ADB" -s "$SERIAL")

sh_() { "${A[@]}" shell "$1" 2>/dev/null | tr -d '\r'; }
prop() { sh_ "getprop $1"; }

# Есть ли root: adb root даёт uid=0, либо на телефоне есть su.
ROOT_OK() {
    local id
    id=$(sh_ 'id -u' | tr -d '\r' | head -1)
    [[ "$id" == "0" ]] && return 0
    sh_ 'command -v su >/dev/null 2>&1 && echo yes' | grep -q yes && return 0
    return 1
}

echo "${CYN}MediaTek-фиксы и диагностика: $SERIAL${RST}"
echo "Текущая система: $(prop ro.build.display.id) ($(prop ro.system.build.version.sdk 2>/dev/null))"
echo

# ── 1. Применение свойств ───────────────────────────────────────────────────
if [[ "$MODE" == "apply" ]]; then
    echo "── Применяю свойства ──────────────────────────────────────────"
    for p in "${PROPS[@]}"; do
        IFS='|' read -r kv desc why <<<"$p"
        KEY="${kv%%=*}"
        VAL="${kv##*=}"
        BEFORE=$(prop "$KEY")
        sh_ "setprop $KEY $VAL" >/dev/null
        sleep 0.2
        AFTER=$(prop "$KEY")
        if [[ "$AFTER" == "$VAL" ]]; then
            if [[ "$BEFORE" == "$VAL" ]]; then
                printf '  %s[уже]%s %-48s = %s\n' "$CYN" "$RST" "$KEY" "$AFTER"
            else
                printf '  %s[ок]%s   %-48s = %s\n' "$GRN" "$RST" "$KEY" "$AFTER"
            fi
        else
            printf '  %s[нет]%s   %-48s (было: %s) — setprop не сработал\n' \
                "$YLW" "$RST" "$KEY" "${BEFORE:-пусто}"
            printf '        %s\n' "$why"
        fi
    done
    echo
    if ! ROOT_OK; then
        echo "${YLW}Внимание:${RST} на обычной (user) сборке setprop persist.* через adb обычно запрещён"
        echo "политикой SELinux — свойства не применились, и это не ошибка скрипта."
        echo "Варианты: перезагрузиться в GSI (там adb root работает), поставить Magisk-модуль"
        echo "с этими свойствами или пересобрать образ с ними (см. port-to-lineage/)."
    else
        echo "${CYN}Важно:${RST} persist-свойства живут до перезагрузки. Если отпечаток/камера заработали —"
        echo "чтобы сохранить эффект, пересоберите образ с этими свойствами (см. port-to-lineage/) или"
        echo "выставьте их постоянно через модуль Magisk/init.d."
    fi
    echo
fi

# ── 2. Диагностика ───────────────────────────────────────────────────────────
echo "── Диагностика ─────────────────────────────────────────────────"

echo "${CYN}Камера${RST}"
CAM_IDS=$(sh_ 'dumpsys media.camera | grep -i "Number of camera devices"')
echo "  Устройств камеры: ${CAM_IDS:-не найдено}"
sh_ 'dumpsys media.camera | grep -iE "Camera [0-9]+|HAL3|HAL version|No camera" | head -8' | sed 's/^/    /'
sh_ 'pm list features | grep -i camera' | sed 's/^/    /'
sh_ 'pm list packages | grep -iE "camera"' | head -6 | sed 's/^/    /'

echo
echo "${CYN}Отпечаток${RST}"
FP=$(sh_ 'dumpsys fingerprint 2>/dev/null | head -5')
if [[ -z "$FP" ]]; then
    echo "  ${YLW}dumpsys fingerprint пуст — сервис отпечатка не отвечает или его нет${RST}"
    echo "  HAL: $(sh_ 'lshal 2>/dev/null | grep -i fingerprint | head -3' | tr '\n' ' ')"
else
    echo "$FP" | sed 's/^/    /'
fi
echo "  Провайдеры: $(sh_ 'pm list features | grep -i fingerprint' | tr '\n' ' ')"

echo
echo "${CYN}Звук${RST}"
sh_ 'dumpsys media.audio_flinger | grep -iE "^ *Output thread|Client|Format|active" | head -8' | sed 's/^/    /'
sh_ 'dumpsys audio | grep -iE "STREAM_MUSIC|Phone call|ringer" | head -5' | sed 's/^/    /'

echo
echo "${CYN}Сеть и SIM${RST}"
sh_ 'dumpsys telephony.registry | grep -m4 -iE "mServiceState|mSignalStrength|mDataConnectionState"' | sed 's/^/    /'
sh_ 'getprop | grep -iE "gsm\.|ril\." | head -6' | sed 's/^/    /'

echo
echo "${CYN}Датчики${RST}"
sh_ 'dumpsys sensorservice | head -12' | sed 's/^/    /'

echo
echo "${CYN}Ядро и vendor${RST}"
echo "  $(sh_ 'uname -a')"
echo "  vendor: $(prop ro.vendor.build.display.id)"
echo "  vndk: $(prop ro.vndk.version), sdk: $(prop ro.vendor.build.version.sdk)"

echo
echo "Готово. Диагностический вывод можно приложить к Issue: https://github.com/GDmio/BlueOS/issues"
