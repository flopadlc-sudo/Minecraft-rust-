#!/usr/bin/env bash
# install-gsi-dsu.sh — установка BlueOS GSI через Dynamic System Update (DSU).
#
# Почему DSU, а не «fastboot flash system»:
#   DSU создаёт отдельный динамический раздел и грузит гостевую систему РЯДОМ со стоковой.
#   Стоковая HiOS остаётся целой, обычная перезагрузка возвращает в неё, данные не стираются.
#   «fastboot flash system» стирает телефон и на TECNO не проверялся.
#
# Что делает:
#   1. проверяет SHA-256 образа (по умолчанию — официальный v0.8.1-gsi);
#   2. кладёт образ в /sdcard/Download/;
#   3. включает флаг DSU;
#   4. запускает штатный com.android.dynsystem.VerificationActivity.
#
# Использование:
#   ./install-gsi-dsu.sh --image ./BlueOS-0.8.1-gsi_arm64-20261103.img.gz
#   ./install-gsi-dsu.sh --image ./system.img --sha256 <hex> --userdata-size 8589934592
#   ./install-gsi-dsu.sh --image ... --dry-run      # только показать, что будет сделано
#
# Выход: 0 — команда отправлена; 1 — ошибка; 2 — нет связи с телефоном.

set -uo pipefail

ADB="${ADB:-adb}"
IMAGE=""
EXPECT_SHA="8adc1ee58e34f3a46e5461095666516c7e153ce8565116a6336b61be65c0a44c"
SYSTEM_SIZE=3145588736      # размер system.img в байтах (3 ГБ) — как в инструкции BlueOS
USERDATA_SIZE=8589934592    # 8 ГБ под данные гостевой системы
REMOTE_NAME="blueos_gsi.img.gz"
DRY_RUN=0
SKIP_SHA=0

RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; CYN=$'\033[36m'; RST=$'\033[0m'
[[ -t 1 ]] || { RED=''; GRN=''; YLW=''; CYN=''; RST=''; }

usage() {
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image)          IMAGE="${2:-}"; shift 2 ;;
        --sha256)         EXPECT_SHA="${2:-}"; shift 2 ;;
        --system-size)    SYSTEM_SIZE="${2:-}"; shift 2 ;;
        --userdata-size)  USERDATA_SIZE="${2:-}"; shift 2 ;;
        --remote-name)    REMOTE_NAME="${2:-}"; shift 2 ;;
        --skip-sha-check) SKIP_SHA=1; shift ;;
        --dry-run)        DRY_RUN=1; shift ;;
        -h|--help)        usage 0 ;;
        *) echo "Неизвестный аргумент: $1" >&2; usage 1 ;;
    esac
done

[[ -n "$IMAGE" ]] || { echo "Нужно указать образ: --image <файл>" >&2; usage 1; }
[[ -f "$IMAGE" ]] || { echo "Файл образа не найден: $IMAGE" >&2; exit 1; }

command -v "$ADB" >/dev/null 2>&1 || { echo "adb не найден в PATH (Android SDK Platform-Tools)." >&2; exit 2; }

DEVICES=$("$ADB" devices | awk 'NR>1 && $2=="device" {print $1}')
[[ -z "$DEVICES" ]] && { echo "Нет подключённого телефона." >&2; exit 2; }
SERIAL="${ADB_SERIAL:-$(printf '%s' "$DEVICES" | head -1)}"
A=("$ADB" -s "$SERIAL")

echo "${CYN}Установка BlueOS GSI через DSU на $SERIAL${RST}"

# ── 1. Контрольная сумма ────────────────────────────────────────────────────
if [[ $SKIP_SHA -eq 0 ]]; then
    echo "• Проверка SHA-256 образа…"
    if command -v sha256sum >/dev/null 2>&1; then
        ACTUAL=$(sha256sum "$IMAGE" | awk '{print $1}')
    elif command -v shasum >/dev/null 2>&1; then
        ACTUAL=$(shasum -a 256 "$IMAGE" | awk '{print $1}')
    else
        echo "  ${YLW}sha256sum не найден — проверка пропущена${RST}"
        ACTUAL=""
    fi
    if [[ -n "$ACTUAL" ]]; then
        if [[ "$ACTUAL" == "$EXPECT_SHA" ]]; then
            echo "  ${GRN}Совпадает${RST}: $ACTUAL"
        else
            echo "  ${RED}НЕ совпадает${RST}"
            echo "  ожидалось: $EXPECT_SHA"
            echo "  получено : $ACTUAL"
            echo "  Файл повреждён при скачивании — скачайте заново."
            exit 1
        fi
    fi
else
    echo "• ${YLW}Проверка SHA-256 пропущена (--skip-sha-check)${RST}"
fi

# ── 2. Состояние телефона ────────────────────────────────────────────────────
LOCKED=$("${A[@]}" shell getprop ro.boot.flash.locked | tr -d '\r')
if [[ "$LOCKED" == "1" ]]; then
    echo "${RED}Загрузчик заблокирован.${RST} DSU не примет фан-образ (нужен OEM-unlock: Tecno ID + 14 дней)."
    exit 1
fi
if [[ "$LOCKED" != "0" ]]; then
    echo "${YLW}Не удалось определить ro.boot.flash.locked (='$LOCKED'). Продолжаю — но если загрузчик закрыт, установка не пройдёт.${RST}"
fi

DYN=$("${A[@]}" shell getprop ro.boot.dynamic_partitions | tr -d '\r')
[[ "$DYN" == "true" ]] || echo "${YLW}Внимание: ro.boot.dynamic_partitions='$DYN'. DSU требует true.${RST}"

FREE=$("${A[@]}" shell 'df -k /data 2>/dev/null' | tr -d '\r' | awk 'NF>=4 && $4 ~ /^[0-9]+$/ {n=$4} END {print n+0}')
if [[ "$FREE" -gt 0 ]]; then
    FREEG=$((FREE / 1024 / 1024))
    if [[ "$FREEG" -lt 12 ]]; then
        echo "${RED}В /data свободно только ${FREEG} ГБ, нужно ~12 ГБ.${RST} Удалите файлы и повторите."
        exit 1
    fi
    echo "• Свободно в /data: ${FREEG} ГБ (нужно ~12 ГБ) — хватает"
fi

# ── 3. Размер system.img (нужен точный, иначе DSU откажется ставить) ────────
if [[ "$SYSTEM_SIZE" == "auto" ]]; then
    # Распакованный .img: берём размер файла; для .gz — распаковываем во временный файл.
    case "$IMAGE" in
        *.gz|*.gzip)
            TMP=$(mktemp -t blueos_img.XXXXXX)
            if gzip -dc "$IMAGE" > "$TMP" 2>/dev/null; then
                SYSTEM_SIZE=$(stat -c%s "$TMP" 2>/dev/null || stat -f%z "$TMP")
                rm -f "$TMP"
            else
                rm -f "$TMP"
                echo "Не удалось распаковать .gz для определения размера. Укажите --system-size вручную." >&2
                exit 1
            fi
            ;;
        *) SYSTEM_SIZE=$(stat -c%s "$IMAGE" 2>/dev/null || stat -f%z "$IMAGE") ;;
    esac
    echo "• Размер system.img определён автоматически: $SYSTEM_SIZE байт"
fi
echo "• KEY_SYSTEM_SIZE=$SYSTEM_SIZE  KEY_USERDATA_SIZE=$USERDATA_SIZE"

REMOTE_PATH="/sdcard/Download/$REMOTE_NAME"

if [[ $DRY_RUN -eq 1 ]]; then
    echo "${YLW}--dry-run: ничего не выполняю.${RST} Дальше было бы:"
    echo "  ${A[*]} push \"$IMAGE\" \"$REMOTE_PATH\""
    echo "  ${A[*]} shell setprop persist.sys.fflag.override.settings_dynamic_system true"
    echo "  ${A[*]} shell am start-activity -n com.android.dynsystem/com.android.dynsystem.VerificationActivity \\"
    echo "      -a android.os.image.action.START_INSTALL -d file://$REMOTE_PATH \\"
    echo "      --el KEY_SYSTEM_SIZE $SYSTEM_SIZE --el KEY_USERDATA_SIZE $USERDATA_SIZE"
    exit 0
fi

# ── 4. Копируем образ ───────────────────────────────────────────────────────
echo "• Копирование образа в $REMOTE_PATH (это займёт время)…"
if ! "${A[@]}" push "$IMAGE" "$REMOTE_PATH"; then
    echo "${RED}Не удалось скопировать образ.${RST}" >&2
    exit 1
fi

# ── 5. Включаем DSU ──────────────────────────────────────────────────────────
# Флаг нужен, чтобы пункт «Динамические обновления системы» был доступен на стоке.
echo "• Включаю поддержку DSU…"
"${A[@]}" shell setprop persist.sys.fflag.override.settings_dynamic_system true >/dev/null 2>&1

# ── 6. Запуск штатного установщика ───────────────────────────────────────────
echo "• Запускаю установку…"
"${A[@]}" shell am start-activity \
    -n com.android.dynsystem/com.android.dynsystem.VerificationActivity \
    -a android.os.image.action.START_INSTALL \
    -d "file://$REMOTE_PATH" \
    --el KEY_SYSTEM_SIZE "$SYSTEM_SIZE" \
    --el KEY_USERDATA_SIZE "$USERDATA_SIZE"

cat <<EOF

${GRN}Команда отправлена.${RST} Дальше:

  1. На телефоне появится диалог подтверждения установки — подтвердите его.
  2. В шторке — уведомление DSU с прогрессом. Дождитесь «установлено».
  3. Нажмите ${CYN}Restart${RST} в этом уведомлении — телефон загрузится в BlueOS.
  4. В GSI пройдёт первая настройка. Отладку по USB включите заново.

Если кнопка Restart в уведомлении не сработала, перезагрузитесь обычным способом —
телефон войдёт в установленную гостевую систему.

Откат: обычная перезагрузка возвращает стоковую HiOS. Удалить образ: кнопка в уведомлении
или ./rollback-dsu.sh (подробности — docs/rollback.md).
EOF
