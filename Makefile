SHELL=/bin/bash
CROSS_COMPILE = riscv64-linux-gnu-

export K230_SDK_ROOT := $(shell pwd)
export BUILD_DIR := $(K230_SDK_ROOT)/output

OPENSBI_SRC_PATH         = src/opensbi
LINUX_SRC_PATH           = src/linux
UBOOT_SRC_PATH           = src/u-boot

CONFIG_DBGLV ?=0
export KCFLAGS=-DDBGLV=$(CONFIG_DBGLV)

export OPENSBI_BUILD_DIR	:= $(BUILD_DIR)/opensbi
export LINUX_BUILD_DIR		:= $(BUILD_DIR)/linux
export UBOOT_BUILD_DIR		:= $(BUILD_DIR)/u-boot
export IMAGE_DIR		:= $(BUILD_DIR)/images

LINUX_KERNEL_DEFCONFIG	= k230_canmv_defconfig
UBOOT_DEFCONFIG		= k230_canmv_defconfig
LINUX_CONFIG = $(LINUX_BUILD_DIR)/.config
LINUX_IMAGE = $(LINUX_BUILD_DIR)/arch/riscv/boot/Image
FW_PAYLOAD = $(OPENSBI_BUILD_DIR)/platform/generic/firmware/fw_payload.bin

export UBOOT_DEFCONFIG

.PHONY: all
all .DEFAULT: $(IMAGE_DIR)/sysimage-sdcard.img

$(LINUX_CONFIG): Makefile
	+$(MAKE) -C "$(LINUX_SRC_PATH)" O=$(LINUX_BUILD_DIR) \
		CROSS_COMPILE=$(CROSS_COMPILE) ARCH=riscv \
		$(LINUX_KERNEL_DEFCONFIG)

$(LINUX_IMAGE): $(LINUX_CONFIG)
	+$(MAKE) -C "$(LINUX_SRC_PATH)" O=$(LINUX_BUILD_DIR) \
		CROSS_COMPILE=$(CROSS_COMPILE) ARCH=riscv

$(IMAGE_DIR)/Image: $(LINUX_IMAGE)
	mkdir -p -- "$(IMAGE_DIR)"
	cp -f -- "$<" "$@"

#make ARCH=riscv O=$(LINUX_BUILD_DIR) modules_install INSTALL_MOD_PATH=$(LINUX_BUILD_DIR)/rootfs/ CROSS_COMPILE=$(CROSS_COMPILE)

$(FW_PAYLOAD): $(LINUX_IMAGE)
	mkdir -p -- "$(OPENSBI_BUILD_DIR)"
	+$(MAKE) -C "$(OPENSBI_SRC_PATH)" O=$(OPENSBI_BUILD_DIR) \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		PLATFORM=generic FW_PAYLOAD_PATH=$<

$(IMAGE_DIR)/fw_payload.bin: $(FW_PAYLOAD)
	mkdir -p -- "$(IMAGE_DIR)"
	cp -f -- "$<" "$@"

.PHONY: uboot
uboot:
	$(MAKE) -C "$(UBOOT_SRC_PATH)" O=$(UBOOT_BUILD_DIR) \
		ARCH=riscv CROSS_COMPILE="$(CROSS_COMPILE)" \
		$(UBOOT_DEFCONFIG)
	$(MAKE) -C "$(UBOOT_SRC_PATH)" O=$(UBOOT_BUILD_DIR) \
		ARCH=riscv CROSS_COMPILE="$(CROSS_COMPILE)"

$(IMAGE_DIR)/rootfs.ext4:
	mkdir -p -- "$(BUILD_DIR)/images"
	rm -f -- "$@"
	# -d rootfs
	/sbin/mkfs.ext4 -r 1 -N 0 -m 1 -L rootfs "$@" 1M

$(IMAGE_DIR)/sysimage-sdcard.img: Makefile src/sdcard.dump \
		$(IMAGE_DIR)/rootfs.ext4 \
		$(IMAGE_DIR)/Image \
		$(IMAGE_DIR)/fw_payload.bin \
		uboot
	tools/gen_image.sh
	dd bs=1K seek=1024 of=$@.tmp if=$(IMAGE_DIR)/uboot/fn_u-boot-spl.bin
	dd bs=1K seek=1536 of=$@.tmp if=$(IMAGE_DIR)/uboot/fn_u-boot-spl.bin
	dd bs=1K seek=2048 of=$@.tmp if=$(IMAGE_DIR)/uboot/fn_ug_u-boot.bin
	dd bs=1K seek=4096 of=$@.tmp if=$(IMAGE_DIR)/linux_system.bin
	dd bs=1K seek=16384 of=$@.tmp if=$(IMAGE_DIR)/rootfs.ext4
	truncate --size=+1M "$@.tmp" # GPT copy
	/sbin/sfdisk "$@.tmp" < src/sdcard.dump
	mv -- "$@.tmp" "$@"

.PHONY: clean
clean:
	git clean -fxd

help:
	@echo "Usage: "
	@echo "make"
	@echo "Supported compilation options"
	@echo "make                          -- Build all for k230";
	@echo "make prepare_sourcecode       -- down source code";
	@echo "make uboot                    -- Build U-boot";
	@echo "make build-image              -- Build k230 rootfs image";
