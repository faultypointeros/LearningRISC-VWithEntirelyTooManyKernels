#!/bin/bash

set -xeu

QEMU=qemu-system-riscv64

CC=clang 
CFLAGS="-std=c11 -O2 -g3 -Wall -Wextra --target=riscv64-unknown-elf -fuse-ld=lld -fno-stack-protector -ffreestanding -nostdlib"
$CC $CFLAGS -Wl,-Tkernel.ld  -o kernel.elf \
    kernel.S


# -machine virt: start the virt machine. virt is a generic riscv emulator
# - bios default: use default firmware(OpenSBI)
# -nographic: start qemu with no graphical window
# - serial mon:stdio: connect qemu's stdio to virt machine's serial port. 'mon' allows switching to qemu monitor by pressing C-A then C. 
# --no-reboot: if virtual machine crashes, don't reboot.
$QEMU -machine virt \
    -bios default \
    -nographic \
    -serial mon:stdio \
    --no-reboot \
    -d unimp,guest_errors,cpu_reset \
    -kernel kernel.elf
