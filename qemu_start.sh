#!/bin/bash

IMAGE=$1
#UBOOT=u-boot.bin
qemu-system-riscv64 \
          -m 2G  -machine virt \
          -smp cpus=4 \
	  -device sdhci-pci \
          -drive file=$IMAGE,if=none,id=mmcblk,format=raw \
	  -device virtio-blk-device,drive=mmcblk \
          -serial mon:stdio \
	  -netdev bridge,id=hn0,br=virbr0 \
          -device virtio-net-pci,netdev=hn0,id=nic1 \

