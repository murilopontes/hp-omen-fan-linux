# HP OMEN Fan Control — Linux

Research and tools for **HP OMEN** laptop fan control on Linux,
focused on **OMEN 15-dc0xxx** (board `84DB`, ~2018–2019).

The stock `hp-wmi` driver reads RPM but **cannot** enable max fan mode via WMI
(`pwm1_enable=0` → `EINVAL`). The working approach is EC register **`0xEC`** (boost).

**Repository:** https://github.com/murilopontes/hp-omen-fan-linux

```bash
cd scripts
sudo ./omen-fan-config.sh max      # fans at maximum
sudo ./omen-fan-config.sh auto     # return control to BIOS
./omen-fan-config.sh status
```

## Repository layout

```
hp-omen-fan-linux/
├── README.md
├── LICENSE                   # GPL-2.0 (Linux kernel compatible)
├── CONTRIBUTING.md
├── docs/
│   ├── HARDWARE.md           # models and known board IDs
│   ├── EC-REGISTERS.md       # EC register map
│   ├── TEST-RESULTS.md       # test results (84DB)
│   └── KERNEL-UPSTREAM.md    # kernel submission guide
├── scripts/
│   ├── omen-fan-config.sh    # userspace tool (ready to use)
│   ├── omen-fan-daemon.sh    # keep-alive for max mode
│   ├── collect-evidence.sh   # gather data for bug reports
│   └── benchmark-fan.sh      # compare auto vs max RPM
├── kernel/
│   ├── README.md             # patch instructions
│   └── 0001-hp-wmi-ec-fan-boost-omen-15-draft.patch
├── data/
│   ├── boards.json           # board IDs and control methods
│   └── evidence-84DB.txt     # evidence from reference hardware
└── examples/
    ├── omen-fan-max.service  # example systemd unit
    └── ec-boost-python.py    # minimal EC write example
```

## Results (board 84DB)

| Mode | fan1 | fan2 |
|------|------|------|
| Auto (BIOS) | ~3600 RPM | ~3400 RPM |
| EC boost (`0xEC=1`) | ~4600 RPM | ~5300 RPM |

## Contributing

1. **Test** on another OMEN 15 (`84DA`, `84DC`) and submit `data/evidence-*.txt`
2. **Kernel** — see [docs/KERNEL-UPSTREAM.md](docs/KERNEL-UPSTREAM.md)
3. **Related projects** — [omen-fan](https://github.com/alou-S/omen-fan), [omen-fan-control](https://github.com/arfelious/omen-fan-control), [OmenCore](https://github.com/theantipopau/omencore)

## References

- Kernel driver: `drivers/platform/x86/hp/hp-wmi.c`
- Mailing list: platform-driver-x86@vger.kernel.org
- HP WMI bug report (Dec 2024): [Julien ROBIN](https://www.spinics.net/lists/platform-driver-x86/msg49417.html)
- NBFC issue OMEN 15-dc0xxx: [hirschmann/nbfc#576](https://github.com/hirschmann/nbfc/issues/576)

## Disclaimer

Writing to the EC can affect thermal management. Use at your own risk.
Prefer `hp-wmi` kernel integration (patch in `kernel/`) over userspace scripts in production.
