# Contributing to the Linux kernel

## Goal

Upstream EC fan boost support in `hp-wmi` for legacy OMEN 15 boards (`84DA`, `84DB`, `84DC`).

## Patch

See [kernel/README.md](../kernel/README.md) and
`kernel/0001-hp-wmi-ec-fan-boost-omen-15-draft.patch`.

## Before you send

1. Rebase against [torvalds/linux](https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git) `master`
2. Build and test `hp-wmi.ko` on affected hardware
3. Gather evidence: `sudo ./scripts/collect-evidence.sh`
4. Run `scripts/checkpatch.pl` on the patch (from the kernel tree)

## Submission

Send to **platform-driver-x86@vger.kernel.org** with:

- Subject: `[PATCH] platform/x86: hp-wmi: EC fan boost for legacy OMEN 15`
- `Signed-off-by:` line (see [Developer Certificate of Origin](https://developercertificate.org/))
- `Tested-on:` with your model and board ID
- Attach `data/evidence-BOARD.txt` or paste relevant `dmesg` / `hwmon` output

## References

- Driver: `drivers/platform/x86/hp/hp-wmi.c`
- Mailing list archive: [platform-driver-x86](https://lore.kernel.org/platform-driver-x86/)
- Prior report (Dec 2024): [Julien ROBIN](https://www.spinics.net/lists/platform-driver-x86/msg49417.html)
- Repository: https://github.com/murilopontes/hp-omen-fan-linux
