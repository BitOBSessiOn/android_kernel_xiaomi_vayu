#!/bin/bash

# Variables
export DEVICE=vayu
export DEFCONFIG=vayu_user_defconfig
export BUILD_DTBO=true
export OUT_PATH=out

export CLANG_PATH=/android/dev/tc/proton-clang
export PATH="/android/bin:$CLANG_PATH/bin:$PATH"

if ! [ -d "$CLANG_PATH" ]; then
	echo "Proton clang not found! Cloning..."
	if ! git clone -q --depth=1 --single-branch https://github.com/kdrag0n/proton-clang $CLANG_PATH; then
		echo "Cloning failed! Aborting..."
		exit 1
	fi
fi

mkdir -p $OUT_PATH
make O=$OUT_PATH ARCH=arm64 $DEFCONFIG

#
# Kernel building
#
if [[ $1 == "-r" || $1 == "--regen" ]]; then
	cp $OUT_PATH/.config arch/arm64/configs/$DEFCONFIG
	echo -e "\nRegened defconfig succesfully!"
	exit 0
else
	echo -e "\nStarting compilation...\n"
	echo -e "Building kernel..."
	make -j$(nproc --all) O=$OUT_PATH ARCH=arm64 CC=clang AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- Image.gz-dtb
	if $BUILD_DTBO; then
		echo -e "Building dtbo..."
		make -j$(nproc --all) O=$OUT_PATH ARCH=arm64 CC=clang AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=aarch64-linux-gnu- CROSS_COMPILE_ARM32=arm-linux-gnueabi- dtbo.img
	fi
fi

#
# Kernel packaging
#

# AnyKernel
export ANYKERNEL_URL=https://github.com/BitOBSessiOn/AnyKernel3
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
			echo -e "dtbo not needed."
		else
			echo -e "dtbo not found! Error!"
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

