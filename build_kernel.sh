#!/bin/bash

# Variables
export ARCH=arm64
export SUBARCH=arm64
export DTC_EXT=dtc
export DEVICE=vayu
export DEVICE_CONFIG=vayu_bito_defconfig

# Mandatory for vayu, but custom build seems to break something...
export BUILD_DTBO=false

# Do we build final zip ?
export BUILD_ZIP=true

# TC:
# git clone https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9 toolchain
export TC_PATH=$PWD/../toolchain

# Google CLANG  9.x :
# https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/android-9.0.0_r48/clang-4691093.tar.gz
#export CLANG_PATH=$PWD/../clang

# Dragon CLANG 13.x :
# git clone -q --depth=1 --single-branch https://github.com/kdrag0n/proton-clang $CLANG_PATH
export CLANG_PATH=/android/dev/tc/proton-clang

export OUT_PATH=$PWD/out

#
# Kernel building
#

# Update PATH (dtc,clang,tc)
# DTC needed (https://forum.xda-developers.com/attachments/device-tree-compiler-zip.4829019/)
# More info:  https://forum.xda-developers.com/t/guide-how-to-compile-kernel-dtbo-for-redmi-k20.3973787/
PATH="/android/bin:$CLANG_PATH/bin:$TC_PATH/bin:$PATH"

mkdir -p $OUT_PATH

make O=$OUT_PATH ARCH=arm64 $DEVICE_CONFIG

# Build kernel
make -j$(nproc --all) O=$OUT_PATH ARCH=arm64 \
	CC=clang \
	CLANG_TRIPLE=aarch64-linux-gnu- \
	CROSS_COMPILE=aarch64-linux-android- \
	Image.gz-dtb

# Building DTBO
# https://android.googlesource.com/platform/system/libufdt/+archive/master/utils.tar.gz
if $BUILD_DTBO; then
	echo -e "Building DTBO..."
	MKDTBOIMG_PATH=/android/bin/

# DEPRECATED:
#	if ! mkdtimg create /$OUT_PATH/arch/arm64/boot/dtbo.img --page_size=4096 $OUT_PATH/arch/arm64/boot/dts/qcom/*.dtbo; then
	if ! python $MKDTBOIMG_PATH/mkdtboimg.py create /$OUT_PATH/arch/arm64/boot/dtbo.img --page_size=4096 $OUT_PATH/arch/arm64/boot/dts/qcom/*.dtbo; then
		echo -e "Error creating DTBO"
		exit 1
	else
		echo -e "DTBO created successfully"
	fi
fi

#
# Kernel packaging
#

# AnyKernel
if $BUILD_ZIP; then

export ANYKERNEL_URL=https://github.com/BitOBSessiON/AnyKernel3
export ANYKERNEL_PATH=$OUT_PATH/AnyKernel3
export ANYKERNEL_BRANCH=vayu
export ZIPNAME="BitO-$DEVICE-$(date '+%Y%m%d-%H%M').zip"

if [ -f "$OUT_PATH/arch/arm64/boot/Image.gz-dtb" ]; then
	echo -e "Packaging...\n"
	git clone -q $ANYKERNEL_URL $ANYKERNEL_PATH -b $ANYKERNEL_BRANCH
	cp $OUT_PATH/arch/arm64/boot/Image.gz-dtb $ANYKERNEL_PATH
	if $BUILD_DTBO && [ -f "$OUT_PATH/arch/arm64/boot/dtbo.img" ]; then
		cp $OUT_PATH/arch/arm64/boot/dtbo.img $ANYKERNEL_PATH
	else
		if ! $BUILD_DTBO; then
			echo -e "DTBO not needed."
		else
			echo -e "DTBO not found! Error!"
			exit 1
		fi
	fi
	rm -f *zip
	cd $ANYKERNEL_PATH
	zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
	cd ..
	echo -e "Cleaning anykernel structure..."
	rm -rf $ANYKERNEL_PATH

	echo "Kernel packaged: $ZIPNAME"

	echo -e "Cleaning build directory..."
	rm -rf $OUT_PATH/arch/arm64/boot
else
	echo -e "Error packaging kernel."
fi

fi

