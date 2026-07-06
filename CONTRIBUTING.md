# Contributing

## For users

1. Test the scripts in `scripts/` on your OMEN laptop
2. Run `sudo ./scripts/collect-evidence.sh` and add `data/evidence-BOARD.txt`
3. If you have an OMEN 15 with board `84DA` or `84DC`, confirm whether EC `0xEC` works

## For kernel developers

1. Read [docs/KERNEL-UPSTREAM.md](docs/KERNEL-UPSTREAM.md)
2. Rebase the patch in `kernel/0001-*.patch` against linux.git `master`
3. Test the compiled `hp-wmi.ko` module
4. Send to platform-driver-x86@vger.kernel.org

## For integrators (OmenCore, omen-fan-control, etc.)

Useful data in this repo:

| File | Contents |
|------|----------|
| `data/boards.json` | Board IDs and control methods |
| `docs/EC-REGISTERS.md` | Documented EC offsets |
| `scripts/omen-fan-config.sh` | Userspace reference implementation |

### Suggested minimal API for other projects

```python
OMEN_15_EC_FAN_BOOST = 0xEC  # write 1 = max, 0 = auto

def set_fan_max_ec():
    with open("/sys/kernel/debug/ec/ec0/io", "r+b") as ec:
        ec.seek(OMEN_15_EC_FAN_BOOST)
        ec.write(bytes([1]))
```

Preferred future interface (with kernel patch):

```bash
echo 0 > /sys/class/hwmon/hwmonN/pwm1_enable  # max
echo 2 > /sys/class/hwmon/hwmonN/pwm1_enable  # auto
```
