#!/usr/bin/env bash
set -euo pipefail

SOURCE_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
KDIR=${KDIR:-/lib/modules/$(uname -r)/build}
CROSS_COMPILE=${CROSS_COMPILE:-}
KERNEL_RELEASE=$(make -s -C "$KDIR" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" kernelrelease)
[[ -n $KERNEL_RELEASE ]] || { echo '无法读取内核版本' >&2; exit 1; }

RELEASE_DIR="$SOURCE_DIR/releases/$KERNEL_RELEASE/aarch64"
make -C "$SOURCE_DIR" KDIR="$KDIR" ARCH=arm64 CROSS_COMPILE="$CROSS_COMPILE" -j"$(nproc)"

modules=(
  unisocwcn/uwe5621_bsp_sdio.ko
  unisocwifi/sprdwl_ng.ko
  tty-sdio/sprdbt_tty.ko
)
for module in "${modules[@]}"; do
  vermagic=$(modinfo -F vermagic "$SOURCE_DIR/$module")
  [[ ${vermagic%% *} == "$KERNEL_RELEASE" ]] || {
    echo "模块 $module 的 vermagic 不匹配: $vermagic" >&2
    exit 1
  }
done

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
if [[ -n ${DTB_FILE:-} ]]; then
  [[ -f $DTB_FILE ]] || { echo "缺少指定的 DTB $DTB_FILE" >&2; exit 1; }
  install -m 0644 "$DTB_FILE" "$RELEASE_DIR/meson-sm1-a95xf3-air_spdif_uwe5621ds_gbit.dtb"
fi
install -m 0755 "$SOURCE_DIR/install_uwe5621.sh" "$SOURCE_DIR/install_uwe5621_btattach.sh" "$RELEASE_DIR/"
echo "发布目录: $RELEASE_DIR"
for file in wcnmodem.bin wifi_56630001_3ant.ini meson-sm1-a95xf3-air_spdif_uwe5621ds_gbit.dtb; do
  if [[ ! -f "$RELEASE_DIR/$file" ]]; then
    echo "提示: $RELEASE_DIR/$file 不存在；完整安装前请提供适配当前硬件的文件。" >&2
  fi
done
