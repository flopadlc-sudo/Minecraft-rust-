#!/usr/bin/env bash
# collect-logs.sh — собрать диагностический отчёт по BlueOS GSI на телефоне.
#
# Зачем: автор BlueOS проверял GSI только на Pixel 6a. Единственный способ получить
# помощь — приложить в Issue логи с телефона. Этот скрипт собирает всё нужное в один
# текстовый файл, который удобно приложить к issue.
#
# Использование:
#   ./collect-logs.sh            # вывод в stdout
#   ./collect-logs.sh -o report.txt
#
# Выход: 0 — отчёт собран; 1 — нет связи с телефоном.

set -uo pipefail

ADB="${ADB:-adb}"
OUT=""
[[ "${1:-}" == "-o" ]] && { OUT="${2:-}"; shift 2; }

command -v "$ADB" >/dev/null 2>&1 || { echo "adb не найден в PATH." >&2; exit 1; }
DEVICES=$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}')
[[ -z "$DEVICES" ]] && { echo "Нет подключённого телефона." >&2; exit 1; }
SERIAL="${ADB_SERIAL:-$(printf '%s' "$DEVICES" | head -1)}"
A=("$ADB" -s "$SERIAL")

emit() { if [[ -n "$OUT" ]]; then printf '%s\n' "$*" >> "$OUT"; else printf '%s\n' "$*"; fi; }
section() { emit ""; emit "==================== $1 ===================="; }
sh_() { "${A[@]}" shell "$1" 2>/dev/null | tr -d '\r'; }

emit "BlueOS GSI — диагностический отчёт"
emit "Собрано: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
MANUF=$(sh_ 'getprop ro.product.manufacturer')
MODEL=$(sh_ 'getprop ro.product.model')
[[ "${MODEL:-}" == "${MANUF:-} "* ]] && MANUF=""
emit "Телефон: ${MANUF:+$MANUF }${MODEL:-?} ($(sh_ 'getprop ro.product.device'))"
emit "Система: $(sh_ 'getprop ro.build.display.id')"
emit "Ядро: $(sh_ 'uname -a')"

section "Свойства"
sh_ 'getprop' | grep -iE "treble|vndk|dynamic_partitions|flash.locked|verifiedboot|cpu.abi|product.device|build.version|security_patch|page_size|fingerprint|camera" | sed 's/^/  /'

section "DSU"
emit "  gsi_tool status:"
sh_ 'gsi_tool status 2>/dev/null || echo "    недоступен"' | sed 's/^/  /'

section "Камера"
sh_ 'dumpsys media.camera' | head -60 | sed 's/^/  /'

section "Отпечаток"
sh_ 'dumpsys fingerprint' | head -40 | sed 's/^/  /'
emit "  HAL:"
sh_ 'lshal 2>/dev/null | grep -i fingerprint' | sed 's/^/    /'

section "Аудио"
sh_ 'dumpsys media.audio_flinger' | head -60 | sed 's/^/  /'

section "Телефония"
sh_ 'dumpsys telephony.registry' | head -30 | sed 's/^/  /'

section "Датчики"
sh_ 'dumpsys sensorservice' | head -30 | sed 's/^/  /'

section "Ошибки в logcat (за последние 2000 строк)"
sh_ 'logcat -d -v brief -t 2000 2>/dev/null | grep -iE "fatal|error|exception|EGL|gralloc|camera|fingerprint|audio|vndk|avc: denied" | tail -120' | sed 's/^/  /'

section "Размеры разделов"
sh_ 'df -h /data /system /vendor 2>/dev/null' | sed 's/^/  /'

if [[ -n "$OUT" ]]; then
    echo "Отчёт сохранён: $OUT ($(wc -l < "$OUT") строк)"
    echo "Приложите его к https://github.com/GDmio/BlueOS/issues и укажите модель телефона."
else
    echo ""
    echo "# Приложите этот вывод к https://github.com/GDmio/BlueOS/issues"
fi
