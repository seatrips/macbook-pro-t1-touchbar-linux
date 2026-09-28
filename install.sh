#!/usr/bin/env bash
# Installs the MacBook Pro Touch Bar keyboard/touchpad setup on Omarchy.
# Safe to run again: existing files are backed up to *.bak.<timestamp> first.
set -euo pipefail
cd "$(dirname "$0")"
ts=$(date +%s)

backup() { [[ -e $1 ]] && cp "$1" "$1.bak.$ts" || true; }

echo "==> User config (Hyprland, xkb layout)"
mkdir -p ~/.config/xkb/symbols ~/.config/hypr
backup ~/.config/xkb/symbols/usmac
cp config/xkb/symbols/usmac ~/.config/xkb/symbols/usmac
backup ~/.config/hypr/macbook.lua
cp config/hypr/macbook.lua ~/.config/hypr/macbook.lua
if ! grep -q 'require("hypr.macbook")' ~/.config/hypr/input.lua; then
  backup ~/.config/hypr/input.lua
  printf '\n-- MacBook Pro Touch Bar keyboard and touchpad settings.\nrequire("hypr.macbook")\n' >> ~/.config/hypr/input.lua
fi

echo "==> System config (needs sudo): keyd, keyboard driver options"
command -v keyd >/dev/null || sudo pacman -S --needed --noconfirm keyd
sudo install -d /etc/keyd
[[ -e /etc/keyd/default.conf ]] && sudo cp /etc/keyd/default.conf /etc/keyd/default.conf.bak.$ts
sudo install -m644 etc/keyd/default.conf /etc/keyd/default.conf
sudo install -m644 etc/modprobe.d/applespi.conf /etc/modprobe.d/applespi.conf
sudo install -m644 etc/modprobe.d/hid_apple.conf /etc/modprobe.d/hid_apple.conf
sudo install -d /etc/libinput
[[ -e /etc/libinput/local-overrides.quirks ]] && sudo cp /etc/libinput/local-overrides.quirks /etc/libinput/local-overrides.quirks.bak.$ts
sudo install -m644 etc/libinput/local-overrides.quirks /etc/libinput/local-overrides.quirks
# Omarchy loads applespi from the initramfs, so the Fn remap only survives a
# reboot once the initramfs is rebuilt with the new modprobe.d file.
echo "==> Rebuilding initramfs so the Fn remap survives reboots"
if command -v limine-mkinitcpio >/dev/null; then
  sudo limine-mkinitcpio
else
  sudo mkinitcpio -P
fi
# Apply the Fn remap now, without a reboot.
[[ -e /sys/module/applespi/parameters/fnremap ]] && echo 7 | sudo tee /sys/module/applespi/parameters/fnremap >/dev/null
sudo systemctl enable --now keyd
sudo keyd reload

hyprctl reload >/dev/null 2>&1 || true
echo "Done. Check 'hyprctl configerrors' shows nothing."
echo "Log out and back in once for the touchpad tap settings to take effect."
