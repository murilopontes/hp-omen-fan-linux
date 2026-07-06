# Supported / investigated hardware

## OMEN 15-dc0xxx (2018–2019)

| Field | Value (reference machine) |
|-------|---------------------------|
| Product | OMEN by HP Laptop 15-dc0xxx |
| Board ID | `84DB` |
| BIOS | F.19 |
| Kernel tested | 7.0.0-27-generic |
| GPU | NVIDIA (nvidia-smi available) |
| Fan driver | `hp-wmi` → hwmon `hp-isa-0000` |

### Related boards (same generation)

These IDs are already listed in `omen_thermal_profile_boards[]` in the kernel:

- `84DA`
- `84DB` ← tested with EC boost control
- `84DC`

**Community request:** confirm whether EC offset `0xEC` also works on `84DA` and `84DC`.

## What works on stock kernel

| Interface | Path | Status |
|-----------|------|--------|
| CPU/GPU fan RPM | `/sys/class/hwmon/hwmon*/fan{1,2}_input` | OK |
| pwm hwmon mode | `/sys/class/hwmon/hwmon*/pwm1_enable` | Present but MAX fails |
| Manual pwm1 | `/sys/class/hwmon/hwmon*/pwm1` | Not exposed |
| platform_profile | `/sys/firmware/acpi/platform_profile` | May be absent on v0 |
| WMI fan max (0x27) | via `pwm1_enable=0` | **EINVAL** |

## What does NOT work on this model

- **NBFC** — confirmed incompatible ([issue #576](https://github.com/hirschmann/nbfc/issues/576))
- **fancontrol / pwmconfig** — no writable PWM sysfs
- **omen-fan** (alou-S) — targets OMEN 16 only; EC offsets partially applicable

## HP OMEN generations on Linux (summary)

| Generation | Example board | Fan control method |
|------------|---------------|-------------------|
| OMEN 15 2018–19 | 84DB | EC `0xEC` + WMI read 0x11 |
| OMEN 16 2020–22 | various | direct `ec_sys` |
| OMEN 16 2023+ | 8BAB, 8C78 | `hp-wmi` Victus-S WMI 0x2D/0x2E |
| OMEN Max 2025+ | 16t-ah0xxx | native hwmon PWM |

See also the [OmenCore Linux guide](https://github.com/theantipopau/omencore/blob/main/docs/LINUX_INSTALL_GUIDE.md).
