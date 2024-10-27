#!/bin/bash
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root"
    exit 1
fi
if [ -z "$1" ]; then
    echo "Usage: $0 /dev/sdX"
    exit 1
fi
dd if=bin/idbloader.img of=$1 seek=64 conv=notrunc,fsync
dd if=bin/uboot.img of=$1 seek=16384 conv=notrunc,fsync
dd if=bin/trust.img of=$1 seek=24576 conv=notrunc,fsync