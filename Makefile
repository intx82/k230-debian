CROSS_COMPILE ?= riscv64-linux-gnu-
BOARD ?= k230_canmv
BUILD_DIR ?= output

CONFIG_DBGLV ?=0
export KCFLAGS=-DDBGLV=$(CONFIG_DBGLV)

all: sysimage-sdcard.img

u-boot: FORCE
	+$(MAKE) -C src/u-boot O=../../$(BUILD_DIR)/u-boot \
		ARCH=riscv CROSS_COMPILE="$(CROSS_COMPILE)" \
		$(BOARD)_defconfig
	+$(MAKE) -C src/u-boot O=../../$(BUILD_DIR)/u-boot \
		ARCH=riscv CROSS_COMPILE="$(CROSS_COMPILE)"

opensbi: linux
	mkdir -p -- "$(BUILD_DIR)/opensbi"
	+$(MAKE) -C src/opensbi O="$(shell pwd)/$(BUILD_DIR)/opensbi" \
		CROSS_COMPILE=$(CROSS_COMPILE) \
		PLATFORM=generic \
		FW_PAYLOAD_PATH="$(shell pwd)/$(BUILD_DIR)/linux/arch/riscv/boot/Image"

linux: FORCE
	+$(MAKE) -C src/linux O=../../$(BUILD_DIR)/linux \
		CROSS_COMPILE=$(CROSS_COMPILE) ARCH=riscv \
		$(BOARD)_defconfig
	+$(MAKE) -C src/linux O=../../$(BUILD_DIR)/linux \
		CROSS_COMPILE=$(CROSS_COMPILE) ARCH=riscv

#make ARCH=riscv O=$(LINUX_BUILD_DIR) modules_install INSTALL_MOD_PATH=$(LINUX_BUILD_DIR)/rootfs/ CROSS_COMPILE=$(CROSS_COMPILE)

.PHONY: FORCE

FW_PAYLOAD = $(BUILD_DIR)/opensbi/platform/generic/firmware/fw_payload.bin
DTB = $(BUILD_DIR)/$(BOARD).dtb
INITRD = $(BUILD_DIR)/initrd.img
ROOTFS = $(BUILD_DIR)/rootfs.ext4

$(BUILD_DIR)/u-boot/spl/u-boot-spl.bin: u-boot
$(BUILD_DIR)/u-boot/u-boot.bin: u-boot
$(FW_PAYLOAD): opensbi

$(BUILD_DIR)/u-boot-spl.bin: $(BUILD_DIR)/u-boot/spl/u-boot-spl.bin
	cp -f -- "$<" "$@"

$(BUILD_DIR)/u-boot.bin: $(BUILD_DIR)/u-boot/u-boot.bin
	cp -f -- "$<" "$@"

%.gz: %
	gzip -fkn9 "$<"

$(BUILD_DIR)/$(BOARD).dts.txt: linux
	mkdir -p -- "$(BUILD_DIR)"
	$(CPP) -nostdinc -I src/linux/include -I src/linux/arch \
		-undef -x assembler-with-cpp \
		src/linux/arch/riscv/boot/dts/kendryte/$(BOARD).dts \
		-o $@

%.dtb: %.dts.txt linux
	$(BUILD_DIR)/linux/scripts/dtc/dtc -I dts -q -O dtb "$<" -o "$@"

$(INITRD): Makefile
	mkdir -p -- "$(BUILD_DIR)"
	truncate --size=1 $@

$(BUILD_DIR)/ug_u-boot.bin: $(BUILD_DIR)/u-boot/u-boot.bin.gz
	$(BUILD_DIR)/u-boot/tools/mkimage -A riscv -C gzip \
		-O u-boot -T firmware  -a 0 -e 0 -n uboot \
		-d "$<" $@

$(BUILD_DIR)/ulinux.bin: u-boot $(FW_PAYLOAD).gz $(INITRD) $(DTB)
	$(BUILD_DIR)/u-boot/tools/mkimage -A riscv -O linux -T multi -C gzip \
		-a 0 -e 0 -n linux \
		-d $(FW_PAYLOAD).gz:$(INITRD):$(DTB) $@

$(ROOTFS): Makefile
	mkdir -p -- "$(BUILD_DIR)"
	rm -f -- "$@"
	# -d rootfs
	/sbin/mkfs.ext4 -r 1 -N 0 -m 1 -L rootfs "$@" 1M

$(BUILD_DIR)/fn_%: $(BUILD_DIR)/%
	./make-k230-firmware -i "$<" -o "$@"

sysimage-sdcard.img: \
		$(BUILD_DIR)/fn_u-boot-spl.bin \
		$(BUILD_DIR)/fn_ug_u-boot.bin \
		$(BUILD_DIR)/fn_ulinux.bin $(BUILD_DIR)/rootfs.ext4
	dd bs=1K seek=1024 of=$@.tmp if=$(BUILD_DIR)/fn_u-boot-spl.bin
	dd bs=1K seek=1536 of=$@.tmp if=$(BUILD_DIR)/fn_u-boot-spl.bin
	dd bs=1K seek=2048 of=$@.tmp if=$(BUILD_DIR)/fn_ug_u-boot.bin
	dd bs=1K seek=4096 of=$@.tmp if=$(BUILD_DIR)/fn_ulinux.bin
	dd bs=1K seek=16384 of=$@.tmp if=$(BUILD_DIR)/rootfs.ext4
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
