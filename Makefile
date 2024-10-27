UBOOT_VERSION := 2023.01
RKBIN_HASH := a2a0b89b6c8c612dca5ed9ed8a68db8a07f68bc0
TOOLCHAIN := arm-gnu-toolchain-13.3.rel1-x86_64-aarch64-none-elf
MAKE := make ARCH=arm CROSS_COMPILE=$(PWD)/$(TOOLCHAIN)/bin/aarch64-none-elf-


images: uboot patch
	cp u-boot-${UBOOT_VERSION}/u-boot-dtb.bin rkbin-${RKBIN_HASH}/ && \
	pushd rkbin-${RKBIN_HASH} && \
	tools/mkimage -n rk3399 -T rksd -d bin/rk33/rk3399_ddr_800MHz_v1.30.bin idbloader.img && \
	cat bin/rk33/rk3399_miniloader_v1.30.bin >> idbloader.img && \
	tools/loaderimage --pack --uboot u-boot-dtb.bin uboot.img 0x00200000 && \
	tools/trust_merger RKTRUST/RK3399TRUST.ini && \
	popd
	if [ ! -d bin ]; then \
		mkdir bin; \
	fi
	cp rkbin-${RKBIN_HASH}/idbloader.img rkbin-${RKBIN_HASH}/uboot.img rkbin-${RKBIN_HASH}/trust.img ./bin

download: toolchain u-boot-src rkbin

toolchain:
	if [ ! -f ${TOOLCHAIN}.tar.xz ]; then \
		curl -L -O https://developer.arm.com/-/media/Files/downloads/gnu/13.3.rel1/binrel/${TOOLCHAIN}.tar.xz; \
	fi
	if [ ! -d ${TOOLCHAIN} ]; then \
		bsdtar -xf ${TOOLCHAIN}.tar.xz; \
	fi

u-boot-src:
	if [ ! -f u-boot-${UBOOT_VERSION}.tar.bz2 ]; then \
		curl -L -O https://ftp.denx.de/pub/u-boot/u-boot-${UBOOT_VERSION}.tar.bz2; \
	fi
	if [ ! -d u-boot-${UBOOT_VERSION} ]; then \
		bsdtar -xf u-boot-${UBOOT_VERSION}.tar.bz2; \
	fi

rkbin:
	if [ ! -f ${RKBIN_HASH}.zip ]; then \
		curl -L -O https://github.com/rockchip-linux/rkbin/archive/${RKBIN_HASH}.zip; \
	fi
	if [ ! -d rkbin-${RKBIN_HASH} ]; then \
		unzip ${RKBIN_HASH}.zip; \
	fi

patch: download
	pushd u-boot-${UBOOT_VERSION} && \
	patch -Np1 -i "../patch/0001-uboot-clockworkpi-a06.patch" && \
	patch -Np1 -i "../patch/0002-mmc-sdhci-allow-disabling-sdma-in-spl.patch" && \
	popd
	pushd rkbin-${RKBIN_HASH} && \
	patch -Np1 -i "../patch/0003-RKTRUST.patch" && \
	popd

uboot: patch
	cp -v rkbin-${RKBIN_HASH}/bin/rk33/rk3399_bl31_v1.36.elf u-boot-${UBOOT_VERSION}/bl31.elf && \
	cp update_config u-boot-${UBOOT_VERSION} && \
	pushd u-boot-${UBOOT_VERSION} && \
	$(MAKE) clockworkpi-a06-rk3399_defconfig && \
	./update_config 'CONFIG_IDENT_STRING' '" Arch Linux"' && \
	./update_config 'CONFIG_OF_LIBFDT_OVERLAY' 'y' && \
	./update_config 'CONFIG_SPL_MMC_SDHCI_SDMA' 'n' && \
	./update_config 'CONFIG_MMC_HS400_SUPPORT' 'y' && \
	./update_config 'CONFIG_SYS_LOAD_ADDR' '0x800800' && \
	./update_config 'CONFIG_TEXT_BASE' '0x00200000' && \
	./update_config 'CONFIG_SPL_HAS_BSS_LINKER_SECTION' 'y' && \
	./update_config 'CONFIG_SPL_BSS_START_ADDR' '0x400000' && \
	./update_config 'CONFIG_SPL_BSS_MAX_SIZE' '0x2000' && \
	./update_config 'CONFIG_HAS_CUSTOM_SYS_INIT_SP_ADDR' 'y' && \
	./update_config 'CONFIG_CUSTOM_SYS_INIT_SP_ADDR' '0x300000' && \
	$(MAKE) EXTRAVERSION=-$(date -R | cut -c18-25) u-boot-dtb.bin && \
	popd

clean:
	rm -r u-boot-* rkbin-* arm-gnu-toolchain-* *.tar.bz2 *.zip *.tar.xz || exit 0