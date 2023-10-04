#!/bin/bash

set -e #exit on error
# set -x #echo on

cmd=$1


dts=$(realpath srcs/dts/)
tcl_src=$(realpath srcs/tcl/)
res=$(realpath res/)

# requires absolute path
dtb="$PWD/build/dtb/"
tcl="$PWD/build/tcl/"
qemu_images="$PWD/build/qemuriscv64/"

source setenv


usage () {
  echo "usage: $0 <cmd>"
  echo -e "\t help \t... this msg"
  echo -e "\t dts \t... compile device tree files"
  echo -e "\t qemu \t... start qemu session"
  echo -e "\t eth \t... configure eth on vcu118"
  echo -e "\t linux \t... boot linux on vcu118"
  echo -e "\t info \t... get selene hw info"
  echo -e "\t rv_sc \t... test rootvoter baremetal single core"
  echo -e "\t rv_mc \t... test rootvoter baremetal multi core"
}


if [[ "$1" == "-h" || ("$1" == "--help")]]
then
  usage
  exit 0
fi


function compile_dts() {
    mkdir -p $dtb

	cat $dts/noel-template.dts | sed 's/NFSMOUNT/selene_isar_ros2/' | sed '/MEMORY_1GB/d' > $dts/noel-uc-ros2-1GB.dts
	cat $dts/noel-template.dts | sed 's/NFSMOUNT/selene_isar_ros2/' | sed '/MEMORY_1GB/d' | sed '/MULTICORE/d' > $dts/noel-mc-ros2-1GB.dts
	cat $dts/noel-template.dts | sed 's/NFSMOUNT/selene_isar_ros2/' | sed '/MEMORY_2GB/d' > $dts/noel-uc-ros2-2GB.dts
	cat $dts/noel-template.dts | sed 's/NFSMOUNT/selene_isar_ros2/' | sed '/MEMORY_2GB/d' | sed '/MULTICORE/d' > $dts/noel-mc-ros2-2GB.dts
	cat $dts/noel-template.dts | sed 's/NFSMOUNT/selene_isar/' | sed '/MEMORY_1GB/d' > $dts/noel-uc-isar-1GB.dts
	cat $dts/noel-template.dts | sed 's/NFSMOUNT/selene_isar/' | sed '/MEMORY_1GB/d' | sed '/MULTICORE/d' > $dts/noel-mc-isar-1GB.dts
	cat $dts/noel-template.dts | sed 's/NFSMOUNT/selene_isar/' | sed '/MEMORY_2GB/d' > $dts/noel-uc-isar-2GB.dts
	cat $dts/noel-template.dts | sed 's/NFSMOUNT/selene_isar/' | sed '/MEMORY_2GB/d' | sed '/MULTICORE/d' > $dts/noel-mc-isar-2GB.dts
	cat $dts/noel-template.dts | sed 's/NFSMOUNT/selene_isar_rootvoter/' | sed '/MEMORY_1GB/d' > $dts/noel-uc-rootvoter-1GB.dts
	cat $dts/noel-template.dts | sed 's/NFSMOUNT/selene_isar_rootvoter/' | sed '/MEMORY_1GB/d' | sed '/MULTICORE/d' > $dts/noel-mc-rootvoter-1GB.dts
	cat $dts/noel-template.dts | sed 's/NFSMOUNT/selene_sdk_buildroot_20220207/' | sed '/MEMORY_2GB/d' | sed '/MULTICORE/d' > $dts/noel-mc-buildroot-2GB.dts
	for i in $dts/*; do
		dtc -I dts -O dtb -o $dtb/$(basename -s .dts $i).dtb  $i
	done
}

function start_qemu() {
    $QEMU \
        -m 1G -M virt -cpu rv64 \
        -netdev user,id=vnet,hostfwd=:127.0.0.1:0-:22 -device virtio-net-pci,netdev=vnet \
        -drive file=$qemu_images/isar-image-${ISAR_IMAGE}-debian-sid-ports-qemuriscv64.ext4.img,if=none,format=raw,id=hd0 \
        -device virtio-blk-device,drive=hd0 \
        -device loader,file=$qemu_images/fw_jump.elf,addr=0x80200000 \
        -kernel $qemu_images/isar-image-${ISAR_IMAGE}-debian-sid-ports-qemuriscv64-vmlinux \
        -initrd $qemu_images/isar-image-${ISAR_IMAGE}-debian-sid-ports-qemuriscv64-initrd.img \
        -append "console=ttyS0 root=/dev/vda rw" -nographic -snapshot
}

function program_hw() {

    source $VIVADO_ENV

    # use sed --expression and double quotes, and @ as a seperator,
    # otherwise the expansion of a path includes too many slashes
    local bitfiledir=$SELENE_HW_REPO/selene-soc/selene-xilinx-vcu118/bitfiles/gpl
    cat $tcl_src/program_hw_template.tcl | sed -e "s@BITFILE_DIR@${bitfiledir}@" > $tcl/program_hw.tcl
    vivado_lab -mode batch -source $tcl/program_hw.tcl

}

function eth_config() {
    local timestamp=`date +"%Y-%m-%dT%H:%M:%S"`
    grmon -u -uart ${SELENE_USB} -c $SELENE_HW_REPO/selene-soc/selene-xilinx-vcu118/eth_config.tcl -log grmon.log
    mv grmon.log $PWD/logs/${timestamp}_eth_config.log
    }

function eth_session() {

    # make sure your network is correctly configured
    # $ sudo nmcli connection up selene_static_usb
    local timestamp=`date +"%Y-%m-%dT%H:%M:%S"`
    grmon -u 2 -eth 192.168.0.51 -log grmon.log
    mv grmon.log $PWD/logs/${timestamp}_eth_session.log
}

function boot_linux() {
    local timestamp=`date +"%Y-%m-%dT%H:%M:%S"`
    local dtbfile=$dtb/noel-uc-ros2-1GB.dtb
    local fw_payload=$FW_PAYLOAD_ELF
	cat $tcl_src/boot_linux_template.tcl | sed -e "s@DTB@${dtbfile}@" | sed -e "s@ELF@${fw_payload}@" > $tcl/boot_linux.tcl
    grmon -u 2 -eth 192.168.0.51 -c $tcl/boot_linux.tcl -log grmon.log

    # some more logging
    echo "" >> grmon.log
    echo $dtbfile >> grmon.log
    echo $fw_payload >> grmon.log
    mv grmon.log $PWD/logs/${timestamp}_eth_session.log
}

function info_selene() {
    local timestamp=`date +"%Y-%m-%dT%H:%M:%S"`
    local selene_info_dir=$SELENE_HW_REPO/selene-soc/selene-xilinx-vcu118/
    cat $tcl_src/info_selene.tcl | sed -e "s@SELENE_INFO_DIR@${selene_info_dir}@" > $tcl/info_selene.tcl
    grmon -u -uart ${SELENE_USB} -c $tcl/info_selene.tcl -log grmon.log
    mv grmon.log $PWD/logs/${timestamp}_info_selene.log
}

function prepare_rootvoter_baremetal() {
    local timestamp=`date +"%Y-%m-%dT%H:%M:%S"`
    local rv_dir=$SELENE_HW_REPO/safety/rootvoter_v2/sw
    local rootvoter_obj_sc=$rv_dir/obj_singlecore.out
    local rootvoter_obj_mc=$rv_dir/obj_multicore.out
    cat $tcl_src/rootvoter_baremetal.tcl | sed -e "s@ROOTVOTER_OBJ@${rootvoter_obj_sc}@" > $tcl/rootvoter_baremetal_sc.tcl
    cat $tcl_src/rootvoter_baremetal.tcl | sed -e "s@ROOTVOTER_OBJ@${rootvoter_obj_mc}@" > $tcl/rootvoter_baremetal_mc.tcl
}

function rv_singlecore() {
    grmon -u -eth 192.168.0.51 -c $tcl/rootvoter_baremetal_sc.tcl -log grmon.log
    mv grmon.log $PWD/logs/${timestamp}_rv_baremetal_sc.log
}

function rv_multicore() {
    grmon -u -eth 192.168.0.51 -c $tcl/rootvoter_baremetal_mc.tcl -log grmon.log
    mv grmon.log $PWD/logs/${timestamp}_rv_baremetal_mc.log
}

# do sub function
if [[ $cmd == "dts" ]]; then
	compile_dts
elif [[ $cmd == "qemu" ]]; then
	start_qemu
elif [[ $cmd == "program_hw" ]]; then
    program_hw
elif [[ $cmd == "eth_config" ]]; then
    eth_config
elif [[ $cmd == "eth" ]]; then
    eth_session
elif [[ $cmd == "linux" ]]; then
	boot_linux
elif [[ $cmd == "info" ]]; then
	info_selene
elif [[ $cmd == "rv_sc" ]]; then
    prepare_rootvoter_baremetal
    rv_singlecore
elif [[ $cmd == "rv_mc" ]]; then
    prepare_rootvoter_baremetal
    rv_multicore
else
	echo "Unknown target: $cmd"
    usage
fi
