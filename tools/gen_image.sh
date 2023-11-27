#!/bin/bash
set -e;

#add_firmHead  xxx.bin  "-n"
#output fn_$1 fa_$1 fs_$1
add_firmHead()
{
	local filename="$1"
	local firmware_gen="${K230_SDK_ROOT}/tools/firmware_gen.py"
	cp ${filename} ${filename}.t
	python3  ${firmware_gen}   -i ${filename}.t \
		-o fn_${filename} -n
	rm -rf  ${filename}.t
}

# "-O linux -T firmware  -a ${add} -e ${add} -n ${name}"
# "-n/-a/-s"
#output fn_ug_xx fa_ug_xx fs_ug_xx;
bin_gzip_ubootHead_firmHead()
{
	local mkimage="${UBOOT_BUILD_DIR}/tools/mkimage"
	local file_full_path="$1"
	local filename=$(basename ${file_full_path})
	local mkimgArgs="$2"
	local firmArgs="$3"

	#[ -f ${file_full_path} ] || (echo ${filename} >${file_full_path} )
	# cd  "${BUILD_DIR}/images/";
	[ "$(dirname ${file_full_path})" == "$(pwd)" ] || cp ${file_full_path} .

	gzip -fkn9 ${filename}

	#add uboot head
	${mkimage} -A riscv -C gzip  ${mkimgArgs} -d ${filename}.gz  ug_${filename} # ${filename}.gzu

	add_firmHead ug_${filename}
	rm -rf ${filename}  ${filename}.gz ug_${filename}
}

gen_uboot_bin()
{
	mkdir -p "${BUILD_DIR}/images/uboot"
	cd ${BUILD_DIR}/images/uboot;
	# "-O linux -T firmware  -a ${add} -e ${add} -n ${name}"
	# "-n/-a/-s"  "-n/-a/-s"
	#fn_ug_xxx
	bin_gzip_ubootHead_firmHead  ${BUILD_DIR}/u-boot/u-boot.bin   \
					"-O u-boot -T firmware  -a 0 -e 0 -n uboot"


	cp ${BUILD_DIR}/u-boot/spl/u-boot-spl.bin  .
	add_firmHead  u-boot-spl.bin #
	rm -rf u-boot-spl.bin
}


#生成可用uboot引导的linux版本文件
gen_linux_bin ()
{
	local BOARD_NAME="k230_canmv"
	local mkimage="${UBOOT_BUILD_DIR}/tools/mkimage"
	local LINUX_SRC_PATH="src/linux"
	local LINUX_DTS_PATH="${LINUX_SRC_PATH}/arch/riscv/boot/dts/kendryte/${BOARD_NAME}.dts"

	cd  "${BUILD_DIR}/images/"
	mkdir -p hw/
	cpp -nostdinc -I ${K230_SDK_ROOT}/${LINUX_SRC_PATH}/include -I ${K230_SDK_ROOT}/${LINUX_SRC_PATH}/arch  -undef -x assembler-with-cpp ${K230_SDK_ROOT}/${LINUX_DTS_PATH}  hw/k230.dts.txt


	${LINUX_BUILD_DIR}/scripts/dtc/dtc -I dts -q -O dtb hw/k230.dts.txt  >k230.dtb
	gzip -fkn9 fw_payload.bin
	echo a>rd;
	${mkimage} -A riscv -O linux -T multi -C gzip -a 0 -e 0 -n linux -d fw_payload.bin.gz:rd:k230.dtb  ulinux.bin;

	add_firmHead  ulinux.bin
	mv fn_ulinux.bin  linux_system.bin
	rm -rf rd;
}

gen_linux_bin
gen_uboot_bin
