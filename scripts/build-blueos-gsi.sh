#!/usr/bin/env bash
# build-blueos-gsi.sh — собрать свой GSI с BlueOS из исходников LineageOS 24.0.
#
# Что делает (по официальному BUILDING.md проекта BlueOS):
#   1. repo init -u https://github.com/LineageOS/android.git -b lineage-24.0
#   2. repo sync -j8
#   3. подключает vendor/blueos и MindTheGapps (по желанию)
#   4. source build/envsetup.sh — накладывает патчи BlueOS
#   5. breakfast gsi_arm64 && m systemimage
#
# Требования к машине: Linux (Ubuntu 22.04/24.04) или Windows+WSL2, 32 ГБ RAM
# (плюс swap 32-48 ГБ), ~350 ГБ свободного диска, несколько часов на первую сборку.
# В песочнице, где писался этот комплект (2 CPU / 3 ГБ RAM / 20 ГБ диска) сборка НЕ выполнялась:
# ресурсов недостаточно. Скрипт — это инструкция в исполняемом виде.
#
# Использование:
#   ./build-blueos-gsi.sh --dir ~/android/lineage --gapps
#   ./build-blueos-gsi.sh --dir ~/android/lineage --sync-only
#
# Выход: 0 — сборка завершена; 1 — ошибка.

set -uo pipefail

DIR="${HOME}/android/lineage"
USE_GAPPS=0
SYNC_ONLY=0
JOBS="$(nproc 2>/dev/null || echo 8)"

RED=$'\033[31m'; GRN=$'\033[32m'; YLW=$'\033[33m'; CYN=$'\033[36m'; RST=$'\033[0m'
[[ -t 1 ]] || { RED=''; GRN=''; YLW=''; CYN=''; RST=''; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dir)        DIR="${2:-}"; shift 2 ;;
        --gapps)      USE_GAPPS=1; shift ;;
        --sync-only)  SYNC_ONLY=1; shift ;;
        --jobs)       JOBS="${2:-}"; shift 2 ;;
        -h|--help)    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "Неизвестный аргумент: $1" >&2; exit 1 ;;
    esac
done

fail() { echo "${RED}Ошибка: $*${RST}" >&2; exit 1; }

for cmd in git repo python3; do
    command -v "$cmd" >/dev/null 2>&1 || fail "$cmd не найден в PATH"
done

# ── Проверка ресурсов ────────────────────────────────────────────────────────
echo "${CYN}Проверка машины${RST}"
MEM_GB=$(( $(free -g 2>/dev/null | awk '/^Mem:/{print $2}') ))
DISK_GB=$(df -BG --output=avail "$DIR" 2>/dev/null | tail -1 | tr -dc '0-9')
[[ -z "$DISK_GB" ]] && DISK_GB=$(df -BG "$HOME" 2>/dev/null | tail -1 | awk '{gsub(/G/,"",$4); print $4}')
echo "  RAM: ${MEM_GB:-?} ГБ (нужно 32)"
echo "  Свободно: ${DISK_GB:-?} ГБ (нужно ~350)"
if [[ -n "$MEM_GB" && "$MEM_GB" -lt 30 ]]; then
    echo "  ${RED}Мало RAM.${RST} Добавьте swap 32-48 ГБ или соберите на другой машине."
    exit 1
fi
if [[ -n "$DISK_GB" && "$DISK_GB" -lt 300 ]]; then
    echo "  ${RED}Мало места.${RST} Нужно ~350 ГБ, есть ${DISK_GB} ГБ."
    exit 1
fi
echo "  ${GRN}Ресурсы выглядят достаточными.${RST}"
echo

mkdir -p "$DIR" || fail "не удалось создать $DIR"
cd "$DIR" || fail "не удалось перейти в $DIR"

# ── 1. repo init ─────────────────────────────────────────────────────────────
if [[ ! -d .repo ]]; then
    echo "${CYN}[1/5] repo init${RST}"
    repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 \
        --git-lfs --no-clone-bundle || fail "repo init не удался"
else
    echo "${CYN}[1/5] repo init — пропускаю, .repo уже есть${RST}"
fi

# ── 2. Локальные манифесты ───────────────────────────────────────────────────
echo "${CYN}[2/5] Локальные манифесты (vendor/blueos)${RST}"
mkdir -p .repo/local_manifests
if [[ ! -f .repo/local_manifests/blueos.xml ]]; then
    cat > .repo/local_manifests/blueos.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <remote name="blueos" fetch="https://github.com/GDmio" />
  <project path="vendor/blueos" name="BlueOS" remote="blueos" revision="refs/tags/v0.8.1" />
</manifest>
EOF
    echo "  создан .repo/local_manifests/blueos.xml (ревизия — тег v0.8.1)"
else
    echo "  .repo/local_manifests/blueos.xml уже есть"
fi

if [[ $USE_GAPPS -eq 1 ]]; then
    if [[ ! -f .repo/local_manifests/gapps.xml ]]; then
        cat > .repo/local_manifests/gapps.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="MindTheGapps/vendor_gapps" path="vendor/gapps" remote="github" revision="cinnamonbun" clone-depth="1" />
</manifest>
EOF
        echo "  создан .repo/local_manifests/gapps.xml (MindTheGapps, ветка cinnamonbun)"
    fi
else
    echo "  ${YLW}Google Play не подключён.${RST} Добавьте --gapps, если он нужен."
fi

# ── 3. repo sync ─────────────────────────────────────────────────────────────
echo "${CYN}[3/5] repo sync -j${JOBS} (долго, несколько часов)${RST}"
repo sync -j"$JOBS" || fail "repo sync не удался"

# ── 4. Подключение BlueOS к сборке ──────────────────────────────────────────
echo "${CYN}[4/5] Подключаю vendor/blueos${RST}"
mkdir -p vendor/extra
if ! grep -q 'vendor/blueos/config/blueos.mk' vendor/extra/product.mk 2>/dev/null; then
    echo '$(call inherit-product, vendor/blueos/config/blueos.mk)' >> vendor/extra/product.mk
    echo "  добавлена строка в vendor/extra/product.mk"
else
    echo "  vendor/extra/product.mk уже содержит подключение"
fi

echo "  ${CYN}source build/envsetup.sh${RST} — здесь накладываются патчи BlueOS."
echo "  Смотрите вывод: должно быть «BlueOS: applied …» и НИ ОДНОГО «BlueOS: FAILED»."
echo "  Если патч не встал — варианты в BUILDING.md: поправить патч или закрепить"
echo "  проекты на ревизиях из vendor/blueos/manifests/blueos-pinned.xml."
echo

# ── 5. Сборка ────────────────────────────────────────────────────────────────
if [[ $SYNC_ONLY -eq 1 ]]; then
    echo "${GRN}Синхронизация завершена.${RST} Дальше:"
    echo "  cd $DIR && source build/envsetup.sh && breakfast gsi_arm64 && m systemimage"
    exit 0
fi

echo "${CYN}[5/5] Сборка GSI (breakfast gsi_arm64 && m systemimage)${RST}"
# shellcheck disable=SC1091
source build/envsetup.sh || fail "envsetup.sh не отработал"
breakfast gsi_arm64 || fail "breakfast не удался"
m systemimage -j"$JOBS" || fail "сборка не удалась"

IMG="$DIR/out/target/product/generic_arm64/system.img"
if [[ -f "$IMG" ]]; then
    echo
    echo "${GRN}Сборка готова:${RST} $IMG ($(du -h "$IMG" | cut -f1))"
    echo "Установите его тем же скриптом:"
    echo "  gzip -c \"$IMG\" > BlueOS-gsi.img.gz && ./install-gsi-dsu.sh --image BlueOS-gsi.img.gz --sha256 \$(sha256sum BlueOS-gsi.img.gz | cut -d' ' -f1)"
else
    echo "${YLW}Ожидаемый файл не найден: $IMG${RST}"
    exit 1
fi
