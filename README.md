# BlueOS на TECNO SPARK 40C (KM4k) — гайд и комплект

Комплект для запуска [BlueOS](https://github.com/GDmio/BlueOS) (фанатская прошивка на базе LineageOS 24.0) на телефоне
**TECNO SPARK 40C**, кодовое имя **KM4k**:

| | |
|---|---|
| Чип | MediaTek Helio G81 (MT6768) |
| ОС на телефоне | Android 15 (HiOS 15.1.2) |
| Экран | 720×1600, 263 ppi → **≈360×800 dp** (плотность 320 dpi) |
| RAM / память | 4+4 ГБ / 128 ГБ, microSD |
| Разблокировка загрузчика | Tecno ID + выдержка **≥14 дней** |

Подтверждённые пользователем условия: `ro.treble.enabled=true`, ABI `arm64-v8a`, `ro.boot.dynamic_partitions=true` —
формальные требования GSI выполнены.

---

## 1. Три пути — какой выбрать

| Путь | Что делаем | Время | Риск для данных | Нужен root/разблокировка |
|---|---|---|---|---|
| **A. Готовый GSI через DSU** | Ставим официальный образ `v0.8.1-gsi` как «гостевую» систему рядом с HiOS | 30–60 мин | **данные не стираются** | нужен **разблокированный загрузчик** |
| **B. Своя сборка GSI с BlueOS** | Собираем `system.img` из LineageOS 24.0 + `vendor/blueos` и добавляем свои MediaTek-фиксы | 6–12 ч на машине с 32 ГБ RAM | данные не стираются (если ставить через DSU) | то же + компьютер ~350 ГБ свободных |
| **C. Полный порт LineageOS под KM4k** | Своё device tree, ядро, блобы камеры/IMS под TECNO | недели | при первой прошивке — да | да |

**Рекомендация: начинать с пути A.** Он проверяет совместимость телефона с BlueOS за вечер и не трогает данные.
Путь B имеет смысл, если в A что-то не работает и нужно это починить в коде (камера, отпечаток, звук).
Путь C — отдельный проект, он не нужен, чтобы «просто получить BlueOS».

> **Важно про версию GSI.** Готовый образ `v0.8.1-gsi` собран из **LineageOS 24.0 (Android 17)** на ветке
> `device/generic/common/gsi_arm64.mk` и наследует `gsi_release.mk`, где
> `PRODUCT_EXTRA_VNDK_VERSIONS := 31 32 33 34` и `PRODUCT_MAX_PAGE_SIZE_SUPPORTED := 16384`.
> Телефон с Android 15 имеет вендор **VNDK 34**, а он в списке ⇒ известная ошибка
> «Vndk version 34 is not supported» на этом образе **не возникает**, и 16 КБ-страницы поддерживаются.
> Это один из главных аргументов «за» путь A.

---

## 2. Блокеры — прочитать ДО действий

1. **Разблокировка загрузчика.** Без неё GSI не поставится: DSU на заблокированном загрузчике принимает только образы,
   подписанные Google/OEM, а BlueOS — фан-образ. У TECNO пункт «Заводская разблокировка» появляется
   **только через ≥14 дней после регистрации Tecno ID** (таймер на серверах Transsion). Это главный блокер,
   и он не технический — он временной. **Начните с регистрации Tecno ID сегодня.**
2. **Разблокировка стирает телефон.** Форматируется `/data` (фото, переписки, приложения). Заранее сохраните
   **коды двухфакторной защиты** (Google Authenticator и т. п.) — восстановить их после сброса нельзя.
3. **Не блокируйте загрузчик обратно**, пока стоит BlueOS/GSI: `fastboot flashing lock` приведёт к кирпичу
   (система не подписана OEM-ключом). Вернуться можно только стоковой прошивкой.
4. **Play Integrity.** В GSI телефон называется «GSI on ARM64» — Google Wallet, часть банковских приложений и игр
   будут отказываться работать. Если это критично — не ставьте.
5. **Гарантий нет.** Это неофициальная сборка. Автор BlueOS проверял GSI **только на Pixel 6a**; на TECNO
   поведение не гарантировано. Отсюда — подробные логи в шагах ниже: с ними результат можно приложить в Issues.

---

## 3. Путь A — готовый GSI через DSU (рекомендуется)

### Шаг 0. Подготовка

* Скачайте с [Releases](https://github.com/GDmio/BlueOS/releases/tag/v0.8.1-gsi):
  * `BlueOS-0.8.1-gsi_arm64-20261103.img.gz` — 1 646 309 591 Б;
  * `SHA256SUMS`.
* Проверьте контрольную сумму:
  ```
  sha256sum BlueOS-0.8.1-gsi_arm64-20261103.img.gz
  # ожидается: 8adc1ee58e34f3a46e5461095666516c7e153ce8565116a6336b61be65c0a44c
  ```
  Windows: `Get-FileHash .\BlueOS-0.8.1-gsi_arm64-20261103.img.gz`.
* Скачайте [Android SDK Platform-Tools](https://developer.android.com/tools/releases/platform-tools) (`adb`, `fastboot`).
* Сделайте резервную копию данных **до** разблокировки.

### Шаг 1. Проверить телефон (до разблокировки)

```
./scripts/check-phone.sh
```
Скрипт читает с телефона только свойства (`getprop`), ничего не меняет. Он проверит Treble, ABI, динамические
разделы, VNDK-изоляцию вендора, размер страницы, статус загрузчика, свободное место и ядро.
**Почему это важно:** если `[vendor] namespace.default.isolated` = `false`, телефон не полностью VNDK-совместим,
и GSI новее Android 15 может не загрузиться вообще — тогда сразу переходите к пути B/C, а не тратьте время.

### Шаг 2. Разблокировать загрузчик (один раз, стирает данные)

1. «Настройки» → «О телефоне» → 7 раз нажать «Номер сборки» → включится режим разработчика.
2. «Настройки» → «Система» → «Для разработчиков»: включить **«Заводская разблокировка»** и **«Отладка по USB»**.
   (Пункт «Заводская разблокировка» у TECNO появляется не сразу — через ≥14 дней после регистрации Tecno ID.)
3. На компьютере:
   ```
   adb reboot bootloader
   fastboot flashing unlock
   ```
4. На телефоне кнопками громкости выбрать «Unlock the bootloader», подтвердить питанием. Телефон перезагрузится
   и покажет предупреждение о разблокированном загрузчике — это штатно.

**Проверка:** `fastboot flashing getvar unlocked` → `unlocked: yes`. Или после загрузки:
`adb shell getprop ro.boot.flash.locked` → `0`.

### Шаг 3. Установить GSI через DSU

```
./scripts/install-gsi-dsu.sh --image ./BlueOS-0.8.1-gsi_arm64-20261103.img.gz
```
Скрипт: проверит SHA-256 → запишет образ в `/sdcard/Download/` → включит флаг DSU → запустит штатный
`com.android.dynsystem.VerificationActivity` с `KEY_SYSTEM_SIZE 3145588736` и `KEY_USERDATA_SIZE 8589934592`.

**Почему через DSU, а не `fastboot flash system`:** DSU создаёт отдельный динамический раздел и грузит систему
параллельно со стоковой. Стоковая HiOS остаётся целой, следующая обычная перезагрузка возвращает в неё.
`fastboot flash system` стирает данные и на TECNO не проверен.

**Проверка:** после установки в шторке есть уведомление DSU — нажмите **Restart**. Телефон загрузится в BlueOS
(первая настройка, как на новом телефоне; отладку по USB включите заново).

### Шаг 4. MediaTek-фиксы

```
./scripts/mt-fixes.sh            # применить и проверить
./scripts/mt-fixes.sh --diagnose # только диагностика, ничего не менять
```
Отпечаток на MediaTek-GSI, камера, звук — типичные больные места; скрипт ставит подходящие `persist.*`-свойства
и честно отвечает, что не работает, а что нужно править в образе (см. `docs/mediatek-risks.md`).

### Шаг 5. Проверка «это BlueOS»

1. Анимация загрузки — нимб и надпись «BlueOS».
2. «Настройки» → «О телефоне» → версия BlueOS.
3. «Обои и стиль»: страницы «Живые часы», «Виджеты и значки», «Цвета», «Погода», «Движение телефона».
4. На рабочем столе — виджеты BlueOS (часы с нимбом, «Сводка», эквалайзеры, погода).
5. Если виджет погоды пишет «Нет данных о погоде» — «Обои и стиль» → «Погода» → «Город».

### Шаг 6. Если что-то не работает

Собрать логи одной командой:
```
./scripts/collect-logs.sh > blueos-km4k-logs.txt
```
и приложить их к [Issues BlueOS](https://github.com/GDmio/BlueOS/issues) — это единственный способ, которым автор
сможет помочь: телефонов, кроме Pixel 6a, у него нет.

---

## 4. Путь B — своя сборка GSI с BlueOS

Нужен компьютер: **32 ГБ RAM** (+ swap 32–48 ГБ) и **~350 ГБ свободного диска**. В песочнице, где велась разработка
этого комплекта, этого нет (2 CPU / 3 ГБ / 20 ГБ), поэтому сборка здесь не выполнялась — зато есть готовый скрипт:

```
./scripts/build-blueos-gsi.sh
```

Что он делает (по [BUILDING.md](https://github.com/GDmio/BlueOS/blob/main/BUILDING.md) BlueOS):

1. `repo init -u https://github.com/LineageOS/android.git -b lineage-24.0 --git-lfs --no-clone-bundle`
2. `repo sync -j8`
3. локальный манифест `vendor/blueos` + строка подключения в `vendor/extra/product.mk`;
4. `source build/envsetup.sh` — накладываются 52 патча BlueOS; в выводе должно быть `BlueOS: applied …`
   и **ни одного** `BlueOS: FAILED`;
5. `breakfast gsi_arm64 && m systemimage` → `out/target/product/generic_arm64/system.img`.

Дальше образ ставится тем же `install-gsi-dsu.sh` (нужно пережать в `.gz`).

**Зачем собирать самому:** только если в готовом образе не устраивает камера/отпечаток/звук и вы понимаете,
что именно правите (например, `ro.fpsensor.position=1` — это `ro.*`-свойство, его нельзя выставить на живой системе,
только в сборке).

---

## 5. Путь C — полный порт LineageOS под KM4k

Готовых деревьев под TECNO SPARK 40C нет (в [wiki LineageOS](https://wiki.lineageos.org/devices/) KM4k отсутствует,
в GitHub — только TWRP-деревья TECNO для других моделей). Зато **чип тот же самый**, и под MT6768 в LineageOS 24.0
есть законченные деревья:

| Репозиторий | Ветка | Что даёт |
|---|---|---|
| [`LineageOS/android_device_motorola_mt6768-common`](https://github.com/LineageOS/android_device_motorola_mt6768-common/tree/lineage-24.0) | `lineage-24.0` | общий код MT6768: `mt6768.mk`, `BoardConfigCommon.mk`, `fstab.mt6768`, `init.mt6768.rc`, sepolicy, `rro_overlays`, `configs/audio|media` |
| [`LineageOS/android_device_motorola_lamu`](https://github.com/LineageOS/android_device_motorola_lamu/tree/lineage-24.0) | `lineage-24.0` | образец device tree под MT6768: `BoardConfig.mk`, `device.mk`, SKU-пропсы |
| [`LineageOS/android_kernel_xiaomi_mt6768`](https://github.com/LineageOS/android_kernel_xiaomi_mt6768/tree/lineage-24.0) | `lineage-24.0` | GKI-ядро 6.6 под MT6768 (`build.config.gki.aarch64`, `build.config.mtk.aarch64`) |

Заготовки под KM4k (device tree, манифесты, шаблон `proprietary-files.txt`, `extract-files.py`) — в
[`port-to-lineage/`](port-to-lineage/README.md). Там же — список того, что **невозможно** сделать без
заводской прошивки TECNO (DTB/DTBO под KM4k, блобы камеры и IMS).

Оценка трудозатрат: 2–4 недели работы, если делать самому, и это без гарантий, что камера заведётся.

---

## 6. Матрица рисков MediaTek (KM4k)

| Подсистема | Ожидание на GSI | Что делать |
|---|---|---|
| Камера | Чаще всего ломается первой: HAL3 MediaTek на GSI несовместим | `persist.camera.HAL3.enabled=1`, проверка `dumpsys media.camera`; в крайнем случае — сборка с HAL1/ручной правкой |
| Отпечаток | На GSI MediaTek отпечаток обычно **не работает вообще** | `persist.sys.phh.virtual_sensors_are_real=1`, `ro.fpsensor.position=1` (только в сборке), `persist.qfp=false` |
| Звук/динамики | Часто ок, но offload может молчать | проверка `dumpsys media.audio_flinger` |
| Яркость/HBM | Возможны артефакты (зависят от прошивки) | смена прошивки, `persist.sys.display.*` |
| SIM/сеть/звонки | Обычно работают; IMS может не подняться | `dumpsys telephony.registry` |
| Bluetooth | Обычно работает | `dumpsys bluetooth_manager` |
| Wi-Fi | Обычно работает (vendor-драйвер MTK) | — |

Подробности и точные команды — в [`docs/mediatek-risks.md`](docs/mediatek-risks.md).

---

## 7. Состав комплекта

```
README.md                       этот файл
docs/
  mediatek-risks.md             риски MediaTek, твики, диагностика по каждой подсистеме
  rollback.md                   как вернуть стоковую прошивку (и почему нельзя relock)
  widget-tuning.md              пороги виджетов BlueOS и сетка рабочего стола под 720×1600
scripts/
  check-phone.sh                preflight: что телефон вообще способен запустить GSI
  install-gsi-dsu.sh            установка образа через DSU с проверкой SHA-256
  mt-fixes.sh                   MediaTek-твики + диагностика
  collect-logs.sh               собрать логи для Issues
  build-blueos-gsi.sh           сборка своего GSI с BlueOS
  rollback-dsu.sh               откат: снять GSI, вернуть стоковую систему
port-to-lineage/                заготовки полного порта под KM4k (путь C)
tests/
  make-mock-adb.sh              имитация телефона KM4k (телефон не нужен)
  run-tests.sh                  прогон всех скриптов на имитации
```

Все скрипты — POSIX-подобный bash, работают с `adb` из Platform-Tools, читают данные только с телефона
(кроме `install-gsi-dsu.sh`, который пишет образ в `/sdcard/Download/`) и ничего не форматируют молча.

### Проверка комплекта

```
./tests/run-tests.sh
```
Тесты гоняют все скрипты на имитации TECNO KM4k (`tests/mock-bin/adb`): телефон не нужен.
37 проверок — синтаксис, коды возврата, разбор вывода `getprop`/`df`, правильность ключей DSU,
отказ на неверной контрольной сумме, безопасность `--dry-run`.

---

## 8. Если коротко

1. Зарегистрируйте Tecno ID **сегодня** — кнопка OEM Unlocking появится через 14 дней.
2. Подготовьте компьютер: platform-tools, ~20 ГБ свободных на телефоне.
3. `./scripts/check-phone.sh` — убедитесь, что телефон проходит проверки.
4. `./scripts/install-gsi-dsu.sh --image BlueOS-0.8.1-gsi_arm64-20261103.img.gz`.
5. Зашли в BlueOS? `./scripts/mt-fixes.sh` и `./scripts/collect-logs.sh`.
6. Что-то сломалось и нужен сток — `docs/rollback.md`.
