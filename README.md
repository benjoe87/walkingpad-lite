# Pad Lite — minimal WalkingPad data field for vívoactive 4S

A stripped-down Garmin Connect IQ **data field** that connects a watch to a
KingSmith WalkingPad treadmill over Bluetooth LE and shows treadmill metrics
during an activity.

Built specifically for the **vívoactive 4S**, whose data fields are limited to
**32 KB of memory** — the reason the full-featured
[WalkingPad app](https://apps.garmin.com/apps/97a22cc7-b1d4-463d-9246-017e1f965751)
by Jens-Duttke cannot support this device.

## Supported treadmills

KingSmith models using the **classic WiLink BLE protocol** (service `0xFE00`),
e.g. **WalkingPad R1 Pro / R2 Pro** and re-branded variants (advertised name
like `KS-*`, `WalkingPad`, `DYNAMAX`, `KINGSMITH`).

Newer models (`KS-HD-*`, `KS-MC21-*`, `ZP-ZEALR1-*`, PH4, X21…) use the standard
FTMS profile (`0x1826`) and are **not** supported by this app.

## Features

- Scans, pairs and connects automatically; reconnects on link loss
- Displays speed, distance, steps and belt time
  - **Layout** setting: `All` (multi-line view) or a single metric —
    `Speed` / `Distance` / `Steps` / `Time`
- Optional **Auto start/stop belt**: starts the belt when the activity timer
  starts/resumes, stops it on pause/stop/save (off by default — enable in the
  field's Connect IQ settings)
- Records to the FIT file:
  - graphs: `pad_speed` (km/h), `pad_dist` (m), `pad_steps`
  - session totals: `pad_dist_total` (m), `pad_steps_total`, `pad_time` (s)
- Fits the 32 KB data-field budget (~16 KB used in simulation)

## Protocol

Implemented from community reverse-engineering
([beltcontrol.com protocol notes](https://beltcontrol.com/walkingpad-bluetooth-protocol),
[ph4r05/ph4-walkingpad](https://github.com/ph4r05/ph4-walkingpad)):

- Service `0xFE00`, notify `0xFE01`, write `0xFE02` (write-without-response)
- Commands: `F7 A2 <cmd> <param> <crc> FD`, `crc = (0xA2+cmd+param) & 0xFF`
  - ask stats `00 00`, set speed `01 <0.1 km/h>`, set mode `02 <0/1/2>`, start `04 01`
- Status notifications `F8 A2`, 18 bytes, big-endian:
  state `[2]`, speed×10 `[3]`, mode `[4]`, elapsed s `[5..7]`,
  distance in 10 m units `[8..10]`, steps `[11..13]`
- The pad does not push status on its own — polled ~1 Hz from `compute()`.
  Command frames must be spaced or they are dropped; `pollStats()` drains one
  queued command per call.

## Build

Requirements: Connect IQ SDK + downloaded device files (SDK Manager), JDK 11+.

```bash
# one-time developer key
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -nocrypt -inform PEM -outform DER \
    -in developer_key.pem -out developer_key.der

# build (adjust SDK + java paths in build.sh as needed)
./build.sh        # → bin/walkingpad.prg
```

## Install

Copy `bin/walkingpad.prg` to `GARMIN/APPS/` on the watch over USB, then add
**Connect IQ → Pad Lite** to a data screen in an activity (e.g. Treadmill Run).
Works best alone on a full data screen.

The pad accepts only **one** BLE connection — close the KS Fit / WalkingPad
phone app first, or the watch will never see it.

## Debugging

Crashes and `System.println` output land in `GARMIN/APPS/LOGS/CIQ_LOG.YML`
on the watch.

## License

MIT
