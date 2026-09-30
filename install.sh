#!/usr/bin/env bash
# Omarchy settings for a 2016-2017 Touch Bar MacBook Pro (T1).
#
#   ./install.sh                  keyboard layout, Hyprland touchpad/keyboard settings,
#                                 libinput touchpad quirks (use with a working Touch Bar)
#   ./install.sh --keyd-fallback  also puts Esc, F1-F12, volume and brightness on the
#                                 keyboard with keyd, for when the Touch Bar can't be revived
#
# The Touch Bar driver itself is not installed by this script; see the README.
# Safe to run again: existing files are backed up to *.bak.<timestamp> first.
set -euo pipefail
cd "$(dirname "$0")"
ts=$(date +%s)

fallback=0
case "${1:-}" in
  --keyd-fallback) fallback=1 ;;
  "") ;;
  *) echo "usage: $0 [--keyd-fallback]" >&2; exit 2 ;;
esac

backup() { [[ -e $1 ]] && cp "$1" "$1.bak.$ts" || true; }
sudo_backup() { [[ -e $1 ]] && sudo cp "$1" "$1.bak.$ts" || true; }

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

echo "==> System config (needs sudo): touchpad quirks, external Apple keyboards"
sudo install -m644 etc/modprobe.d/hid_apple.conf /etc/modprobe.d/hid_apple.conf
sudo install -d /etc/libinput
sudo_backup /etc/libinput/local-overrides.quirks
sudo install -m644 etc/libinput/local-overrides.quirks /etc/libinput/local-overrides.quirks

if (( fallback )); then
  echo "==> keyd fallback: Fn layer (F-keys, volume, brightness) and Caps + Tab = Esc"
  command -v keyd >/dev/null || sudo pacman -S --needed --noconfirm keyd
  sudo install -d /etc/keyd
  sudo_backup /etc/keyd/default.conf
  sudo install -m644 fallback/etc/keyd/default.conf /etc/keyd/default.conf
  sudo install -m644 fallback/etc/modprobe.d/applespi.conf /etc/modprobe.d/applespi.conf
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
elif [[ -e /etc/modprobe.d/applespi.conf ]] && grep -q 'fnremap=7' /etc/modprobe.d/applespi.conf; then
  echo "NOTE: the keyd fallback from an earlier install is still active (Fn sends Right Alt)."
  echo "      With a working Touch Bar, remove it so Fn switches the bar to F1-F12:"
  echo "      see 'Moving from the keyd fallback to the real Touch Bar' in the README."
fi

hyprctl reload >/dev/null 2>&1 || true
echo "Done. Check 'hyprctl configerrors' shows nothing."
echo "Log out and back in once for the touchpad settings to take effect."
