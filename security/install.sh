#!/usr/bin/env bash
# Optional: installs Security Watch (OpenSnitch firewall + daily arch-audit,
# rkhunter and lynis checks with desktop notifications) on Omarchy.
# Not MacBook-specific, and the main install.sh doesn't run it.
# Safe to run again: existing files are backed up to *.bak.<timestamp> first.
set -euo pipefail
cd "$(dirname "$0")"
ts=$(date +%s)

sinstall() { # sinstall MODE SRC DEST
  [[ -e $3 ]] && sudo cp "$3" "$3.bak.$ts"
  sudo install -D -m"$1" "$2" "$3"
}

echo "==> Packages (needs sudo)"
sudo pacman -S --needed --noconfirm opensnitch rkhunter lynis arch-audit libnotify

echo "==> OpenSnitch: allow local DNS, the system resolver and clock sync"
for rule in etc/opensnitchd/rules/*.json; do
  sinstall 600 "$rule" "/etc/opensnitchd/rules/$(basename "$rule")"
done
sudo systemctl enable --now opensnitchd
if ! grep -q 'opensnitch-ui' ~/.config/hypr/autostart.lua 2>/dev/null; then
  mkdir -p ~/.config/hypr
  [[ -e ~/.config/hypr/autostart.lua ]] && cp ~/.config/hypr/autostart.lua ~/.config/hypr/autostart.lua.bak.$ts
  printf 'o.launch_on_start("opensnitch-ui --background")\n' >> ~/.config/hypr/autostart.lua
fi
pgrep -x opensnitch-ui >/dev/null || (setsid opensnitch-ui --background >/dev/null 2>&1 &)

echo "==> rkhunter and lynis config"
sinstall 644 etc/rkhunter.conf.local /etc/rkhunter.conf.local
sinstall 644 etc/lynis/custom.prf /etc/lynis/custom.prf
sinstall 644 etc/pacman.d/hooks/rkhunter-propupd.hook /etc/pacman.d/hooks/rkhunter-propupd.hook
# rkhunter compares files against this baseline; the hook refreshes it after updates.
sudo rkhunter --propupd --nolog

echo "==> Security Watch script and daily timer (notifies $USER)"
tmp=$(mktemp)
sed "s/^NOTIFY_USER=.*/NOTIFY_USER=$USER/" usr/local/bin/security-watch > "$tmp"
sinstall 755 "$tmp" /usr/local/bin/security-watch
rm -f "$tmp"
sinstall 644 etc/systemd/system/security-watch.service /etc/systemd/system/security-watch.service
sinstall 644 etc/systemd/system/security-watch.timer /etc/systemd/system/security-watch.timer
sudo systemctl daemon-reload
sudo systemctl enable --now security-watch.timer

echo "Done. Run a first check now with: sudo systemctl start security-watch"
echo "Results go to /var/log/security-watch.log; you only get a notification for new findings."
echo "In OpenSnitch's preferences, set the popup default duration to \"once\"."
