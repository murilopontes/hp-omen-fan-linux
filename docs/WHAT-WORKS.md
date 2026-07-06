# What works and what does not — HP OMEN 15 (board 84DB)

Compatibility matrix for **OMEN by HP Laptop 15-dc0xxx** (board `84DB`),
BIOS F.19, kernel `7.0.0-27-generic`.

Test dates: 2026-07-06. See also [TEST-RESULTS.md](TEST-RESULTS.md) and
[EC-REGISTERS.md](EC-REGISTERS.md).

## Quick reference

| Goal | Works? | Method |
|------|--------|--------|
| Read fan RPM | **Yes** | `sensors hp-isa-0000` or `fan{1,2}_input` sysfs |
| Force fans to maximum | **Yes** | EC write `0xEC = 1` |
| Return to BIOS auto control | **Yes** | EC write `0xEC = 0` (+ restore sequence) |
| Set a specific RPM (e.g. 50%) | **No** | No granular control on 84DB |
| Kernel `pwm1_enable=0` (WMI max) | **No** | Returns `EINVAL` |
| Manual `pwm1` PWM control | **No** | Not exposed in hwmon |
| NBFC | **No** | Incompatible ([issue #576](https://github.com/hirschmann/nbfc/issues/576)) |
| `fancontrol` / `pwmconfig` | **No** | No writable PWM sysfs |
| Per-fan speed via `0x34` / `0x35` | **No** | Writes accepted but no RPM change |
| Fan percent via `0x58` | **No** | Unreliable; appears to reflect internal state |

## Kernel interfaces

### Works

| Interface | Path | Notes |
|-----------|------|-------|
| Fan RPM read | `/sys/devices/platform/hp-wmi/hwmon/hwmonN/fan1_input` | WMI query `0x11` |
| Fan RPM read | `sensors hp-isa-0000` | Same data via lm-sensors |
| `pwm1_enable` read | `.../pwm1_enable` | `2` = auto mode |
| `pwm1_enable` write auto | `echo 2 > pwm1_enable` | Restores auto flag in driver |
| EC read/write | `/sys/kernel/debug/ec/ec0/io` | Needs `ec_sys write_support=1` + root |

### Does not work

| Interface | Expected | Actual on 84DB |
|-----------|----------|----------------|
| `echo 0 > pwm1_enable` | Max fan via WMI `0x27` | **EINVAL** — WMI call fails |
| `echo 1 > pwm1_enable` | Manual PWM | **EOPNOTSUPP** — no `pwm1` attribute |
| `platform_profile` | balanced / performance / cool | May be absent on this BIOS |
| Kernel patch (stock) | EC boost in `hp_wmi_apply_fan_settings()` | Not upstream yet — use `kernel/` draft |

## EC register control (board 84DB)

### `0xEC` (236) — FAN_BOOST — the only reliable control

| Write | Read-back | Effect | fan1 RPM* | fan2 RPM* |
|-------|-----------|--------|-----------|-----------|
| `0` | `0` | Auto (BIOS thermal curve) | ~3600 | ~3400 |
| `1` | `3` | **Maximum boost** | ~4600 | ~5300 |
| `2` | `0` | **Dangerous — reduces fans** | ~3000 | ~2800 |
| `3` | `3` | **Dangerous — reduces fans** | ~3000 | ~2800 |

\*Measured with CPU under load (`stress-ng`, package ~88°C). In auto mode, RPM
also depends on temperature — a warm idle machine may already show ~4400/4200 RPM
without boost.

**Important:** Only write `0` or `1` to `0xEC`. Values `2` and `3` **lower** fan
speed below the BIOS curve. The EC may rewrite `1` to `3` on read-back; this is
normal.

### `0x34` (52) — FAN1_SPEED — does not work

Community-documented offset ([omen-fan-control](https://github.com/arfelious/omen-fan-control)).
On 84DB, values `0–255` were written and persisted in EC RAM, but **fan RPM did
not change** in any consistent way.

### `0x35` (53) — FAN2_SPEED — does not work

Same as `0x34`. No isolated effect on fan2 RPM.

### `0x58` (88) — FAN_PERCENT? — does not work as control

| Observation | Detail |
|-------------|--------|
| Read in auto | Typically `63–73` (varies with thermal state) |
| Write `0–120` | RPM stays ~4000 or ~4400 depending on load; no linear mapping |
| Write `100` (one run) | Brief spike to ~4600/5200, not reproducible as stable control |
| Write `128+` | RPM dropped to ~4000 in some tests |

**Conclusion:** Treat `0x58` as internal/reflective state, not a speed setter.

### `0x62` (98) — BIOS_FLAGS

| Value | Effect on 84DB |
|-------|----------------|
| `0` | Normal — used in restore sequence |
| `6` | Documented by [omen-fan](https://github.com/alou-S/omen-fan) to disable BIOS fan control on other models; **not required** for boost on 84DB |

### Other EC offsets

| Offset | Name | Control? |
|--------|------|----------|
| `0x63` (99) | BIOS_TIMER | Thermal profile timer — kernel only |
| `0x95` (149) | THERMAL_PROFILE | Platform profile — kernel only |

## Userspace tools in this repo

| Tool | Status | Notes |
|------|--------|-------|
| `scripts/omen-fan-config.sh max` | **Works** | Writes `0xEC=1` |
| `scripts/omen-fan-config.sh auto` | **Works** | Restores `0xEC`, `0x62`, `0x34`, `0x35` to `0` |
| `scripts/omen-fan-daemon.sh` | **Works** | Re-applies `0xEC=1` every 60s |
| `scripts/benchmark-fan.sh` | **Works** | Compares auto vs max RPM |
| `scripts/collect-evidence.sh` | **Works** | Gathers DMI, hwmon, EC state |
| `examples/ec-boost-python.py` | **Works** | Minimal EC write example |
| `kernel/0001-...-draft.patch` | **Untested upstream** | Draft for `hp-wmi` EC fallback |

## Prerequisites for EC writes

1. Root (`sudo`)
2. debugfs mounted: `/sys/kernel/debug`
3. `modprobe ec_sys write_support=1`
4. Secure Boot may block `ec_sys` module loading

## Related boards (84DA, 84DC)

Same generation as 84DB. EC boost at `0xEC` is **assumed** to work but **not
confirmed** on hardware other than 84DB. Please run `collect-evidence.sh` and
`benchmark-fan.sh` and submit results.

## Other OMEN generations (not 84DB)

| Generation | Board example | Method |
|------------|---------------|--------|
| OMEN 16 2020–22 | various | Direct `ec_sys` (different offsets) |
| OMEN 16 2023+ | 8BAB, 8C78 | `hp-wmi` WMI `0x2D`/`0x2E` |
| OMEN Max 2025+ | 16t-ah0xxx | Native hwmon PWM |

Do **not** assume 84DB offsets work on these models.

## How to verify on your machine

```bash
# 1. Evidence collection
sudo ./scripts/collect-evidence.sh

# 2. Auto vs max benchmark
cd scripts && sudo ./benchmark-fan.sh

# 3. Manual EC test (with CPU load for visible difference)
stress-ng --cpu 6 --timeout 30s &
sleep 20
sensors hp-isa-0000                    # auto baseline
sudo ./omen-fan-config.sh max
sleep 10
sensors hp-isa-0000                    # should rise ~3600→4600 / ~3400→5300
sudo ./omen-fan-config.sh auto
```

## References

- [EC-REGISTERS.md](EC-REGISTERS.md) — full register map
- [TEST-RESULTS.md](TEST-RESULTS.md) — raw benchmark data
- [data/boards.json](../data/boards.json) — machine-readable board data
- [data/register-map-84DB.json](../data/register-map-84DB.json) — register → RPM mapping
