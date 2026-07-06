# EC register map — legacy HP OMEN 15

Offsets validated or referenced by the community. **Model-specific** — do not
assume they work on all OMEN laptops without testing.

See [WHAT-WORKS.md](WHAT-WORKS.md) for a full compatibility matrix and
[data/register-map-84DB.json](../data/register-map-84DB.json) for machine-readable
register → RPM data.

## Primary registers (board 84DB)

| Offset (dec) | Offset (hex) | Name | R/W | Works? | Observed effect |
|--------------|--------------|------|-----|--------|-----------------|
| 52 | 0x34 | FAN1_SPEED | rw | **No** | Write persists; no RPM change |
| 53 | 0x35 | FAN2_SPEED | rw | **No** | Write persists; no RPM change |
| 88 | 0x58 | FAN_PERCENT? | rw | **No** | Reflective state (~63–73 in auto); not a setter |
| 98 | 0x62 | BIOS_FLAGS | rw | Partial | `0` = normal; `6` = disable BIOS on other models |
| 99 | 0x63 | BIOS_TIMER | rw | Kernel | Thermal profile timer (hp-wmi) |
| 149 | 0x95 | THERMAL_PROFILE | rw | Kernel | Platform profile (hp-wmi) |
| 236 | **0xEC** | **FAN_BOOST** | rw | **Yes** | `0` = auto, `1` = max; **avoid `2`/`3`** |

## Register value → fan RPM (0xEC only)

Tested on board 84DB with CPU under load (`stress-ng`, package ~88°C).
Auto RPM also varies with temperature at idle.

| Write `0xEC` | Read-back | Mode | fan1 RPM | fan2 RPM | Safe? |
|--------------|-----------|------|----------|----------|-------|
| `0` | `0` | Auto (BIOS) | ~3600 | ~3400 | Yes |
| `1` | `3` | Maximum boost | ~4600 | ~5300 | Yes |
| `2` | `0` | Reduced speed | ~3000 | ~2800 | **No** |
| `3` | `3` | Reduced speed | ~3000 | ~2800 | **No** |

There is **no granular speed control** — offsets `0x34`, `0x35`, and `0x58` do
not provide a usable register-to-RPM curve on 84DB.

### Kernel upstream (hp-wmi) — what already exists

Verified against `drivers/platform/x86/hp/hp-wmi.c` (Linux 7.0.0 / Ubuntu
`7.0.0-27-generic`).

**EC offsets already defined and used** (thermal profile / platform_profile):

```c
HP_OMEN_EC_THERMAL_PROFILE_FLAGS_OFFSET  = 0x62  // 98
HP_OMEN_EC_THERMAL_PROFILE_TIMER_OFFSET  = 0x63  // 99
HP_OMEN_EC_THERMAL_PROFILE_OFFSET        = 0x95  // 149
```

**Board IDs `84DA`, `84DB`, `84DC` are already listed** in
`omen_thermal_profile_boards[]` — but only for ACPI `platform_profile`
(balanced / performance / cool), **not** for fan max via `pwm1_enable`.

**What is missing upstream** (the gap this repo's patch fills):

| Item | In kernel? |
|------|------------|
| `HP_OMEN_EC_FAN_BOOST_OFFSET` (`0xEC`) | No |
| EC write fallback in `hp_wmi_apply_fan_settings()` | No |
| Working `echo 0 > pwm1_enable` (WMI query `0x27`) on 84DB | No — returns `EINVAL` |

On 84DB, `PWM_MODE_MAX` still calls only `hp_wmi_fan_speed_max_set()` (WMI `0x27`).
Recent Victus S / OMEN 2023+ fan-control patches use a different WMI path and do
not cover legacy OMEN 15 (`84D*` boards are absent from
`victus_s_thermal_profile_boards[]`).

Offset **0xEC is not in the kernel** — userspace EC writes or the draft patch in
`kernel/` are required for fan boost on this generation.

## Userspace sequence (workaround)

### Maximum

```python
# Write 1 to 0xEC
with open("/sys/kernel/debug/ec/ec0/io", "r+b") as ec:
    ec.seek(0xEC)
    ec.write(bytes([1]))
```

Requires: `modprobe ec_sys write_support=1` + debugfs mounted.

### Restore auto

```python
with open("/sys/kernel/debug/ec/ec0/io", "r+b") as ec:
    ec.seek(0xEC); ec.write(bytes([0]))
    ec.seek(0x62); ec.write(bytes([0]))
    ec.seek(0x34); ec.write(bytes([0]))
    ec.seek(0x35); ec.write(bytes([0]))
```

## Reading RPM (kernel — preferred)

Do not use EC for RPM on this model. The `hp-wmi` driver exposes:

```
/sys/devices/platform/hp-wmi/hwmon/hwmonN/fan1_input
/sys/devices/platform/hp-wmi/hwmon/hwmonN/fan2_input
```

## Reference EC dump (84DB, idle)

Relevant slice (offset 0x50–0xBF):

```
0x50: 80 00 00 00 00 05 00 00 4f 3f ...
0xB0: 00 00 1b 0e 00 6e 10 51 00 00 01 07 58 56 ...
```

RPM in DSDT at 0xB2+ (NBFC issue) — read via WMI, not direct EC.

## References

- [omen-fan.py](https://github.com/alou-S/omen-fan/blob/main/omen-fan.py) — `BOOST_OFFSET = 236`
- [omen_logic.py](https://github.com/arfelious/omen-fan-control/blob/main/omen_logic.py) — offsets 52/53/98/99
- [Julien ROBIN retro-engineering](https://pix-server-sorel.luoss.fr/Manual/Linux/HP-WMI/Bug-Report-2024-12-12/)
