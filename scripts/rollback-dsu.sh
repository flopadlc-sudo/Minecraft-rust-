#!/usr/bin/env bash
# rollback-dsu.sh — снять установленный GSI и вернуть телефон к стоковой системе.
#
# Что делает (по порядку «от мягкого к жёсткому»):
#   status  — показать состояние DSU (ничего не меняет);
#   disable — выключить «липкий» режим: следующая перезагрузка уйдёт в стоковую систему,
#             но образ GSI останется на диске (его можно включить обратно);
#   wipe    — удалить образ GSI вместе с его данными;
#   wipe-data — стереть только данные гостевой системы (userdata DSU), сам образ оставить;
#   enable  — включить GSI обратно (одна загрузка: --single-boot);
#
# ВАЖНО: не выполняйте «fastboot flashing lock», пока стоит GSI: телефон не загрузится.
# Вернуться на сток с заблокированным загрузчиком можно только после полного снятия GSI
# и (при желании) восстановления заводской прошивки — см. docs/rollback.md.
#
# Использование:
#   ./rollback-dsu.sh status
#   ./rollback-dsu.sh disable
#   ./rollback-dsu.sh wipe
#   ./rollback-dsu.sh wipe-data
#   ./rollback-dsu.sh enable --single-boot
#
# Выход: 0 — успех; 1 — ошибка; 2 — нет связи с телефоном.

set -uo pipefail

ADB="${ADB:-adb}"
CMD="${1:-status}"
shift 2>/dev/null || true

RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; CYN=$'\033[36m'; RST=$'\033[0m'
[[ -t 1 ]] || { RED=''; GRN=''; YLW=''; CYN=''; RST=''; }

command -v "$ADB" >/dev/null 2>&1 || { echo "adb не найден в PATH." >&2; exit 1; }
DEVICES=$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}')
[[ -z "$DEVICES" ]] && { echo "Нет подключённого телефона." >&2; exit 2; }
SERIAL="${ADB_SERIAL:-$(printf '%s' "$DEVICES" | head -1)}"
A=("$ADB" -s "$SERIAL")

case "$CMD" in
    status)
        echo "${CYN}Состояние DSU:${RST}"
        # gsi_tool живёт в /system/bin и печатает installed/running/enabled/normal.
        OUT=$("${A[@]}" shell 'command -v gsi_tool >/dev/null 2>&1 && gsi_tool status || echo "gsi_tool недоступен"' | tr -d '\r')
        echo "$OUT" | sed 's/^/  /'
        echo
        echo "  Разблокирован ли загрузчик: $("${A[@]}" shell getprop ro.boot.flash.locked | tr -d '\r')"
        echo "  Текущая система: $("${A[@]}" shell getprop ro.build.display.id | tr -d '\r')"
        echo
        echo "  Если gsi_tool недоступен (стоковая HiOS без system/gsid) — пользуйтесь кнопками"
        echo "  в уведомлении DSU: Restart / Discard."
        ;;
    disable)
        echo "Выключаю липкий режим GSI (следующая перезагрузка — в стоковую систему)…"
        if "${A[@]}" shell gsi_tool disable; then
            echo "${GRN}Готово.${RST} Перезагрузите телефон обычным способом — вернётся стоковая система."
        else
            echo "${YLW}gsi_tool не сработал (нет root или нет gsi_tool).${RST}"
            echo "Перезагрузитесь: после обычной перезагрузки GSI не стартует, если липкий режим выключен."
        fi
        ;;
    enable)
        EXTRA=""
        [[ "${1:-}" == "--single-boot" ]] && EXTRA="-s"
        echo "Включаю GSI${EXTRA:+ на одну загрузку}…"
        "${A[@]}" shell "gsi_tool enable $EXTRA" || {
            echo "${YLW}gsi_tool недоступен или нужны права root.${RST}"; exit 1; }
        echo "${GRN}Готово.${RST} Перезагрузитесь, чтобы войти в GSI."
        ;;
    wipe)
        echo "Удаляю образ GSI и его данные…"
        if "${A[@]}" shell gsi_tool wipe; then
            echo "${GRN}Готово.${RST} После перезагрузки GSI не останется."
        else
            echo "${YLW}gsi_tool wipe не сработал.${RST}"
            echo "Если вы сейчас внутри GSI — сначала выключите липкий режим и перезагрузитесь в сток,"
            echo "затем повторите wipe. В крайнем случае удалите образ через кнопку Discard в уведомлении DSU."
            exit 1
        fi
        ;;
    wipe-data)
        echo "Стираю данные гостевой системы (userdata DSU)…"
        "${A[@]}" shell gsi_tool wipe-data || {
            echo "${YLW}gsi_tool wipe-data не сработал (нужно не находиться внутри работающего GSI).${RST}"; exit 1; }
        echo "${GRN}Готово.${RST}"
        ;;
    *)
        echo "Использование: $0 {status|disable|enable [--single-boot]|wipe|wipe-data}" >&2
        exit 1
        ;;
esac
