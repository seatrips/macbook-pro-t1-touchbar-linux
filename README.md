# MacBook Pro Touch Bar on Linux: get Esc, F1–F12, volume and brightness back (Omarchy / Hyprland / Arch)

> **This does not make the Touch Bar light up.** It stays blank. This guide puts the keys the Touch Bar would give you on the physical keyboard instead: **Caps Lock + Tab** for Esc, and **Fn + number row / arrows** for F1–F12, volume and brightness. It also tunes the touchpad so it stops clicking by itself.

Tested on a **MacBook Pro 14,3** (15-inch, 2017, Touch Bar, T1 chip) running **[Omarchy](https://omarchy.org) 4** (Arch Linux + Hyprland), kernel 7.2, keyd 2.6. It should work the same on the other 2016–2017 Touch Bar models, which use the same `applespi` keyboard and touchpad driver. One command installs it all, and every change is explained below so you can also apply it by hand on another distro.

**Contents:** [Is this for me?](#is-this-for-me) · [What you get](#what-you-get) · [Install](#install) · [How it works](#how-it-works) · [Manual install / other distros](#manual-install-and-other-distros) · [Checking it works](#checking-it-works) · [Troubleshooting](#troubleshooting) · [Uninstall](#uninstall) · [FAQ](#faq) · [Optional extras](#optional-extras)

## Is this for me?

You're in the right place if you installed Linux on a Touch Bar MacBook Pro and:

- the **Touch Bar is black** / blank / does nothing,
- you have **no Esc key**, no F1–F12, and no volume or brightness keys,
- the **Fn key does nothing** on its own and can't be bound in Hyprland (or any other desktop),
- Caps Lock types odd characters like `ﬀ` instead of capitals (that's Omarchy's Compose key),
- the touchpad **clicks or starts selections by itself** while you type or rest your hand on it.

Check your model:

```bash
cat /sys/class/dmi/id/product_name
```

| Model identifier | Mac | Touch Bar | Covered |
|---|---|---|---|
| MacBookPro13,2 | 13-inch, 2016, four Thunderbolt 3 ports (A1706) | Yes | Should work (same driver), untested |
| MacBookPro13,3 | 15-inch, 2016 (A1707) | Yes | Should work (same driver), untested |
| MacBookPro14,2 | 13-inch, 2017, four Thunderbolt 3 ports (A1706) | Yes | Should work (same driver), untested |
| **MacBookPro14,3** | **15-inch, 2017 (A1707)** | **Yes** | **Tested** |
| MacBookPro13,1 / 14,1 | 13-inch, two ports, real function keys (A1708) | No | You don't need the Fn layer; the touchpad part still applies |
| 2018 and later (T2 chip) | | Yes | **No.** These use a different keyboard driver; see [t2linux.org](https://wiki.t2linux.org) |

Confirm the driver with `lsmod | grep applespi`. If that prints nothing, this setup won't do anything on your machine.

## What you get

### Keyboard

| Keys | Does |
|---|---|
| **Fn + 1 … 0, -, =** | F1 … F12 |
| **Fn + ↑ / ↓** | Volume up / down |
| **Fn + → / ←** | Screen brightness up / down |
| **Fn + Backspace** | Forward Delete |
| **Caps Lock + Tab** | Esc |
| **Caps Lock** (tap) | Normal Caps Lock (no more Compose) |
| **§ / ±** | The key left of 1 on ISO (European) keyboards |

**Right Option** works the same as Fn (see [Trade-offs](#trade-offs-and-gotchas)).

### Touchpad

| Gesture | Does |
|---|---|
| **4-finger swipe left / right** | Switch workspace |
| **2-finger scroll** | macOS-style "natural" scrolling |
| **2-finger tap** | Right click |
| **3-finger tap** | Middle click |
| **Firm click and drag** | Select text / drag windows |

Light brushes and resting palms are ignored, the touchpad pauses while you type, and tap-and-drag and three-finger drag are off, because they kept starting selections by themselves.

## Install

On a fresh Omarchy install, one command sets up everything:

```bash
git clone https://github.com/seatrips/omarchy-macbook-touchbar-workaround.git ~/omarchy-macbook-touchbar-workaround && ~/omarchy-macbook-touchbar-workaround/install.sh
```

Already cloned it? Update and re-apply with:

```bash
cd ~/omarchy-macbook-touchbar-workaround && git pull && ./install.sh
```

What the script does:

1. Copies the Hyprland and keyboard-layout files to `~/.config` and adds one `require("hypr.macbook")` line to `~/.config/hypr/input.lua`.
2. Installs `keyd` if it's missing, and copies its config plus the driver and touchpad settings to `/etc` (asks for your sudo password).
3. Rebuilds the initramfs (`limine-mkinitcpio`), so the Fn remap survives a reboot.
4. Turns on the Fn remap right away and starts keyd.

Every file it replaces is backed up to `<file>.bak.<timestamp>` first, so it's safe to run again. The keyboard works straight away. **Log out and back in once** for the touchpad settings. A reboot is not required, but it's the best test that everything sticks.

## How it works

The Touch Bar is a separate little computer (the T1 chip) that Linux has no working driver for here, so it never shows any keys. The physical keyboard is fine, but its **Fn key is handled inside the `applespi` driver** and never reaches the desktop, so you can't bind anything to it. The fix has three parts:

1. **Make Fn visible.** The `applespi` driver has a `fnremap` option. `fnremap=7` makes Fn send **Right Alt** (Right Option), a normal key that other programs can see.
2. **Turn Fn into a layer.** [keyd](https://github.com/rvaiya/keyd) is a system-wide key remapper that works below Wayland/X11. It treats Right Alt as a layer key: while it's held, the number row becomes F1–F12 and the arrows become volume and brightness. Caps Lock becomes a layer too, which gives Caps + Tab = Esc while a tap still toggles Caps Lock.
3. **Tame the touchpad.** A libinput quirks file raises the minimum contact size for a touch and lowers the palm threshold, and Hyprland settings turn off the drag features that misfire.

| File in this repo | Installed to | Purpose |
|---|---|---|
| [`etc/modprobe.d/applespi.conf`](etc/modprobe.d/applespi.conf) | `/etc/modprobe.d/` | `options applespi fnremap=7`: Fn sends Right Alt. Omarchy loads this driver from the initramfs, so the initramfs must be rebuilt or the option is ignored after a reboot. |
| [`etc/keyd/default.conf`](etc/keyd/default.conf) | `/etc/keyd/` | The "fn" layer (F-keys, volume, brightness, Delete) and the "caps" layer (Caps + Tab = Esc). Edit this file to change what Fn does, then `sudo keyd reload`. |
| [`etc/modprobe.d/hid_apple.conf`](etc/modprobe.d/hid_apple.conf) | `/etc/modprobe.d/` | `fnmode=2`: F-keys first on *external* Apple keyboards. Doesn't affect the built-in one. |
| [`etc/libinput/local-overrides.quirks`](etc/libinput/local-overrides.quirks) | `/etc/libinput/` | `AttrTouchSizeRange=300:250` (default 150:130): a contact must be bigger to count as a touch. `AttrPalmSizeThreshold=900` (default 1600): big contacts count as a palm sooner. `AttrKeyboardIntegration=internal` for keyd's virtual keyboard: keyd re-sends every keystroke from a virtual *USB* keyboard, so without this libinput thinks you're typing on an external keyboard and never pauses the touchpad. |
| [`config/xkb/symbols/usmac`](config/xkb/symbols/usmac) | `~/.config/xkb/symbols/` | US layout plus § / ± on the extra ISO key. |
| [`config/hypr/macbook.lua`](config/hypr/macbook.lua) | `~/.config/hypr/` | Hyprland (Lua config): `usmac` layout, Compose key off, natural scrolling, tap button map, 4-finger workspace swipe, tap-and-drag / drag lock / three-finger drag off. |

## Trade-offs and gotchas

- **Right Option is taken.** The driver can only remap Fn to a key the MacBook already has. Right Option is the least used, so it doubles as Fn.
- **No Page Up / Page Down / Home / End.** Fn + arrows normally give those; here they're volume and brightness. Change the `[fn]` section in `/etc/keyd/default.conf` if you'd rather have them (e.g. `up = pageup`).
- **No Compose key.** Omarchy normally makes Caps Lock a Compose key; that's switched off so Caps Lock gives capitals.
- **No 3-finger swipes.** They never reached Hyprland on this touchpad, so the workspace swipe uses 4 fingers.
- **Selecting needs a firm click.** The Force Touch pad only clicks on a firm press. With tap-and-drag off, press, hold and drag.
- **Right click pastes inside Claude Code.** That's Claude Code's own behavior, not the touchpad. Everywhere else a right click is a normal right click.

## Manual install and other distros

The keyboard part isn't Omarchy-specific: `fnremap` + keyd work on any distro and any desktop (GNOME, KDE, Sway, X11), because keyd runs below all of them.

```bash
# 1. Fn -> Right Alt, now and on every boot
echo 'options applespi fnremap=7' | sudo tee /etc/modprobe.d/applespi.conf
echo 7 | sudo tee /sys/module/applespi/parameters/fnremap
sudo mkinitcpio -P            # Omarchy/Limine: sudo limine-mkinitcpio
                              # Debian/Ubuntu: sudo update-initramfs -u
                              # Fedora: sudo dracut --force

# 2. keyd with the Fn and Caps layers
sudo pacman -S keyd           # or your distro's package / build from source
sudo install -Dm644 etc/keyd/default.conf /etc/keyd/default.conf
sudo systemctl enable --now keyd

# 3. Touchpad quirks (log out and back in afterwards)
sudo install -Dm644 etc/libinput/local-overrides.quirks /etc/libinput/local-overrides.quirks
```

On a non-Omarchy Hyprland setup, copy the settings you want from [`config/hypr/macbook.lua`](config/hypr/macbook.lua) into your own config. On GNOME or KDE, set natural scrolling and tap-to-click in their settings apps instead.

## Checking it works

- `cat /sys/module/applespi/parameters/fnremap` prints `7`.
- `systemctl is-active keyd` prints `active`.
- `sudo keyd monitor`, then press Fn: it should show `rightalt`. (Ctrl + C to quit.)
- In a browser, **Fn + 5** (F5) reloads the page, and **Fn + ↑** raises the volume.
- `hyprctl configerrors` prints nothing.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Fn keys worked, then stopped after a reboot; `fnremap` prints `0` | The initramfs wasn't rebuilt, so the driver loaded without the option. Run `sudo limine-mkinitcpio` (or `sudo mkinitcpio -P`) and reboot. |
| Fn does nothing, `fnremap` is `7` | keyd isn't running: `sudo systemctl enable --now keyd`, then check `journalctl -u keyd` for config errors. |
| Caps Lock gives `ﬀ`, `æ` or other odd characters | The Compose key is still on: make sure `~/.config/hypr/input.lua` contains `require("hypr.macbook")` and run `hyprctl reload`. |
| Touchpad still clicks by accident | Log out and in (quirks only load then). Still too sensitive? Raise `AttrTouchSizeRange` (e.g. `350:300`) and lower `AttrPalmSizeThreshold` (e.g. `800`). |
| Real taps get missed | Lower `AttrTouchSizeRange` a step (e.g. `250:210`), then log out and in. |
| Touchpad reacts while typing | Check the quirk is applied: `sudo libinput quirks list /dev/input/eventN` for keyd's virtual keyboard (find N with `sudo libinput list-devices`) should show `AttrKeyboardIntegration=internal`. |
| `hyprctl configerrors` shows errors | Your Omarchy may be older than 4 (the config is Lua). Copy the settings into your `.conf` files by hand. |

## Uninstall

```bash
sudo systemctl disable --now keyd
sudo rm /etc/keyd/default.conf /etc/modprobe.d/applespi.conf /etc/modprobe.d/hid_apple.conf /etc/libinput/local-overrides.quirks
sudo limine-mkinitcpio        # or: sudo mkinitcpio -P
rm ~/.config/hypr/macbook.lua ~/.config/xkb/symbols/usmac
sed -i '/hypr.macbook/d;/MacBook Pro Touch Bar keyboard/d' ~/.config/hypr/input.lua
```

Then reboot. The `*.bak.<timestamp>` files next to each installed file are the versions from before the first install, if you want to restore those.

## FAQ

**Can the Touch Bar itself be made to work?** On the 2016–2017 (T1) models there is an out-of-tree driver: [nohzafk/omarchy-macbookpro-t1](https://github.com/nohzafk/omarchy-macbookpro-t1). It needs the T1's firmware, which comes from macOS. If you installed Linux over the whole disk and wiped macOS, the T1 sits in recovery mode (`05ac:1281` in `lsusb`), and you'd have to reinstall macOS and then install Linux next to it. This guide is for everyone who doesn't want to do that.

**Why keyd and not Hyprland keybindings?** Hyprland can't see Fn at all, and a keyd layer makes F1–F12 real F-keys that every program (and the Linux console) understands, instead of shortcuts that only exist inside Hyprland.

**Will an Omarchy update undo this?** No. Everything lives in `/etc` and in your own `~/.config/hypr`, which Omarchy updates don't overwrite. A kernel update rebuilds the initramfs with the `/etc/modprobe.d` file included.

**Do USB-C docks and adapters work?** Yes, as far as tested: a USB-C Ethernet adapter (`cdc_ncm` driver) worked out of the box at 1 Gbit/s, and NetworkManager preferred it over Wi-Fi automatically.

**Is the built-in Wi-Fi really that bad?** On the 14,2 and 14,3 it can be; see the [Wi-Fi fix](#optional-fix-weak-wi-fi-signal) below.

## Optional extras

These aren't needed for the keyboard and touchpad, and `install.sh` doesn't do them.

### Optional: stop Bluetooth auto-accepting pairings

This isn't specific to MacBooks, and `install.sh` doesn't do it. Omarchy runs `bt-agent -c NoInputNoOutput` (the `bt-agent` user service), which **accepts every Bluetooth pairing request without asking**. While Bluetooth is on, someone nearby who knows your laptop's Bluetooth address could pair a device, such as a fake keyboard, and you'd see no prompt. On a laptop you use for work or private things, turn it off:

```bash
systemctl --user disable --now bt-agent.service
systemctl --user mask bt-agent.service
```

Devices you've already paired keep working. To pair a new one, use `bluetui` (or the Omarchy menu), which asks you to confirm. To undo:

```bash
systemctl --user unmask bt-agent.service && systemctl --user enable --now bt-agent.service
```

### Optional: fix weak Wi-Fi signal

This only applies to models with the Broadcom **BCM43602** Wi-Fi chip (14,2 and 14,3, and some 13,x; check with `lspci | grep -i 43602`). `install.sh` doesn't do it.

The Linux firmware for this chip is from 2015 and can't detect the country it's in. It then transmits at a bogus **31 dBm**, which also drowns out its own receiver: the signal shows around -93 dBm even with a phone hotspot right next to the laptop, and speeds drop to a few Mbit/s ([kernel bug 193121](https://bugzilla.kernel.org/show_bug.cgi?id=193121)). Capping transmit power at 10 dBm fixes most of it. On the 14,3 this setup was written on:

| | Before | After (first test) | After reboot, set by the script |
|---|---|---|---|
| Transmit power | 31 dBm | 10 dBm | 10 dBm |
| Signal | -93 dBm | -83 dBm | -81 dBm |
| Download (rx) | 2 Mbit/s | 86.6 Mbit/s | 86.6 Mbit/s |
| Upload (tx) | 6.5 Mbit/s | 39 Mbit/s | 78 Mbit/s |

Try it first (lasts until reboot; replace `wlp3s0` with your interface from `iw dev`):

```bash
sudo iw dev wlp3s0 set txpower fixed 1000
iw dev wlp3s0 link | grep -E 'signal|bitrate'
```

To keep it, install [`etc/NetworkManager/dispatcher.d/90-wifi-txpower`](etc/NetworkManager/dispatcher.d/90-wifi-txpower). It re-applies the cap every time Wi-Fi connects (after boot, sleep or a reconnect). It assumes the interface is `wlp3s0`; edit the name in the script if yours differs. A udev rule doesn't work here, because the driver ignores the setting until the interface is up.

```bash
sudo install -o root -g root -m 755 etc/NetworkManager/dispatcher.d/90-wifi-txpower /etc/NetworkManager/dispatcher.d/
```

Reboot once to confirm it sticks (tested on the 14,3: after a reboot the cap was applied without doing anything). Then check with `iw dev wlp3s0 info | grep txpower`, which should say `10.00 dBm`. If it still says `31.00 dBm`, the interface name in the script doesn't match yours, or the file isn't executable and owned by root (NetworkManager skips it otherwise). To undo: `sudo rm /etc/NetworkManager/dispatcher.d/90-wifi-txpower`. Wi-Fi stays 2.4 GHz only; a USB Wi-Fi adapter is the only full fix.

### Optional: Security Watch (firewall and daily security checks)

This isn't specific to MacBooks, and `install.sh` doesn't do it. It's for when you use the laptop for work or private things and want to hear about problems without checking yourself. It sets up:

- **[OpenSnitch](https://github.com/evilsocket/opensnitch)**, an application firewall. The first time a program connects to the internet, a popup asks whether to allow it. Three rules come preinstalled so the basics work without popups: local DNS, the system resolver (`systemd-resolved`) and clock sync (`systemd-timesyncd`).
- **Security Watch**, a script that a systemd timer runs once a day (and catches up after the laptop was off). It sends a desktop notification **only for new findings**, so it stays quiet until something needs doing:
  - `arch-audit --upgradable`: installed packages with known vulnerabilities that an update fixes. Run `omarchy update`.
  - `rkhunter`: rootkits and system files that were swapped out. A pacman hook refreshes its baseline after every update, so updates don't cause alerts.
  - `lynis`: a system hardening audit, on Sundays.

Install it with:

```bash
cd ~/omarchy-macbook-touchbar-workaround && ./security/install.sh
sudo systemctl start security-watch   # first check now instead of waiting a day
```

Then open OpenSnitch's preferences (the tray icon) and set the popup's **default duration to "once"**. Otherwise a popup you miss blocks that program for 12 hours. Allow the programs you trust "always": your browser, `NetworkManager`, `pacman`, `git-remote-http`, and `arch-audit` (it downloads the Arch security feed).

| File in this repo | Installed to | Purpose |
|---|---|---|
| `security/usr/local/bin/security-watch` | `/usr/local/bin/` | Runs the three checks and notifies you about new findings. The details go to `/var/log/security-watch.log`. |
| `security/etc/systemd/system/security-watch.{service,timer}` | `/etc/systemd/system/` | Runs the script daily, 10 minutes after boot and in the background at low priority. |
| `security/etc/pacman.d/hooks/rkhunter-propupd.hook` | `/etc/pacman.d/hooks/` | Updates rkhunter's file baseline after package updates. |
| `security/etc/rkhunter.conf.local` | `/etc/` | Whitelists rkhunter warnings that are normal on Arch/Omarchy (`egrep`/`fgrep`/`ldd` being scripts, hidden Kerberos man pages, unset sshd options while sshd is off). |
| `security/etc/lynis/custom.prf` | `/etc/lynis/` | Skips lynis' "vulnerable packages" test, because it also counts CVEs with no fix yet. `arch-audit --upgradable` covers the ones you can fix. |
| `security/etc/opensnitchd/rules/000-allow-*.json` | `/etc/opensnitchd/rules/` | The three basic allow rules. |

If a notification turns out to be a false positive on your machine, add it to `/etc/rkhunter.conf.local` (for rkhunter) or `/etc/lynis/custom.prf` (`skip-test=<ID>`, for lynis). To undo: `sudo systemctl disable --now security-watch.timer opensnitchd`, remove the `opensnitch-ui` line from `~/.config/hypr/autostart.lua`, and remove the files listed above.

