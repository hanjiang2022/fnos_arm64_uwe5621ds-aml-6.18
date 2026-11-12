#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
KDIR=${KDIR:-/lib/modules/$(uname -r)/build}
CROSS_COMPILE=${CROSS_COMPILE:-}
TREE_RELEASE=$(make -s -C "$KDIR" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" kernelrelease)
[[ -n $TREE_RELEASE ]] || { echo '无法读取内核版本' >&2; exit 1; }

make -C "$SOURCE_DIR" KDIR="$KDIR" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" -j"$(nproc)"

modules=(
  unisocwcn/uwe5621_bsp_sdio.ko
  unisocwifi/sprdwl_ng.ko
  tty-sdio/sprdbt_tty.ko
)
KERNEL_RELEASE=
for module in "${modules[@]}"; do
  vermagic=$(modinfo -F vermagic "$SOURCE_DIR/$module")
  module_release=${vermagic%% *}
  [[ -n $module_release ]] || { echo "无法读取模块 $module 的 vermagic" >&2; exit 1; }
  if [[ -z $KERNEL_RELEASE ]]; then
    KERNEL_RELEASE=$module_release
  elif [[ $module_release != "$KERNEL_RELEASE" ]]; then
    echo "模块 $module 的 vermagic 与其他模块不一致: $vermagic" >&2
    exit 1
  fi
done

if [[ $TREE_RELEASE != "$KERNEL_RELEASE" ]]; then
  echo "提示: 内核树 kernelrelease=$TREE_RELEASE，模块 vermagic=$KERNEL_RELEASE；按实际模块版本归档。" >&2
fi
RELEASE_DIR="$SOURCE_DIR/releases/$KERNEL_RELEASE/aarch64"
mkdir -p "$RELEASE_DIR"
for module in "${modules[@]}"; do
  install -m 0644 "$SOURCE_DIR/$module" "$RELEASE_DIR/"
done
if [[ -n ${FIRMWARE_DIR:-} ]]; then
  for firmware in wcnmodem.bin wifi_56630001_3ant.ini; do
    [[ -f "$FIRMWARE_DIR/$firmware" ]] || {
      echo "缺少指定的固件 $FIRMWARE_DIR/$firmware" >&2
      exit 1
    }
    install -m 0644 "$FIRMWARE_DIR/$firmware" "$RELEASE_DIR/"
  done
fi
DTB_SOURCE=${DTB_FILE:-$SOURCE_DIR/dtb/meson-sm1-a95xf3-air_spdif_uwe5621ds_gbit.dtb}
[[ -f $DTB_SOURCE ]] || { echo "缺少 DTB $DTB_SOURCE" >&2; exit 1; }
install -m 0644 "$DTB_SOURCE" "$RELEASE_DIR/meson-sm1-a95xf3-air_spdif_uwe5621ds_gbit.dtb"
install -m 0755 "$SOURCE_DIR/install_uwe5621.sh" "$SOURCE_DIR/install_uwe5621_btattach.sh" "$RELEASE_DIR/"
echo "发布目录: $RELEASE_DIR"
for file in wcnmodem.bin wifi_56630001_3ant.ini; do
  if [[ ! -f "$RELEASE_DIR/$file" ]]; then
    echo "提示: $RELEASE_DIR/$file 不存在；完整安装前请提供适配当前硬件的文件。" >&2
  fi
done
