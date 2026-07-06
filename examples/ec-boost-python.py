# Manual test of EC offset 0xEC (requires root + ec_sys)

# Prerequisites
sudo modprobe ec_sys write_support=1
sudo mount -t debugfs none /sys/kernel/debug

# Enable maximum
sudo python3 -c "
with open('/sys/kernel/debug/ec/ec0/io', 'r+b') as ec:
    ec.seek(0xEC)
    ec.write(bytes([1]))
"

# Check RPM
sensors hp-isa-0000

# Restore auto
sudo python3 -c "
with open('/sys/kernel/debug/ec/ec0/io', 'r+b') as ec:
    ec.seek(0xEC)
    ec.write(bytes([0]))
"
