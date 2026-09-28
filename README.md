# Omarchy on a MacBook Pro with Touch Bar: a workaround

> **This does not make the Touch Bar work.** It stays blank. Instead, this setup puts the keys the Touch Bar would give you (Esc, F1–F12, volume, brightness) on the regular keyboard: **Caps Lock + Tab** for Esc, and **Fn** + number row or arrows for the rest.

Keyboard and touchpad setup for **Omarchy** (Hyprland) on a **MacBook Pro 14,3** (15", 2017, Touch Bar, T1 chip). It should also work on other 2016–2017 Touch Bar models (13,x / 14,2 / 14,3), whose keyboard and touchpad use the `applespi` driver.

## Why this is needed

On these MacBooks the **Touch Bar stays blank on Linux**: no Touch Bar driver is loaded. That means no Esc, no F1–F12, and no volume or brightness keys. The Fn key doesn't work as a key by itself either. The keyboard driver handles it internally, so the desktop never sees it.

This setup puts all those missing keys on the physical keyboard.

## What you get

### Keyboard

| Keys | Does |
|---|---|
| **Fn + 1 … 0, -, =** | F1 … F12 |
| **Fn + ↑ / ↓** | Volume up / down |
| **Fn + → / ←** | Brightness up / down |
| **Fn + Backspace** | Forward Delete |
| **Caps Lock + Tab** | Esc |
| **Caps Lock** (tap) | Normal Caps Lock |
| **§ / ±** | The key left of 1 (ISO keyboard) |

**Right Option** works the same as Fn (see "How it works").

### Touchpad

| Gesture | Does |
|---|---|
| **4-finger swipe left / right** | Switch workspace |
| **2-finger scroll** | macOS-style "natural" scrolling |
| **2-finger tap** | Right click |
| **3-finger tap** | Middle click |

Light brushes and resting palms are ignored, so tapping causes fewer accidental clicks.

## Install

On a fresh Omarchy install, one command sets up everything:

```bash
git clone https://github.com/seatrips/omarchy-macbook-touchbar-workaround.git ~/omarchy-macbook-touchbar-workaround && ~/omarchy-macbook-touchbar-workaround/install.sh
```

Already cloned it? Update and re-apply with:

```bash
cd ~/omarchy-macbook-touchbar-workaround && git pull && ./install.sh
```

The script asks for your sudo password for the system files. It backs up every file it replaces to `<file>.bak.<timestamp>`, so you can run it more than once. The keyboard changes apply right away. **Log out and back in once** for the touchpad tap settings to take effect.

## How it works

| File in this repo | Installed to | Purpose |
|---|---|---|
| `etc/modprobe.d/applespi.conf` | `/etc/modprobe.d/` | `fnremap=7` tells the keyboard driver to make **Fn** send **Right Alt**, so keyd can see it. Omarchy loads this driver from the initramfs, so `install.sh` rebuilds it (`limine-mkinitcpio`). Otherwise the setting is lost on reboot. |
| `etc/keyd/default.conf` | `/etc/keyd/` | [keyd](https://github.com/rvaiya/keyd) turns Right Alt (= Fn) into an "fn" layer (F-keys, volume, brightness, Delete), and holding Caps Lock into a "caps" layer (Caps+Tab = Esc). |
| `etc/modprobe.d/hid_apple.conf` | `/etc/modprobe.d/` | `fnmode=2` makes F-keys come first on external Apple keyboards. It doesn't affect the built-in keyboard. |
| `etc/libinput/local-overrides.quirks` | `/etc/libinput/` | Touchpad driver tweak: a contact has to be bigger before it counts as a touch (`AttrTouchSizeRange=200:170`, default 150:130), and large contacts are treated as palms sooner (`AttrPalmSizeThreshold=1200`, default 1600). Fewer accidental taps. Raise the numbers if taps still happen by accident, lower them if real taps get missed. |
| `config/xkb/symbols/usmac` | `~/.config/xkb/symbols/` | US layout plus § / ± on the extra ISO key. |
| `config/hypr/macbook.lua` | `~/.config/hypr/` | Hyprland: `usmac` layout, **no Compose key** on Caps Lock (Omarchy's default), touchpad gestures, tap and scroll settings. `install.sh` adds `require("hypr.macbook")` to `~/.config/hypr/input.lua`. |

## Trade-offs and gotchas

- **Right Option is taken.** The driver can only remap Fn to a key the MacBook already has. Right Option is the least used, so it now works as a second Fn.
- **No Page Up / Page Down / Home / End.** Normally Fn + arrows give those. Here Fn + arrows control volume and brightness instead.
- **No Compose key.** Omarchy normally uses Caps Lock as Compose for special characters. That's switched off so Caps Lock works normally. If Caps Lock doesn't give capitals but strange small letters (Caps then `f` `f` gives `ﬀ`), this is the reason.
- **No 3-finger swipes.** They never reached Hyprland on this touchpad, so the workspace swipe uses 4 fingers.
- **Right click pastes inside Claude Code.** That's Claude Code's own behavior, not a touchpad problem. Everywhere else a right click is a normal right click.

## Checking it works

- `hyprctl configerrors` should print nothing.
- `cat /sys/module/applespi/parameters/fnremap` should print `7`. If it prints `0` after a reboot, the initramfs wasn't rebuilt: run `sudo limine-mkinitcpio` and reboot.
- `systemctl is-active keyd` should print `active`.
- On a web page, **Fn + 5** (F5) should reload the page.
