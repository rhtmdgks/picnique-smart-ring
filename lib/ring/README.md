# Colmi/Yawell Ring BLE Module

Pure Dart `flutter_blue_plus` **companion-level** stack — no OEM native SDK bridge.
Yawell/QRing RF03 rings: dual GATT channel (16B main + 0xBC big-data).

## Architecture

```
App services (ble_command_queue facade)
        ↓
RingRepository
        ↓
RingCommandQueue ── main write 6e400002 (16B, checksum)
              ├── main notify 6e400003 → PacketCodec (16B)
              ├── big write  de5bf72a  (0xBC cmd)
              └── big notify de5bf729 → BigDataCodec (33B/104B…)
```

**R08 btsnoop finding:** `invalid packet length 33` was big-data frames hitting the 16B parser.
`0x02` = ring heartbeat (ignore). `0x2f` = packet-size indicator (byte[1]=244).

## Device identification (scan)

R08 advertises **fee7 only** — `6e40fff0` / `de5bf728` show up after GATT discovery, not in adv.

- **Scan:** open (no `withServices` UUID filter)
- **Adopt:** `advName` or `platformName` starts with `R0` (e.g. `R08_XXXX`)
- **Post-connect:** probe `0x01` setTime for capabilities

## Architecture

```
lib/ring/
  transport/     FBP connect, notify V1+V2, command queue
  codec/         16-byte packet + checksum
  commands/      Opcode builders + parsers (ported from references)
  capability/    Device allowlist + model matrix
  repository/    RingRepository facade
  features/      Rosary touch (raw accelerometer)
  example/       ring_demo.dart
```

## Opcode ↔ Feature ↔ Source

| Opcode | Feature | Primary Source | Secondary Source |
|--------|---------|----------------|----------------|
| — | GATT V1 service `6E40FFF0` | colmi_r06_fbp | Gadgetbridge YawellRingConstants |
| — | GATT V2 service `DE5BF728` | colmi_r06_fbp | Gadgetbridge |
| — | 16-byte packet + checksum | colmi_r06_fbp `hexStringToCmdBytes` | colmi_r02_client `packet.py` |
| `0x01` | Time sync | colmi_r02_client `set_time.py` | Gadgetbridge |
| `0x03` | Battery query | colmi_r06_fbp | colmi_r02_client `battery.py` |
| `0x08` | Reboot / power off | colmi_r02_client `reboot.py` | Gadgetbridge |
| `0x15` | HR history (daily) | colmi_r02_client `hr.py` | Gadgetbridge |
| `0x16` | HR auto-log settings | colmi_r02_client `hr_settings.py` | Gadgetbridge |
| `0x1E` | Realtime HR stream | Gadgetbridge | — |
| `0x43` | Activity history | colmi_r02_client `steps.py` | Gadgetbridge |
| `0x69/0x01` | Manual HR | colmi_r06_fbp | Gadgetbridge |
| `0x69/0x03` | Manual SpO2 | colmi_r06_fbp | colmi_r02_client `real_time.py` |
| `0x69/0x08` | Manual stress | colmi_r06_fbp | — |
| `0x73/0x0C` | Battery push | colmi_r06_fbp | Gadgetbridge |
| `0x73/0x12` | Live steps/cal/distance | colmi_r06_fbp | Gadgetbridge |
| `0xBC/0x27` | Sleep raw (V2 write) | Gadgetbridge | ring-health-tracker |
| `0xBC/0x2A` | SpO2 history (V2 write) | Gadgetbridge | ring-health-tracker |
| `0xA1/0x03` | Raw accelerometer | colmi_r06_fbp | — |
| `0xFF` | Factory reset | colmi_r06_fbp | Gadgetbridge |

## Capability Matrix

**Default (unknown/OEM): QRing optimistic — all RF03 features enabled until probe refines.**

| Model | SpO2 | Stress | HRV | Temperature | Sleep | Raw Accel |
|-------|------|--------|-----|-------------|-------|-----------|
| R02–R04 | yes | yes | probe | probe | yes | yes |
| R05 | yes | yes | probe | yes | yes | yes |
| R06–R08 | yes | yes | probe | probe | yes | yes |
| R09–R12 | yes | yes | yes | yes | yes | yes |
| H59 / OEM | yes | yes | probe | probe | yes | yes |

`probe` = refined from `0x01` setTime response at connect.

Device names from [ATC_RF03_Ring Known_BLE_OEM_Ring_Names.txt](https://github.com/atc1441/ATC_RF03_Ring/blob/main/Known_BLE_OEM_Ring_Names.txt).

## Licenses

| Reference | License | Files |
|-----------|---------|-------|
| colmi_r06_fbp | BSD-3-Clause | transport, codec, raw parsers |
| colmi_r02_client | MIT | packet codec, set_time, hr, steps, battery |
| Gadgetbridge yawell/ring | AGPL-3.0 | sleep, spo2 big data, constants |
| ATC_RF03_Ring | Check upstream | known_device_names.dart |

## Demo

```dart
import 'package:picnique_rosary_healthcare_smartring/ring/example/ring_demo.dart';

// Navigate to RingDemoScreen — scan → connect → setTime → HR once
```

Or use `RingRepository.instance` directly:

```dart
final repo = RingRepository.instance;
await repo.connect(device);
await repo.setTime.execute();
final hr = await repo.realtimeHr.measureOnce();
```

## Derived Metrics (interface only)

- `SleepDerivedMetrics` — sleep stage scoring not implemented; raw stages only
- Stress/recovery scores — raw stress samples only
