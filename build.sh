#!/bin/bash
#
# Compile script for Gilver kernel
# Copyright (C) 2020-2021 Adithya R.
# Copyright (C) 2021-2025 Richard
# Copyright (C) 2025 Vergilantte

SECONDS=0 # builtin bash timer
ZIPNAME="Gilver-surya-$(date '+%Y%m%d-%H%M').zip"
TC_DIR="$(pwd)/tc/clang-20"
AK3_DIR="$(pwd)/android/AnyKernel3"
DEFCONFIG="surya_defconfig"

if test -z "$(git rev-parse --show-cdup 2>/dev/null)" &&
   head=$(git rev-parse --verify HEAD 2>/dev/null); then
	ZIPNAME="${ZIPNAME::-4}-$(echo $head | cut -c1-8).zip"
fi

export PATH="$TC_DIR/bin:$PATH"

sync_repo() {
    local dir=$1
    local repo_url=$2
    local branch=$3
	local update=$4

    if [ -d "$dir" ]; then
        if $update; then
			# Fetch the latest changes
            git -C "$dir" fetch origin --quiet

            # Compare local and remote commits
            LOCAL_COMMIT=$(git -C "$dir" rev-parse HEAD)
            REMOTE_COMMIT=$(git -C "$dir" rev-parse "origin/$branch")

            # If there are changes, reset and log the update
            if [ "$LOCAL_COMMIT" != "$REMOTE_COMMIT" ]; then
                git -C "$dir" reset --quiet --hard "origin/$branch"
                LATEST_COMMIT=$(git -C "$dir" log -1 --oneline)
                echo -e "Updated $repo_url to: $LATEST_COMMIT\n" | tee -a "$dir/updates.txt"
            else
                echo "No changes found for $repo_url. Skipping update."
            fi
        fi
    else
        # Clone the repository if it doesn't exist
        echo "Cloning $repo_url to $dir..."
        if ! git clone --quiet --depth=1 -b "$branch" "$repo_url" "$dir"; then
            echo "Cloning failed! Aborting..."
            exit 1
        fi
    fi
}

if [[ $1 = "-u" || $1 = "--update" ]]; then
    sync_repo $AK3_DIR "https://github.com/xvergilantte/AnyKernel3.git" "Gilver" true
    sync_repo $TC_DIR "https://bitbucket.org/xvergil/clang-standalone.git" "20" true
	exit
else
    sync_repo $AK3_DIR "https://github.com/xvergilantte/AnyKernel3.git" "Gilver" false
    sync_repo $TC_DIR "https://bitbucket.org/xvergil/clang-standalone.git" "20" false
fi

if [ ! -d "$AK3_DIR" ] || [ ! -d "$TC_DIR" ]; then
    echo "Error: Required directories are missing. Aborting the build process."
    exit 1
fi

if [[ $1 = "-r" || $1 = "--regen" ]]; then
	make $DEFCONFIG savedefconfig
	cp out/defconfig arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated defconfig at $DEFCONFIG"
	exit
fi

if [[ $1 = "-rf" || $1 = "--regen-full" ]]; then
	make $DEFCONFIG
	cp out/.config arch/arm64/configs/$DEFCONFIG
	echo -e "\nSuccessfully regenerated full defconfig at $DEFCONFIG"
	exit
fi

CLEAN_BUILD=false
ENABLE_KSU=false
ENABLE_KSUSUSFS=false

for arg in "$@"; do
	case $arg in
		-c|--clean)
			CLEAN_BUILD=true
			;;
		-s|--su)
			ENABLE_KSU=true
			ZIPNAME="${ZIPNAME/Gilver-surya/Gilver-KSU}"
			;;
		-ss|--susus)
			ENABLE_KSUSUSFS=true
			ZIPNAME="${ZIPNAME/Gilver-surya/Gilver-KSUSUSFS}"
			;;
		*)
			echo "Unknown argument: $arg"
			exit 1
			;;
	esac
done

if $CLEAN_BUILD; then
	echo "Cleaning output directory..."
	rm -rf out
fi

if $ENABLE_KSU; then
	echo "Building with KSU support"
	KSU_DEFCONFIG="ksu_${DEFCONFIG}"
	KSU_DEFCONFIG_PATH="arch/arm64/configs/${KSU_DEFCONFIG}"
	cp arch/arm64/configs/$DEFCONFIG $KSU_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU=n/CONFIG_KSU=y/g' $KSU_DEFCONFIG_PATH
	trap '[[ -f $KSU_DEFCONFIG_PATH ]] && rm -f $KSU_DEFCONFIG_PATH' EXIT
fi

if $ENABLE_KSUSUSFS; then
	echo "Building with KSU and SuSFS support..."
	KSUSUSFS_DEFCONFIG="ksususfs_${DEFCONFIG}"
	KSUSUSFS_DEFCONFIG_PATH="arch/arm64/configs/${KSUSUSFS_DEFCONFIG}"
	cp arch/arm64/configs/$DEFCONFIG $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU=n/CONFIG_KSU=y/g' $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU_SUSFS=n/CONFIG_KSU_SUSFS=y/g' $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=n/CONFIG_KSU_SUSFS_HAS_MAGIC_MOUNT=y/g' $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU_SUSFS_SUS_PATH=n/CONFIG_KSU_SUSFS_SUS_PATH=y/g' $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU_SUSFS_SUS_MOUNT=n/CONFIG_KSU_SUSFS_SUS_MOUNT=y/g' $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=n/CONFIG_KSU_SUSFS_AUTO_ADD_SUS_KSU_DEFAULT_MOUNT=y/g' $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=n/CONFIG_KSU_SUSFS_AUTO_ADD_SUS_BIND_MOUNT=y/g' $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU_SUSFS_SUS_KSTAT=n/CONFIG_KSU_SUSFS_SUS_KSTAT=y/g' $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU_SUSFS_TRY_UMOUNT=n/CONFIG_KSU_SUSFS_TRY_UMOUNT=y/g' $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=n/CONFIG_KSU_SUSFS_AUTO_ADD_TRY_UMOUNT_FOR_BIND_MOUNT=y/g' $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU_SUSFS_SPOOF_UNAME=n/CONFIG_KSU_SUSFS_SPOOF_UNAME=y/g' $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU_SUSFS_ENABLE_LOG=n/CONFIG_KSU_SUSFS_ENABLE_LOG=y/g' $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=n/CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS=y/g' $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=n/CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG=y/g' $KSUSUSFS_DEFCONFIG_PATH
	sed -i 's/CONFIG_KSU_SUSFS_OPEN_REDIRECT=n/CONFIG_KSU_SUSFS_OPEN_REDIRECT=y/g' $KSUSUSFS_DEFCONFIG_PATH
	trap '[[ -f $KSUSUSFS_DEFCONFIG_PATH ]] && rm -f $KSUSUSFS_DEFCONFIG_PATH' EXIT
fi

echo -e "\nStarting compilation...\n"
if $ENABLE_KSU; then
		make $KSU_DEFCONFIG
elif
   $ENABLE_KSUSUSFS; then
		make $KSUSUSFS_DEFCONFIG
else
		make $DEFCONFIG
fi
make -j$(nproc --all) LLVM=1 Image.gz dtb.img dtbo.img 2> >(tee log.txt >&2) || exit $?

kernel="out/arch/arm64/boot/Image.gz"
dtb="out/arch/arm64/boot/dtb.img"
dtbo="out/arch/arm64/boot/dtbo.img"

if [ -f "$kernel" ] && [ -f "$dtb" ] && [ -f "$dtbo" ]; then
	echo -e "\nKernel compiled successfully! Zipping up...\n"
	cp -r $AK3_DIR AnyKernel3
	cp $kernel $dtb $dtbo AnyKernel3
	cd AnyKernel3
	git checkout Gilver &> /dev/null
	zip -r9 "../$ZIPNAME" * -x .git modules\* patch\* ramdisk\* README.md *placeholder
	cd ..
	rm -rf AnyKernel3
	rm -rf out
	echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
	echo "Zip: $ZIPNAME"
else
	echo -e "\nCompilation failed!"
	exit 1
fi