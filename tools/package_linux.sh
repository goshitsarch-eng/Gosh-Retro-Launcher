#!/usr/bin/env bash
# Packages an exported Linux binary (PCK embedded) as .tar.gz and .deb.
#
#   tools/package_linux.sh <x86_64|arm64> <version> <path-to-exported-binary> <output-dir>
#
# Produces, in <output-dir>:
#   program-manager-<version>-linux-<arch>.tar.gz
#   program-manager_<version>_<amd64|arm64>.deb      (needs dpkg-deb)
set -euo pipefail

arch="${1:?arch (x86_64|arm64)}"
version="${2:?version}"
binary="${3:?exported binary}"
out="${4:?output dir}"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
case "$arch" in
  x86_64) deb_arch=amd64 ;;
  arm64) deb_arch=arm64 ;;
  *) echo "unsupported arch: $arch" >&2; exit 2 ;;
esac

mkdir -p "$out"
out="$(cd "$out" && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

# ---- tar.gz: program-manager-<version>-linux-<arch>/{program-manager,program-manager.desktop,icon.png}
tar_root="$work/program-manager-${version}-linux-${arch}"
mkdir -p "$tar_root"
install -m 0755 "$binary" "$tar_root/program-manager"
install -m 0644 "$here/packaging/linux/program-manager.desktop" "$tar_root/program-manager.desktop"
install -m 0644 "$here/resources/icon.png" "$tar_root/program-manager.png"
tar -C "$work" -czf "$out/program-manager-${version}-linux-${arch}.tar.gz" "program-manager-${version}-linux-${arch}"

# ---- .deb
if command -v dpkg-deb >/dev/null 2>&1; then
  deb_root="$work/deb"
  mkdir -p "$deb_root/DEBIAN" "$deb_root/opt/program-manager" "$deb_root/usr/bin" \
    "$deb_root/usr/share/applications" "$deb_root/usr/share/icons/hicolor/512x512/apps"
  install -m 0755 "$binary" "$deb_root/opt/program-manager/program-manager"
  ln -s /opt/program-manager/program-manager "$deb_root/usr/bin/program-manager"
  install -m 0644 "$here/packaging/linux/program-manager.desktop" "$deb_root/usr/share/applications/program-manager.desktop"
  install -m 0644 "$here/resources/icon.png" "$deb_root/usr/share/icons/hicolor/512x512/apps/program-manager.png"
  cat > "$deb_root/DEBIAN/control" <<EOF
Package: program-manager
Version: ${version}
Section: utils
Priority: optional
Architecture: ${deb_arch}
Maintainer: Program Manager maintainers <noreply@example.invalid>
Depends: libc6, libgl1, libx11-6, libxcursor1, libxi6, libxinerama1, libxrandr2, libxkbcommon0
Recommends: xdg-desktop-portal
Homepage: https://github.com/goshitsarch-eng/Gosh-Retro-Launcher
Description: Windows 3.1 Program Manager clone
 A nostalgic recreation of the Windows 3.1 Program Manager (and a Windows 95 shell)
 for launching applications.
EOF
  dpkg-deb --root-owner-group --build "$deb_root" "$out/program-manager_${version}_${deb_arch}.deb"
else
  echo "dpkg-deb not found; skipping .deb" >&2
fi
ls -l "$out"
