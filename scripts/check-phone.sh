#!/usr/bin/env bash
# check-phone.sh — preflight-проверка телефона перед установкой BlueOS GSI.
#
# Что делает: читает с телефона ТОЛЬКО свойства и сводку разделов (никаких изменений).
# Зачем: заранее выяснить, способен ли телефон запустить GSI, и не тратить день на
# разблокировку загрузчика, если установка всё равно невозможна.
#
# Использование:
#   ./check-phone.sh            # проверка одного телефона
#   ./check-phone.sh --json     # тот же вывод в JSON (для автоматической проверки)
#
# Выход: 0 — критичных проблем нет; 1 — есть блокирующая проблема; 2 — нет связи с телефоном.

set -uo pipefail

ADB="${ADB:-adb}"
JSON=0
[[ "${1:-}" == "--json" ]] && JSON=1

RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; CYN=$'\033[36m'; RST=$'\033[0m'
[[ -t 1 ]] || { RED=''; GRN=''; YLW=''; CYN=''; RST=''; }

BLOCKERS=0
WARNINGS=0
declare -a RESULTS=()

say()  { [[ $JSON -eq 1 ]] || printf '%s\n' "$*"; }
hr()   { [[ $JSON -eq 1 ]] || printf '%s\n' "────────────────────────────────────────────────────────────"; }

# ok|WARN|BAD <ключ> <значение> <комментарий>
record() {
    local status="$1" key="$2" value="$3" note="$4"
    RESULTS+=("$status"$'\t'"$key"$'\t'"$value"$'\t'"$note")
    case "$status" in
        BAD)  BLOCKERS=$((BLOCKERS+1)) ;;
        WARN) WARNINGS=$((WARNINGS+1)) ;;
    esac
    [[ $JSON -eq 1 ]] && return
    case "$status" in
        ok)   printf '  %s[ ok ]%s %-34s %s%s\n' "$GRN" "$RST" "$key" "$value" "${note:+  — $note}" ;;
        WARN) printf '  %s[warn]%s %-34s %s%s\n' "$YLW" "$RST" "$key" "$value" "${note:+  — $note}" ;;
        BAD)  printf '  %s[FAIL]%s %-34s %s%s\n' "$RED" "$RST" "$key" "$value" "${note:+  — $note}" ;;
    esac
}

command -v "$ADB" >/dev/null 2>&1 || { say "adb не найден в PATH. Установите Android SDK Platform-Tools."; exit 2; }

DEVICES=$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}')
COUNT=$(printf '%s\n' "$DEVICES" | grep -c . || true)
if [[ "$COUNT" -eq 0 ]]; then
    say "Нет подключённого телефона. Включите «Отладку по USB», разблокируйте экран и подтвердите доверие компьютеру."
    exit 2
fi
if [[ "$COUNT" -gt 1 ]]; then
    say "Подключено несколько устройств ($COUNT): $DEVICES"
    say "Укажите нужное: ADB_SERIAL=<serial> ./check-phone.sh"
    exit 2
fi

SERIAL=$(printf '%s' "$DEVICES" | head -1)
if [[ -n "${ADB_SERIAL:-}" ]]; then SERIAL="$ADB_SERIAL"; fi

prop() { "$ADB" -s "$SERIAL" shell "getprop $1" 2>/dev/null | tr -d '\r'; }

say "${CYN}Проверка телефона $SERIAL${RST}"
hr

# ── Идентификация ────────────────────────────────────────────────────────────
MODEL=$(prop ro.product.model)
DEV=$(prop ro.product.device)
MANUF=$(prop ro.product.manufacturer)
REL=$(prop ro.build.version.release)
SDK=$(prop ro.build.version.sdk)
PLATFORM=$(prop ro.board.platform)
HARDWARE=$(prop ro.hardware)
# Не повторяем производителя, если он уже есть в названии модели (TECNO TECNO KM4k).
[[ "${MODEL:-}" == "${MANUF:-} "* ]] && MANUF=""
say "  Устройство: ${MANUF:+$MANUF }${MODEL:-?} (${DEV:-?}), Android ${REL:-?} (SDK ${SDK:-?}), платформа ${PLATFORM:-?}/${HARDWARE:-?}"
hr

# ── 1. Treble ────────────────────────────────────────────────────────────────
TREBLE=$(prop ro.treble.enabled)
if [[ "$TREBLE" == "true" ]]; then
    record ok "Treble (ro.treble.enabled)" "true" "GSI поддерживается"
else
    record BAD "Treble (ro.treble.enabled)" "${TREBLE:-пусто}" "GSI на этом телефоне не заработает"
fi

# ── 2. Архитектура ───────────────────────────────────────────────────────────
ABI=$(prop ro.product.cpu.abi)
ABILIST=$(prop ro.product.cpu.abilist)
if [[ "$ABI" == "arm64-v8a" ]]; then
    record ok "Архитектура" "$ABI" "нужен образ arm64"
elif [[ "$ABILIST" == *arm64-v8a* ]]; then
    record WARN "Архитектура" "$ABI" "в списке есть arm64-v8a ($ABILIST)"
else
    record BAD "Архитектура" "$ABI" "нужен arm64-v8a, 64-битный образ не подойдёт"
fi

# ── 3. Динамические разделы ─────────────────────────────────────────────────
DYN=$(prop ro.boot.dynamic_partitions)
if [[ "$DYN" == "true" ]]; then
    record ok "Dynamic partitions" "true" "нужно для DSU"
else
    record BAD "Dynamic partitions" "${DYN:-пусто}" "без них DSU невозможен"
fi

# ── 4. Версия Android ────────────────────────────────────────────────────────
if [[ -n "$SDK" ]] && [[ "$SDK" -ge 33 ]]; then
    record ok "Версия Android" "$REL (SDK $SDK)" ">= 13, GSI поддерживается"
elif [[ -n "$SDK" ]]; then
    record BAD "Версия Android" "$REL (SDK $SDK)" "нужен Android 13 (SDK 33) или новее"
fi

# ── 5. VNDK ──────────────────────────────────────────────────────────────────
VNDK=$(prop ro.vndk.version)
VSDK=$(prop ro.vendor.build.version.sdk)
if [[ -n "$VNDK" ]]; then
    if [[ "$VNDK" -le 34 ]]; then
        record ok "VNDK вендора" "$VNDK" "входит в PRODUCT_EXTRA_VNDK_VERSIONS (31 32 33 34) образа"
    else
        record WARN "VNDK вендора" "$VNDK" "вне списка образа (31-34): возможна ошибка VNDK"
    fi
else
    record WARN "VNDK вендора" "не найден" "проверьте вручную: adb shell getprop ro.vndk.version"
fi
[[ -n "$VSDK" ]] && record ok "SDK вендора" "$VSDK" ""

# ── 6. Изоляция вендора (главный риск совместимости) ─────────────────────────
ISO=$("$ADB" -s "$SERIAL" shell 'cat /system/etc/ld.config.version_identifier.txt 2>/dev/null | grep -A 20 "\[vendor\]" | grep -m1 "namespace.default.isolated"' 2>/dev/null | tr -d '\r')
if [[ "$ISO" == *"true"* ]]; then
    record ok "[vendor] namespace.isolated" "true" "телефон VNDK-совместим, GSI новее Android 15 допустим"
elif [[ "$ISO" == *"false"* ]]; then
    record BAD "[vendor] namespace.isolated" "false" "не VNDK-совместим: допустим только GSI ровно Android 15"
else
    record WARN "[vendor] namespace.isolated" "не найден" "файл ld.config.version_identifier.txt недоступен"
fi

# ── 7. Размер страницы ───────────────────────────────────────────────────────
PAGE=$("$ADB" -s "$SERIAL" shell 'getconf PAGE_SIZE' 2>/dev/null | tr -d '\r' | grep -o '[0-9]*' | head -1)
if [[ -z "$PAGE" ]]; then
    record WARN "Размер страницы" "не определён" "проверьте вручную: adb shell getconf PAGE_SIZE"
elif [[ "$PAGE" == "16384" ]]; then
    record ok "Размер страницы" "16384 (16 КБ)" "образ поддерживает 16 КБ (PRODUCT_MAX_PAGE_SIZE_SUPPORTED)"
elif [[ "$PAGE" == "4096" ]]; then
    record ok "Размер страницы" "4096 (4 КБ)" "совместимо"
else
    record WARN "Размер страницы" "$PAGE" "необычно, проверьте совместимость"
fi

# ── 8. Загрузчик ─────────────────────────────────────────────────────────────
LOCKED=$(prop ro.boot.flash.locked)
VSTATE=$(prop ro.boot.verifiedbootstate)
if [[ "$LOCKED" == "0" ]]; then
    record ok "Загрузчик" "разблокирован" "DSU с фан-образом разрешён"
elif [[ "$LOCKED" == "1" ]]; then
    record BAD "Загрузчик" "заблокирован" "нужен OEM-unlock (Tecno ID + 14 дней), DSU фан-образа не примет"
else
    record WARN "Загрузчик" "не определён (locked=${LOCKED:-?})" "проверьте: adb shell getprop ro.boot.flash.locked"
fi
[[ -n "$VSTATE" ]] && record ok "Verified boot state" "$VSTATE" ""

# ── 9. Место под DSU ─────────────────────────────────────────────────────────
FREE=$("$ADB" -s "$SERIAL" shell 'df -k /data 2>/dev/null' | tr -d '\r' | awk 'NF>=4 && $4 ~ /^[0-9]+$/ {n=$4} END {print n+0}')
if [[ "$FREE" -gt 0 ]]; then
    FREEG=$((FREE / 1024 / 1024))
    if [[ "$FREEG" -ge 12 ]]; then
        record ok "Свободно в /data" "${FREEG} ГБ" "нужно ~12 ГБ"
    else
        record BAD "Свободно в /data" "${FREEG} ГБ" "нужно минимум ~12 ГБ — удалите файлы"
    fi
else
    record WARN "Свободно в /data" "не определено" "проверьте вручную: adb shell df -h /data"
fi

# ── 10. Ядро и патчи безопасности ────────────────────────────────────────────
KERNEL=$("$ADB" -s "$SERIAL" shell 'uname -a' 2>/dev/null | tr -d '\r')
[[ -n "$KERNEL" ]] && record ok "Ядро" "$KERNEL" ""
SPL=$(prop ro.build.version.security_patch)
[[ -n "$SPL" ]] && record ok "Патч безопасности" "$SPL" ""

# ── Итог ─────────────────────────────────────────────────────────────────────
hr
if [[ $JSON -eq 1 ]]; then
    printf '{"serial":"%s","model":"%s","android":"%s","blockers":%d,"warnings":%d,"results":[' \
        "$SERIAL" "$MODEL" "$REL" "$BLOCKERS" "$WARNINGS"
    sep=""
    for r in "${RESULTS[@]}"; do
        IFS=$'\t' read -r st key val note <<<"$r"
        printf '%s{"status":"%s","key":"%s","value":"%s","note":"%s"}' "$sep" "$st" "$key" "$val" "$note"
        sep=","
    done
    printf ']}\n'
else
    if [[ $BLOCKERS -eq 0 && $WARNINGS -eq 0 ]]; then
        printf '%sВсе проверки пройдены.%s Можно ставить GSI: ./install-gsi-dsu.sh --image <файл>\n' "$GRN" "$RST"
    elif [[ $BLOCKERS -eq 0 ]]; then
        printf '%sБлокирующих проблем нет, предупреждений: %d.%s Смотрите список выше.\n' "$YLW" "$WARNINGS" "$RST"
    else
        printf '%sБлокирующих проблем: %d (предупреждений: %d).%s Пункты [FAIL] надо устранить до установки.\n' \
            "$RED" "$BLOCKERS" "$WARNINGS" "$RST"
    fi
fi

[[ $BLOCKERS -gt 0 ]] && exit 1
exit 0
