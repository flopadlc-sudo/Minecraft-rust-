# Порт LineageOS 24.0 под TECNO SPARK 40C (KM4k)

Это заготовка (path C в корневом `README.md`). Это **не** готовая сборка: здесь лежит каркас device tree
и список того, что нужно добыть с телефона и из заводской прошивки.

Оценка трудозатрат: **2–4 недели** работы при знании темы, без гарантий, что камера заведётся.
Начинать с этого пути стоит, только если путь A (GSI) не дал нужного результата.

---

## 1. Почему за основу берётся MT6768

KM4k построен на MediaTek Helio G81 — это **MT6768**. Под этот чип в LineageOS 24.0 уже есть законченные
деревья, и они на том же чипе, что и TECNO:

| Репозиторий | Ветка | Роль |
|---|---|---|
| [`LineageOS/android_device_motorola_mt6768-common`](https://github.com/LineageOS/android_device_motorola_mt6768-common/tree/lineage-24.0) | `lineage-24.0` | общий код MT6768: `mt6768.mk`, `BoardConfigCommon.mk`, `init/fstab.mt6768`, `init/init.mt6768.rc`, sepolicy, `odm/manifest_*.xml` |
| [`LineageOS/android_device_motorola_lamu`](https://github.com/LineageOS/android_device_motorola_lamu/tree/lineage-24.0) | `lineage-24.0` | образец device tree под MT6768 (Motorola Moto G42/G53-подобные) |
| [`LineageOS/android_kernel_xiaomi_mt6768`](https://github.com/LineageOS/android_kernel_xiaomi_mt6768/tree/lineage-24.0) | `lineage-24.0` | GKI-ядро под MT6768 (`build.config.gki.aarch64`, `build.config.mtk.aarch64`) |

**Важно:** чипсет общий, но устройства разные. У TECNO свои DTB/DTBO, свой vendor, своя камера.
Поэтому Motorola-деревья — это **образец структуры**, а не готовые блобы.

---

## 2. Что нужно добыть (блокеры, которые нельзя обойти)

### 2.1. Заводская прошивка TECNO SPARK 40C (KM4k)

Нужна для:

* **DTB/DTBO под KM4k.** Tecno исходники ядра **не публикует** ([wall of shame](https://github.com/zenfyrdev/bootloader-unlock-wall-of-shame/blob/main/brands/tecno/README.md)),
  поэтому DT собирается не из исходников, а берётся из стоковой прошивки (`boot.img` / `dtbo.img`).
  Это рабочий подход: prebuilt DT + GKI-ядро, как и сделано в `motorola_lamu`
  (`BOARD_PREBUILT_DTBOIMAGE := $(TARGET_KERNEL_DIR)/dtbo.img`).
* **Отсылки для `extract-files.py`** — заголовок `# Unpinned blobs from ...` с точным build fingerprint.

Где искать: официальный сайт TECNO (раздел поддержки SPARK 40C) либо форумы. Проверяйте модель:
в слоте `ro.product.device` должно быть `KM4k`, в названии прошивки — TECNO SPARK 40C.

### 2.2. Блобы с телефона

`extract-files.py` вытаскивает проприетарные файлы прямо с устройства (нужен разблокированный загрузчик
и root через adb). Список — в `proprietary-files.txt`; здесь лежит **шаблон**, а не готовый список.

> ⚠️ **Юридически важно.** Блобы — проприетарные файлы производителя. Вытаскивать их со **своего**
> телефона для **своего** использования — обычная практика LineageOS. Публиковать их в публичном
> репозитории нельзя. `vendor/tecno/km4k` с блобами в публичный репозиторий **не выкладывайте**.

### 2.3. Разблокировка загрузчика

См. `notes/tecno-unlock.md`. Без неё ни GSI, ни сборка с блобами невозможны.

---

## 3. Порядок работ

1. **Разблокировать загрузчик**, сохранить данные. Дождаться кнопки OEM Unlocking (≥14 дней с регистрации Tecno ID).
2. **Собрать чистую LineageOS** по этому каркасу **без** BlueOS. Сначала должна заработать LineageOS —
   иначе ошибки BlueOS невозможно отделить от ошибок дерева устройства.
3. **Проверить на телефоне**: загрузка, Wi-Fi, звук, SIM, камера, отпечаток. Что не работает — править здесь.
4. **Только потом** добавлять BlueOS по [BUILDING.md](https://github.com/GDmio/BlueOS/blob/main/BUILDING.md):
   ```
   mkdir -p vendor/extra
   echo '$(call inherit-product, vendor/blueos/config/blueos.mk)' >> vendor/extra/product.mk
   ```
   и убедиться, что в выводе `source build/envsetup.sh` нет строк `BlueOS: FAILED`.

---

## 4. Каркас в этом каталоге

```
port-to-lineage/
├── README.md
├── notes/
│   └── tecno-unlock.md              разблокировка загрузчика TECNO
├── local_manifests/
│   └── km4k.xml                     подключение device tree в сборку
└── device/tecno/km4k/
    ├── AndroidProducts.mk
    ├── Android.bp
    ├── BoardConfigCommon.mk         параметры платы: разделы, A/B, загрузчик, экран
    ├── BoardConfig.mk               плотность, ядро, пути к блобам
    ├── device.mk                    продукт: экран 720×1600, SKU, наследование mt6768.mk
    ├── lineage_common.mk            общие куски для всех SKU
    ├── lineage_km4k.mk              продукт lineage_km4k
    ├── lineage.dependencies         зависимости (mt6768-common, ядро)
    ├── extract-files.py             вытягивание блобов с телефона
    ├── proprietary-files.txt        ШАБЛОН списка блобов — заполняется под KM4k
    ├── product.prop
    └── vendor.prop
```

### Как это подключить к сборке

Скопируйте каталоги в корень исходников LineageOS:

```bash
cp -r port-to-lineage/local_manifests/km4k.xml .repo/local_manifests/
mkdir -p device/tecno
cp -r port-to-lineage/device/tecno/km4k device/tecno/
```

`km4k.xml` подключает `device/tecno/km4k` и ядро. Дальше:

```bash
source build/envsetup.sh
breakfast km4k
m bacon
```

`breakfast` в LineageOS 24 работает по дереву устройства в `device/<производитель>/<устройство>` —
имя `km4k` подхватится, если в каталоге есть `AndroidProducts.mk` с `lineage_km4k.mk`.

### Что нужно доделать руками

| Файл | Что исправить |
|---|---|
| `BoardConfigCommon.mk` | `BOARD_SUPER_PARTITION_SIZE` — под размер super-раздела TECNO; `AB_OTA_PARTITIONS` — под фактические разделы; имя группы `BOARD_SUPER_PARTITION_GROUPS` с `motorola_` на `tecno_` |
| `BoardConfig.mk` | `TARGET_SCREEN_DENSITY` — **320** для 720×1600; `TARGET_KERNEL_DEVICE`, `TARGET_KERNEL_DIR` — под фактическое ядро; `TARGET_PREBUILT_KERNEL`, `BOARD_PREBUILT_DTBOIMAGE` — файлы из стоковой прошивки KM4k |
| `device.mk` | `TARGET_SCREEN_WIDTH := 720`, `TARGET_SCREEN_HEIGHT := 1600`; `PRODUCT_SHIPPING_API_LEVEL := 35`; SKU-свойства под TECNO (`ro.boot.hardware.sku`) |
| `init/fstab.mt6768` (в `mt6768-common`) | пути разделов TECNO (имена разделов Transsion часто отличаются) |
| `proprietary-files.txt` | заполнить списком, полученным с KM4k |
| `extract-files.py` | `namespace_imports` → свои; blob-фиксы под TECNO |

---

## 5. Что должно взять ядро

Ориентир из `motorola_lamu/BoardConfig.mk`:

```makefile
BOARD_KERNEL_SEPARATED_DTBO := true
TARGET_KERNEL_DEVICE := mgk_64_k66
TARGET_KERNEL_DIR := $(KERNEL_PATH)/6.6
TARGET_PROVIDES_STATIC_MODULE_LISTS := true
BOARD_KERNEL_MODULE_DIR := $(TARGET_KERNEL_DIR)
BOARD_PREBUILT_DTBOIMAGE := $(TARGET_KERNEL_DIR)/dtbo.img
TARGET_PREBUILT_KERNEL := $(TARGET_KERNEL_DIR)/$(BOARD_KERNEL_IMAGE_NAME)
BOARD_VENDOR_KERNEL_MODULES += \
    $(BOARD_KERNEL_MODULE_DIR)/fmradio_drv_mt6631.ko \
    $(BOARD_KERNEL_MODULE_DIR)/gps_drv_stp.ko \
    $(BOARD_KERNEL_MODULE_DIR)/wlan_drv_gen4m_6768.ko \
    $(BOARD_KERNEL_MODULE_DIR)/wmt_chrdev_wifi.ko \
    $(BOARD_KERNEL_MODULE_DIR)/wmt_drv.ko
```

Для KM4k набор модулей другой — берите список из стоковой прошивки:
```
fastboot boot boot.img   # или распакуйте boot.img из прошивки
lsmod | grep -E "wlan|wmt|fmradio|gps"
```
и кладите в `device/tecno/km4k-kernels/6.6/` вместе с `dtbo.img` и ядром.

---

## 6. Реалистичные ожидания по подсистемам

| Подсистема | Ожидание в полном порте | Почему |
|---|---|---|
| Загрузка | высокий шанс | тот же SoC, то же дерево MT6768 |
| Wi-Fi/Bluetooth/SIM | высокий | вендорные блобы TECNO подставляются как есть |
| Звук | высокий | `mt6768.mk` подключает `audio.primary.default` и `MtkInCallService` |
| Камера | средний | HAL3 MediaTek под Android 17 может не завестись; в `mt6768-common` есть `blob-patches/` (0001-0022) под IMS — их надо перенести и починить под TECNO |
| Отпечаток | средний | `hal_fingerprint_default.te` в дереве общий, но HAL-адаптер под TECNO другой |
| IMS/звонки | средний | blob-патчи Motorola не применимы к блобам TECNO напрямую |
| OTA | средний | A/B-обновления требуют точных `AB_OTA_PARTITIONS` |

---

## 7. Полезные ссылки

* [LineageOS wiki: сборка под своё устройство](https://wiki.lineageos.org/devices/)
* [LineageOS `android_device_motorola_mt6768-common`](https://github.com/LineageOS/android_device_motorola_mt6768-common/tree/lineage-24.0)
* [LineageOS `android_device_motorola_lamu`](https://github.com/LineageOS/android_device_motorola_lamu/tree/lineage-24.0)
* [LineageOS `android_kernel_xiaomi_mt6768`](https://github.com/LineageOS/android_kernel_xiaomi_mt6768/tree/lineage-24.0)
* [BlueOS BUILDING.md](https://github.com/GDmio/BlueOS/blob/main/BUILDING.md) и [PORTING.md](https://github.com/GDmio/BlueOS/blob/main/PORTING.md)
* [TheMuppets](https://github.com/TheMuppets) — готовые блобы для популярных устройств (для TECNO KM4k их нет)
