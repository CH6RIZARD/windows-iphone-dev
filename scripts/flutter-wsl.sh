#!/bin/bash
# Installs Flutter 3.47.6 in WSL and builds the Linux-hosted iOS gen_snapshot (omarchy-apple-dev/flutter/setup.sh).
# Safe to re-run. Log: ~/flutter-setup.log
set -e
exec > >(tee -a ~/flutter-setup.log) 2>&1
source ~/.local/share/swiftly/env.sh; export PATH="$HOME/flutter/bin:$HOME/.local/bin:$PATH"

echo "== packages"
sudo apt-get -o DPkg::Lock::Timeout=900 update -qq
sudo apt-get -o DPkg::Lock::Timeout=900 install -y -qq llvm clang rsync file zip unzip xz-utils curl git python3 python3-venv pkg-config >/dev/null

# Ubuntu ships some LLVM tools only under /usr/lib/llvm-N/bin; expose the ones build.sh needs.
llvmbin=$(ls -d /usr/lib/llvm-*/bin | sort -V | tail -1)
for t in llvm-strip llvm-lipo llvm-otool llvm-install-name-tool llvm-ar; do
  command -v $t >/dev/null || ln -sf "$llvmbin/$t" ~/.local/bin/$t
done

echo "== flutter"
if [ ! -x ~/flutter/bin/flutter ]; then
  curl -fL --retry 5 -C - -o /tmp/flutter.tar.xz https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.6-stable.tar.xz
  tar -xJf /tmp/flutter.tar.xz -C ~ && rm /tmp/flutter.tar.xz
fi
git config --global --add safe.directory '*'
flutter config --no-analytics >/dev/null; flutter --version | head -1
grep -q 'flutter/bin' ~/.bashrc || echo 'export PATH="$HOME/flutter/bin:$PATH"' >> ~/.bashrc

echo "== kit"
[ -d ~/omarchy-apple-dev ] || git clone --depth 1 https://github.com/joshuaswarren/omarchy-apple-dev ~/omarchy-apple-dev
chmod +x ~/omarchy-apple-dev/flutter/*.sh ~/omarchy-apple-dev/flutter/shims/* 2>/dev/null || true

echo "== ios gen_snapshot (long)"
~/omarchy-apple-dev/flutter/setup.sh
echo "== ALL DONE"
