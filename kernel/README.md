# Draft patch — hp-wmi EC fan boost for legacy OMEN 15

**Status:** DRAFT — not tested against the current kernel tree. Requires review and
`make M=drivers/platform/x86/hp modules` testing before submission.

## Apply

```bash
cd /path/to/linux
patch -p1 < 0001-hp-wmi-ec-fan-boost-omen-15-draft.patch
```

## What it does

- Adds `HP_OMEN_EC_FAN_BOOST_OFFSET` (0xEC)
- Defines `omen_ec_fan_boost_boards[]` = 84DA, 84DB, 84DC
- In `hp_wmi_apply_fan_settings()`, uses `ec_write(0xEC, 1)` for `PWM_MODE_MAX`
  when WMI 0x27 is not suitable
- Restores with `ec_write(0xEC, 0)` in `PWM_MODE_AUTO`

## Relationship to upstream

Checked against `hp-wmi.c` in Linux 7.0.0 (`7.0.0-27-generic`). This patch is
**not duplicated** upstream, but there is **partial overlap**:

| Already in kernel | Added by this patch |
|-------------------|---------------------|
| `84DA` / `84DB` / `84DC` in `omen_thermal_profile_boards[]` (platform_profile only) | `omen_ec_fan_boost_boards[]` (fan max via EC) |
| EC offsets `0x62`, `0x63`, `0x95` for thermal profiles | EC offset `0xEC` for fan boost |
| `hp_wmi_fan_speed_max_set()` via WMI query `0x27` | EC fallback when WMI max fails |

On board 84DB, `echo 0 > pwm1_enable` still returns `EINVAL` without this patch.
Recent kernel work for Victus S / OMEN 2023+ (boards `8BCA`, `8BCD`, etc.) adds
WMI-based fan control for newer models; legacy OMEN 15 (`84D*`) is not covered.

A maintainer may ask to drop `omen_ec_fan_boost_boards[]` and gate the EC path on
an existing board list instead — the functional change (write `0xEC` on
`PWM_MODE_MAX` / `PWM_MODE_AUTO`) would remain the same.

See also [docs/EC-REGISTERS.md](../docs/EC-REGISTERS.md).

## Before submitting

1. Rebase against `torvalds/linux` master
2. Confirm `ec_write`/`ec_read` are already available in the driver (they are)
3. Add `Tested-on: OMEN by HP Laptop 15-dc0xxx (board 84DB)`
4. Run `./scripts/checkpatch.pl` with no warnings
5. Confirm no regression on `is_victus_s_thermal_profile()` boards

## Alternative

If the maintainer prefers WMI: investigate why 0x27 fails on 84DB and whether
another GM query exists for this generation.
