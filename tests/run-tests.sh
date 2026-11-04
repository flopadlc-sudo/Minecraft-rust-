#!/usr/bin/env bash
# run-tests.sh — прогон скриптов комплекта на имитации телефона TECNO KM4k.
#
# Телефон не нужен: tests/make-mock-adb.sh создаёт подмену adb, которая отвечает
# как реальный KM4k (Treble, arm64-v8a, dynamic partitions, VNDK 34, разблокированный
# загрузчик). Так проверяется логика скриптов: разбор вывода, коды возврата, тексты.
#
# Использование:
#   ./tests/run-tests.sh
#
# Выход: 0 — все тесты прошли; 1 — есть падения.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0

ok()   { printf '  %s[ок]%s   %s\n' "$GRN" "$RST" "$1"; PASS=$((PASS+1)); }
bad()  { printf '  %s[FAIL]%s %s\n' "$RED" "$RST" "$1"; FAIL=$((FAIL+1)); }

RED=$'\033[31m'; GRN=$'\033[32m'; RST=$'\033[0m'
[[ -t 1 ]] || { RED=''; GRN=''; RST=''; }

"$ROOT/tests/make-mock-adb.sh" >/dev/null
export PATH="$ROOT/tests/mock-bin:$PATH"

expect_exit() {
    local want="$1" desc="$2"; shift 2
    "$@" >/tmp/test-out.txt 2>&1
    local got=$?
    if [[ "$got" == "$want" ]]; then ok "$desc (код $got)"; else bad "$desc: ожидался код $want, получен $got"; sed 's/^/      /' /tmp/test-out.txt | head -5; fi
}

expect_contains() {
    local file="$1" needle="$2" desc="$3"
    if grep -qF -- "$needle" "$file"; then ok "$desc"; else bad "$desc: не найдено «$needle»"; fi
}

cd "$ROOT"

echo "Синтаксис скриптов"
for f in scripts/*.sh tests/*.sh; do
    if bash -n "$f" 2>/tmp/syn.txt; then ok "bash -n $f"; else bad "bash -n $f"; sed 's/^/      /' /tmp/syn.txt; fi
done

echo
echo "check-phone.sh (все проверки должны пройти)"
expect_exit 0 "check-phone.sh на корректном телефоне" ./scripts/check-phone.sh
expect_contains /tmp/test-out.txt "Все проверки пройдены" "итог — успех"
expect_contains /tmp/test-out.txt "namespace.isolated" "проверка VNDK-изоляции выполнена"
expect_contains /tmp/test-out.txt "VNDK вендора" "проверка VNDK выполнена"

echo
echo "check-phone.sh --json"
expect_exit 0 "check-phone.sh --json" ./scripts/check-phone.sh --json
if python3 -c "import json,sys; d=json.load(open('/tmp/test-out.txt')); assert d['blockers']==0; assert len(d['results'])>10" 2>/dev/null; then
    ok "JSON валиден, блокеров 0"
else
    bad "JSON невалиден или есть блокеры"
fi

echo
echo "install-gsi-dsu.sh"
printf 'not a real image' | gzip -c > /tmp/test-gsi.img.gz
export MOCK_LOG=/tmp/mock-adb.log
: > "$MOCK_LOG"
expect_exit 0 "установка с --skip-sha-check (имитация push)" \
    ./scripts/install-gsi-dsu.sh --image /tmp/test-gsi.img.gz --skip-sha-check
expect_contains /tmp/test-out.txt "KEY_SYSTEM_SIZE=3145588736" "размер system передан верно"
expect_contains /tmp/test-out.txt "KEY_USERDATA_SIZE=8589934592" "размер userdata передан верно"
# Команды, реально ушедшие на телефон, проверяем по логу mock-adb.
expect_contains "$MOCK_LOG" "com.android.dynsystem" "запуск штатного установщика DSU"
expect_contains "$MOCK_LOG" "android.os.image.action.START_INSTALL" "правильный action DSU"
expect_contains "$MOCK_LOG" "push" "образ скопирован на телефон"
expect_contains "$MOCK_LOG" "persist.sys.fflag.override.settings_dynamic_system" "флаг DSU включён"

echo
echo "install-gsi-dsu.sh: неверная контрольная сумма"
expect_exit 1 "битый образ отклонён" \
    ./scripts/install-gsi-dsu.sh --image /tmp/test-gsi.img.gz
expect_contains /tmp/test-out.txt "НЕ совпадает" "сообщение о несовпадении суммы"

echo
echo "install-gsi-dsu.sh --dry-run ничего не выполняет"
expect_exit 0 "dry-run" ./scripts/install-gsi-dsu.sh --image /tmp/test-gsi.img.gz --skip-sha-check --dry-run
expect_contains /tmp/test-out.txt "ничего не выполняю" "dry-run безопасен"

echo
echo "mt-fixes.sh"
expect_exit 0 "mt-fixes.sh --list" ./scripts/mt-fixes.sh --list
expect_contains /tmp/test-out.txt "persist.sys.phh.virtual_sensors_are_real" "список свойств содержит отпечаток-фикс"
expect_contains /tmp/test-out.txt "persist.camera.HAL3.enabled" "список свойств содержит камеру-фикс"
expect_exit 0 "mt-fixes.sh --diagnose" ./scripts/mt-fixes.sh --diagnose
expect_contains /tmp/test-out.txt "Диагностика" "диагностика выполнена"

echo
echo "rollback-dsu.sh"
expect_exit 0 "rollback-dsu.sh status" ./scripts/rollback-dsu.sh status
expect_contains /tmp/test-out.txt "installed" "статус DSU прочитан"
expect_exit 0 "rollback-dsu.sh disable" ./scripts/rollback-dsu.sh disable
expect_exit 1 "rollback-dsu.sh с неизвестной командой" ./scripts/rollback-dsu.sh nonsense

echo
echo "collect-logs.sh"
expect_exit 0 "collect-logs.sh" ./scripts/collect-logs.sh
expect_contains /tmp/test-out.txt "диагностический отчёт" "отчёт собран"
expect_contains /tmp/test-out.txt "Свойства" "раздел свойств заполнен"

echo
echo "────────────────────────────────────────────"
printf 'Пройдено: %d, падений: %d\n' "$PASS" "$FAIL"
[[ $FAIL -eq 0 ]] || exit 1
exit 0
