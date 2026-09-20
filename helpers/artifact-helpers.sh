#!/bin/bash
# Package files cross from a PR build to publish.yml as one GitHub Actions
# artifact. actions/upload-artifact rejects any path containing ':', and a
# package with an epoch is named `name-1:ver-rel-arch.pkg.tar.zst` by
# makepkg. So the files ride inside a tar with a plain name and keep their
# own names untouched: pacman clients and bin/publish-artifact both rely on
# the filename matching PKGINFO.

# pack_packages <dir> <tar>: every *.pkg.tar.zst directly in <dir> into <tar>.
# Signatures and the scratch database next to them stay behind.
pack_packages() {
  local dir=$1 out=$2 restore files=()
  restore=$(shopt -p nullglob); shopt -s nullglob
  files=("$dir"/*.pkg.tar.zst)
  $restore
  (( ${#files[@]} )) || { echo "pack_packages: no *.pkg.tar.zst in $dir" >&2; return 1; }
  tar -cf "$out" -C "$dir" -- "${files[@]##*/}"
}

# unpack_packages <artifact dir> <dest>: the packages an unzipped artifact
# carried, into <dest>. Packed artifacts hold packages.tar; artifacts from
# builds before packing hold the bare files. The bare form can go once
# those artifacts have expired (7-day retention).
unpack_packages() {
  local src=$1 dest=$2 restore files=()
  mkdir -p "$dest"
  if [[ -f "$src/packages.tar" ]]; then
    tar -xf "$src/packages.tar" -C "$dest"
    return
  fi
  restore=$(shopt -p nullglob); shopt -s nullglob
  files=("$src"/*.pkg.tar.zst)
  $restore
  (( ${#files[@]} )) || { echo "unpack_packages: nothing to unpack in $src" >&2; return 1; }
  cp -- "${files[@]}" "$dest/"
}
