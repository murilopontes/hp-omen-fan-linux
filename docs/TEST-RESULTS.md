# Test results — board 84DB

Machine: **OMEN by HP Laptop 15-dc0xxx**, BIOS F.19, kernel 7.0.0-27-generic.

Initial test date: 2026-07-06.

## Summary

| Test | Result |
|------|--------|
| `sensors hp-isa-0000` | fan1/fan2 readable |
| `echo 0 > pwm1_enable` | EINVAL (driver WMI max fails) |
| `echo 1 > pwm1_enable` | EOPNOTSUPP (no manual pwm1) |
| `EC 0xEC = 1` | RPM rises ~3600→4600 / ~3400→5300 |
| `EC 0xEC = 0` | Restores BIOS control (may lag if CPU is hot) |
| stress-ng 15s in auto | RPM stable ~3600 (BIOS already aggressive when hot) |

## Measured RPM

### Auto mode (baseline, CPU ~76°C)

```
fan1: 3599 RPM
fan2: 3401 RPM
```

### After EC boost (`0xEC = 1`)

```
fan1: 4597 RPM
fan2: 5297 RPM
```

### Temperatures during test

```
Package id 0: +76°C
GPU: 81°C
NVMe Composite: +52°C
```

## Commands used

```bash
# Baseline
sensors hp-isa-0000

# Kernel attempt (fails)
echo 0 | sudo tee /sys/class/hwmon/hwmon7/pwm1_enable
# → Invalid argument

# EC workaround
sudo python3 -c "
with open('/sys/kernel/debug/ec/ec0/io','r+b') as f:
    f.seek(236); f.write(bytes([1]))
"
sleep 5
sensors hp-isa-0000
```

## Full benchmark

```bash
cd scripts
sudo ./benchmark-fan.sh
```

Writes a report to `data/benchmark-YYYYMMDD.txt`.

## Submit your results

```bash
sudo ./scripts/collect-evidence.sh
```

Attach the output in an issue/PR or email to platform-driver-x86@vger.kernel.org.
