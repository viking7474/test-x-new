# P0 Manual Data Guide

This guide is for the canonical fake-device profile pipeline. The goal is to
avoid hand-editing generated JSON and to make every manual data change
reproducible.

## Current source of truth

- `layout/Library/IOS.db`
  - `KMDevices`: ProductType, board/hw model, regulatory A-number, iOS range.
  - `KMOS`: iOS version/build/Darwin/XNU source rows.
- `data/iphone_hardware_db.json`
  - model-level P0 hardware: RAM, display, storage, camera, CPU profile.
- `data/iphone_cellular_db.json`
  - regional cellular capability keyed by regulatory `Axxxx`.
  - the iPhone 15 family currently has 16 explicit slots, all `known=false`.
  - generator publishes these as `cellularByRegulatoryModelNumber`; runtime resolves the exact A-number first.

`KMDevices` also contains legacy CPU/RAM/storage/screen columns. Treat those as
**audit evidence, not the P0 hardware source of truth**. The historical DB has
known stale/incorrect rows (for example the former iPhone14,7/A2846 row), and
older Plus-model display columns use ambiguous render-buffer/native semantics.
Do not bulk-copy those fields into the hardware catalog.
- `data/iphone_model_db.json` and `data/ios_build_db.json`
  - generated outputs. Do not edit these by hand.

## iPhone 15 family status

The repository migration scripts now repair/populate these rows in `IOS.db`:

| ProductType | Name | Board | Regulatory A-numbers |
|---|---|---|---|
| iPhone15,4 | iPhone 15 | D37AP | A2846, A3089, A3090, A3092 |
| iPhone15,5 | iPhone 15 Plus | D38AP | A2847, A3093, A3094, A3096 |
| iPhone16,1 | iPhone 15 Pro | D83AP | A2848, A3101, A3102, A3104 |
| iPhone16,2 | iPhone 15 Pro Max | D84AP | A2849, A3105, A3106, A3108 |

All four start at iOS 17.0 in this database generation. The current `KMOS`
already covers iOS 17.0 through 18.6, so no manual KMOS rows are required merely
to enable these four models.

The source database also had two defects that are now handled by migration:

1. A2846 was attached to `iPhone14,7`; it belongs to `iPhone15,4`.
2. iOS 18.3.1 reused `22C152` (the iOS 18.2 build); it is corrected to
   `22D72`.

## Normal workflow

Run the audit first:

```bat
py scripts\audit_p0_manual_data.py
```

The audit reports:

- missing target models,
- exact `KMDevices` and `KMOS` schema,
- duplicate OSBuild rows,
- conflicting hardware rows inside one ProductType,
- current iPhone 15 board/A-number tuples.

If the source DB is an old copy, dry-run the migrations:

```bat
py scripts\patch_iosdb_iphone15.py
py scripts\patch_iosdb_known_fixes.py
```

Apply only after the dry-run is correct:

```bat
py scripts\patch_iosdb_iphone15.py --apply
py scripts\patch_iosdb_known_fixes.py --apply
```

Then regenerate outputs:

```bat
py scripts\build_ios_db.py
```

Run the focused gates:

```bat
py scripts\test_p0_canonical_hardware_static.py
py scripts\test_iosdb_regression_static.py
py scripts\test_hardware_profile_sync_static.py
py scripts\test_phase2_validator_static.py
```

Finally run the wider regression:

```bat
py scripts\release_hardening.py regression --iterations 2
git diff --check
```

## Data that still requires authoritative manual input

### 1. Regional cellular capability

Do not infer physical-SIM/eSIM behavior from ProductType alone. It can differ by
regulatory A-number/region.

For each regulatory A-number that you want to mark as verified, collect:

- `enabled`
- `physicalSIM`
- `eSIM`
- `dualSIM`
- `cdma` (only if the exact variant genuinely supports the legacy identity)
- `imeiTACs`: one or more **verified 8-digit TACs** for that exact regional model
- `meidPrefixes`: required only when `cdma=true`

The manual edit point is **only** `data/iphone_cellular_db.json`. Each key is a
regulatory A-number, for example:

```json
"A2846": {
  "known": false
}
```

Do not change `known` to `true` merely because the phone is obviously cellular.
The current dependency contract intentionally requires a coherent baseband
identity when a cellular model is declared known. First collect the regional
capability **and** the matching baseband dataset; otherwise leave:

```json
{
  "known": false
}
```

When the baseband dataset is ready, a verified regional row has this shape:

```json
"Axxxx": {
  "known": true,
  "enabled": true,
  "physicalSIM": true,
  "eSIM": true,
  "dualSIM": true,
  "cdma": false,
  "imeiTACs": [
    "REPLACE_WITH_VERIFIED_8_DIGIT_TAC"
  ]
}
```

If `cdma=true`, also provide:

```json
"meidPrefixes": [
  "REPLACE_WITH_VERIFIED_6_HEX_PREFIX"
]
```

These are schema templates, not values to copy. `build_ios_db.py` rejects
non-8-digit TACs, rejects missing MEID prefixes for CDMA rows, and keeps
`known=false` as a valid explicit unknown state. After editing, run
`py scripts\\audit_p0_manual_data.py`; the audit lists every still-pending A-number
and rejects orphan regulatory numbers.

Until verification is complete, the runtime fails closed rather than fabricating
IMEI2/MEID/SIM capability.

### 2. Retail ModelNumber / SKU

`A2846`, `A3108`, etc. are regulatory model numbers. They are not the
MobileGestalt/IOKit retail `ModelNumber` value.

Keep them in:

```text
RegulatoryModelNumber
```

Do not copy them into:

```text
ModelNumber
```

If retail SKU spoofing is required later, collect the exact retail SKU base
(`MT...`, `MU...`, etc.) with its region/storage/color relation and add it as a
separate data set.

### 3. Build-specific baseband firmware

Baseband firmware is not a model-level constant. The manual source is:

```text
data/iphone_baseband_db.json
```

It is keyed in two layers:

```text
RegulatoryModelNumber -> basebandFamily
basebandFamily + IOSBuild -> BasebandVersion
```

Keep the A-number row as `known=false` until the modem family and **every iOS
build currently supported by that ProductType** have verified firmware values.
The generator intentionally requires complete build coverage so random profile
generation can never select an iOS build with unknown baseband.

To avoid manually discovering the required build list, export a worksheet:

```bat
py scripts\export_p1_manual_template.py --output p1_manual_template.json
```

The current iPhone 15-family worksheet contains 16 regional A-number records and
derives the required IOSBuild list directly from `deviceToBuilds`. Fill the
worksheet from authoritative observations/source material.

Validate the worksheet without changing source data:

```bat
py scripts\import_p1_manual_data.py p1_manual_template.json
```

If the dry-run reports PASS, apply it:

```bat
py scripts\import_p1_manual_data.py p1_manual_template.json --apply
py scripts\build_ios_db.py
```

The importer verifies ProductType/A-number ownership, boolean capability fields,
8-digit IMEI TACs, MEID prefix format, exact supported IOSBuild coverage and
conflicting firmware values inside one baseband family. It updates only
`iphone_cellular_db.json` and `iphone_baseband_db.json`; do not hand-edit the
generated model/build JSON.

Schema shape:

```json
{
  "families": {
    "REPLACE_WITH_VERIFIED_MODEM_FAMILY": {
      "builds": {
        "21A329": "REPLACE_WITH_VERIFIED_BASEBAND_VERSION"
      }
    }
  },
  "regulatoryModels": {
    "Axxxx": {
      "known": true,
      "productType": "iPhoneXX,Y",
      "basebandFamily": "REPLACE_WITH_VERIFIED_MODEM_FAMILY"
    }
  }
}
```

Do not derive firmware from the iOS version string and do not reuse a nearby
model's modem family. `build_ios_db.py` rejects unknown IOSBuilds, mismatched
ProductType ownership, incomplete build coverage, and a known baseband row whose
cellular row is still unknown/disabled.

## Fields you do NOT need to fill for P0

The current P0 generator does not consume these legacy `KMDevices` columns:

- `sale_country`
- `battery_voltage`
- `battery_capacity`
- `bootrom`
- `sc_size`
- `sc_size_dev`
- `x_statubar_h`
- `x_botom_h`
- `x_can_faceID`

Leave them NULL rather than copying values from another model.

## If adding a new iPhone generation later

Do not edit generated JSON first.

1. Add verified model-level hardware to `data/iphone_hardware_db.json`.
2. Add exact `KMDevices` rows to `IOS.db`:
   - `identifier`
   - `internal_name`
   - `anumber`
   - `generation`
   - `defaultOSV`
   - `maxOSV`
3. Ensure `KMOS` contains the supported build range with unique `OSBuild`
   values and valid Darwin/XNU banners.
4. Run `audit_p0_manual_data.py`.
5. Regenerate with `build_ios_db.py`.
6. Run all P0/regression gates.

Never reuse a nearby model's BoardID, A-number, storage tier, display geometry,
kernel tuple, or baseband value just because the devices are in the same family.
