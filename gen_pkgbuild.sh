#!/usr/bin/env bash
root_dir="$(dirname $(realpath ${0}))"

if [[ -d "${root_dir}/src" ]]; then
    rm -rf "${root_dir}/src"
fi

if [[ -d "${root_dir}/out" ]]; then
    rm -rf "${root_dir}/out"
fi

mkdir "${root_dir}/src"
mkdir "${root_dir}/out"

cd "${root_dir}/src"
wget https://github.com/archlinux/svntogit-packages/archive/packages/linux-zen.tar.gz
bsdtar xf linux-zen.tar.gz
pkgver="$(grep '^pkgver=' svntogit-packages-packages-linux-zen/trunk/PKGBUILD | sed 's/pkgver=//')"
srctag="v${pkgver%.*}-${pkgver##*.}"
cp svntogit-packages-packages-linux-zen/trunk/* "${root_dir}/out/"
wget "https://github.com/zen-kernel/zen-kernel/archive/${srctag}.tar.gz"
bsdtar xf "${srctag}.tar.gz"
mv "zen-kernel-${pkgver%.*}-${pkgver##*.}" i
mkdir -p w/drivers/input/serio
cp i/drivers/input/serio/i8042.c w/drivers/input/serio/
sed -i "s/	.resume		= i8042_pm_resume,/	.resume		= i8042_pm_restore,/" w/drivers/input/serio/i8042.c
echo "diff -uprN i/drivers/input/serio/i8042.c w/drivers/input/serio/i8042.c" > "${root_dir}/out/lets-note.patch"
diff -uprN i/drivers/input/serio/i8042.c w/drivers/input/serio/i8042.c >> "${root_dir}/out/lets-note.patch"

cd "${root_dir}/out"
sed -i "s/pkgbase=linux-zen/pkgbase=linux-zen-letsnote/" PKGBUILD
sed -i "s/pkgdesc='Linux ZEN'/pkgdesc='Linux ZEN patched for Lets note'/" PKGBUILD
sed -i 's/_srcname=zen-kernel/_srcname="zen-kernel-${pkgver%.*}-${pkgver##*.}"/' PKGBUILD
sed -i 's@$_srcname::git+https://github.com/zen-kernel/zen-kernel?signed#tag=$_srctag@https://github.com/zen-kernel/zen-kernel/archive/$_srctag.tar.gz@' PKGBUILD
sed -i "$(grep -n "sphinx-workaround.patch$" PKGBUILD | awk -F ':' '{print $1}')a \ \ lets-note.patch" PKGBUILD
start_validpgp_num="$(grep -n "validpgpkeys=" PKGBUILD | awk -F ':' '{print $1}')"

for i in $(grep -n "^)" PKGBUILD | awk -F ':' '{print $1}'); do
    if [[ "${i}" -gt "${start_validpgp_num}" ]]; then
        sed -i "${start_validpgp_num},${i}d" PKGBUILD
        break
    fi
done

last_sha256_num="$(($(grep -n "export KBUILD_BUILD_HOST=archlinux" PKGBUILD | awk -F ':' '{print $1}')-2))"
last_sha256="$(sed -n "${last_sha256_num}p" PKGBUILD)"
sed -i "s/${last_sha256}/${last_sha256/)/ }/" PKGBUILD
sed -i "${last_sha256_num}a \ \ \ \ \ \ \ \ \ \ \ \ '$(sha256sum lets-note.patch | awk '{print $1}')'\n)" PKGBUILD
