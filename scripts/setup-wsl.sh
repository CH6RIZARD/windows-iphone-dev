#!/usr/bin/env bash
# Run inside WSL Ubuntu after virtualization is enabled: bash scripts/setup-wsl.sh
set -e
sudo apt-get update
sudo apt-get install -y usbmuxd libimobiledevice-utils curl git unzip binutils-gold zip gnupg2 libc6-dev libcurl4-openssl-dev libgcc-15-dev libpython3-dev libstdc++-15-dev libxml2-dev libncurses-dev libz3-dev pkg-config zlib1g-dev
# Swift toolchain via swiftly (xtool needs Swift 6+)
cd /tmp && curl -fO https://download.swift.org/swiftly/linux/swiftly-$(uname -m).tar.gz
cd /tmp && tar zxf swiftly-$(uname -m).tar.gz && ./swiftly init --quiet-shell-followup -y
. ~/.local/share/swiftly/env.sh
# xtool on PATH
# Unpack the AppImage so no FUSE is needed
mkdir -p ~/.local/bin ~/.local/opt && cd ~/.local/opt && rm -rf xtool squashfs-root
curl -fL -o x.AppImage "https://github.com/xtool-org/xtool/releases/latest/download/xtool-$(uname -m).AppImage" && chmod +x x.AppImage
./x.AppImage --appimage-extract >/dev/null && mv squashfs-root xtool && rm x.AppImage
ln -sf ~/.local/opt/xtool/AppRun ~/.local/bin/xtool && cd ~
grep -q swiftly/env.sh ~/.bashrc || echo '. ~/.local/share/swiftly/env.sh' >> ~/.bashrc
grep -q '.local/bin' ~/.bashrc || echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo "Done. Next: download Xcode .xip from developer.apple.com, then run: xtool setup"
