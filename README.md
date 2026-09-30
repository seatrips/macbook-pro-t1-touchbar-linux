# MacBook Pro T1 Touch Bar on Linux: working Touch Bar, Fn keys and touchpad (Omarchy / Hyprland / Arch)

A complete, tested walkthrough for the **2016–2017 Touch Bar MacBook Pro** (T1 chip) on Linux: bring a **dead, black Touch Bar** back (even after Linux wiped macOS), get **Esc, F1–F12, volume and brightness** on it, and set up the keyboard and touchpad for **[Omarchy](https://omarchy.org)** (Arch Linux + Hyprland).

Don't want the Touch Bar at all? There's a [keyboard-only fallback](#fallback-no-touch-bar-keys-on-the-keyboard-instead) that puts Esc and F1–F12 on the physical keys instead.

Done on a **MacBook Pro 14,3** (15-inch, 2017) with a full-disk Omarchy 4 install, kernel 7.2. Result: Touch Bar lit with Esc and media keys, **hold Fn for F1–F12**, FaceTime camera and ambient light sensor working, with automatic screen brightness. The Touch Bar driver and T1 recovery come from other people's projects (credited below); this repo ties them together and adds the Omarchy side.

**Contents:** [Is this for me?](#is-this-for-me) · [How the T1 works](#how-the-t1-works-and-why-the-touch-bar-goes-black) · [Step 1: back up](#step-1-back-up-the-t1-firmware) · [Step 2: revive the T1](#step-2-revive-the-t1-if-its-in-recovery-mode) · [Step 3: Touch Bar driver](#step-3-install-a-touch-bar-driver) · [Step 4: Omarchy settings](#step-4-omarchy-keyboard-and-touchpad-settings) · [What works](#what-works-now) · [Troubleshooting](#troubleshooting) · [keyd fallback](#fallback-no-touch-bar-keys-on-the-keyboard-instead) · [FAQ](#faq) · [Optional extras](#optional-extras) · [Credits](#credits)

## Is this for me?

You're in the right place if you run Linux on a Touch Bar MacBook Pro and:

- the **Touch Bar is black** / blank / does nothing,
- you have **no Esc key**, no F1–F12, no volume or brightness keys,
- the FaceTime **camera is missing**,
- `lsusb` shows **`05ac:1281 Apple, Inc. Mobile Device (Recovery Mode)`**,
- or the touchpad **clicks and starts selections by itself**.

Check your model and the T1's state:

```bash
cat /sys/class/dmi/id/product_name       # which Mac
lsusb | grep -i 05ac                     # 8600 = T1 running, 1281 = T1 in recovery mode
```

| Model identifier | Mac | This guide |
|---|---|---|
| MacBookPro13,2 | 13-inch 2016, four Thunderbolt 3 ports (A1706) | Yes (T1). Tested by the projects linked below. |
| MacBookPro13,3 | 15-inch 2016 (A1707) | Yes (T1). Tested by the projects linked below. |
| MacBookPro14,2 | 13-inch 2017, four Thunderbolt 3 ports (A1706) | Yes (T1). Tested by the projects linked below. |
| **MacBookPro14,3** | **15-inch 2017 (A1707)** | **Yes (T1). Tested here, end to end.** |
| MacBookPro13,1 / 14,1 | 13-inch, two ports, physical F-keys (A1708) | No Touch Bar. Only [Step 4](#step-4-omarchy-keyboard-and-touchpad-settings) applies. |
| MacBookPro15,x and later | 2018+ (T2 chip) | **No.** Different chip; see [t2linux.org](https://wiki.t2linux.org). T2 guides don't work on T1 either. |

## How the T1 works (and why the Touch Bar goes black)

The Touch Bar, FaceTime camera, ambient light sensor and Touch ID all hang off the **T1**, a small ARM chip that shows up to Linux as a USB device. The T1 has **no firmware of its own**: at power-on, the Mac's boot firmware loads it from the EFI System Partition, `EFI/APPLE/EMBEDDEDOS/` (about 30 MB, personalised to your chip).

Most Linux installers recreate the EFI partition, which **erases that folder**. The T1 then has nothing to boot and falls back to **recovery mode** (`05ac:1281`). The Touch Bar goes black and the camera disappears, and no driver can help, because the chip isn't running. That's what happened here.

So there are two separate problems:

1. **Is the T1 running?** `05ac:8600` = yes, go to Step 3. `05ac:1281` = no, do Step 2 first.
2. **Does Linux drive the Touch Bar?** That needs a driver (Step 3). Without one, even a running T1 shows a black or static bar.

## Step 1: back up the T1 firmware

If `EFI/APPLE` still exists on your disk (macOS still installed, or you haven't reinstalled yet), **copy it somewhere off this disk first**: a USB stick, another computer, cloud storage. With a backup, a wiped EFI partition later is a 5-second file copy. Without one, you depend on Apple still signing this firmware (Step 2).

```bash
git clone https://github.com/creolben/macbook-t1-touchbar ~/macbook-t1-touchbar
sudo ~/macbook-t1-touchbar/standalone/t1-touchbar.sh backup-firmware
```

Already revived with Step 2? Back up right after that too; `t1-revive backup --to <path>` does the same.

## Step 2: revive the T1 (if it's in recovery mode)

Only needed if `lsusb` shows `05ac:1281`. **[niconistal/t1-revive](https://github.com/niconistal/t1-revive)** rebuilds the T1 firmware **from Linux alone, without macOS**: it drives Apple's own restore protocol, lets the chip fetch its Apple-signed data from Apple's servers, boots the T1 and puts the files back on the EFI partition so the Mac loads them at every boot.

```bash
git clone https://github.com/niconistal/t1-revive ~/t1-revive && cd ~/t1-revive
bash build.sh                              # builds patched libimobiledevice tools into prefix/
sudo bin/t1-revive preflight               # read-only checks, installs acpi_call-dkms and headers
sudo bin/t1-revive regenerate              # about 5 minutes, asks before each device step
```

**Read its README before running it.** It writes to the T1 and needs mains power, a network connection to Apple and you at the keyboard. If a step fails: shut down fully, wait 20 seconds, power on and run `sudo bin/t1-revive regenerate --from <step>`.

Afterwards `lsusb` shows `05ac:8600 iBridge`, and it stays that way across reboots (confirmed here: the first boot after the revive enumerated `8600` straight away). The camera works right away (`uvcvideo`); the Touch Bar needs Step 3. **Now do Step 1** if you couldn't before.

## Step 3: install a Touch Bar driver

There are two drivers. They **conflict**, so pick one:

| | [t1bridge](https://github.com/standardagents/t1bridge) | [macbook-t1-touchbar](https://github.com/creolben/macbook-t1-touchbar) (used here) |
|---|---|---|
| Touch Bar | ✅ own renderer | ✅ Esc + media keys, Fn = F1–F12 |
| Camera | ✅ | ✅ (plain `uvcvideo`) |
| **Touch ID** | ✅ via `fprintd` | ❌ |
| What it is | Full T1 stack, signed Arch packages | Ronald Tschalär's `apple-ibridge` kernel driver, patched for current kernels, via DKMS |
| Size | Larger, third-party package repo | Small, three kernel modules + one boot service |

**Want Touch ID? Use t1bridge**; t1-revive's [docs/omarchy.md](https://github.com/niconistal/t1-revive/blob/main/docs/omarchy.md) covers the Omarchy details (firewall rule, PAM lines). The rest of this section is the small driver this machine uses:

```bash
cd ~/macbook-t1-touchbar/standalone
./t1-touchbar.sh status                    # read-only: firmware, USB, HID, driver, DKMS
sudo ./bootstrap-t1-touchbar.sh            # prerequisites, patch + build, DKMS, boot service, initramfs
./t1-touchbar.sh audit-boot                # will it come up by itself after a reboot?
```

What ends up on the system (copies of this machine's files are in [`touchbar/`](touchbar/)):

| File | Purpose |
|---|---|
| DKMS module `appleibridge` | `apple-ibridge`, `apple-ib-tb`, `apple-ib-als`; rebuilt automatically on kernel updates. The patch only adapts three functions to kernel API changes (`report_fixup` returns `const`, `platform_driver.remove` returns `void`, no `.owner` on ACPI drivers). |
| `/etc/modules-load.d/apple-touchbar.conf` | Loads the driver at boot. The copy in this repo also loads `apple-ib-als` (light sensor); see [below](#optional-ambient-light-sensor-and-automatic-brightness). |
| `/etc/modprobe.d/apple-ib-tb.conf` | `options apple-ib-tb fnmode=1`: the bar shows Esc + brightness/volume/media, **hold Fn for F1–F12**. `fnmode=2` flips that; `0` = F-keys only; `3` = media keys only. |
| `/etc/modprobe.d/apple-ib-als.conf` | `blacklist apple-ib-als`, written by the installer because the light-sensor module can fail to load. It loads fine with `modprobe`; remove this file to use the sensor. |
| `apple-touchbar.service` + `/usr/local/sbin/apple-touchbar-handover` | At boot, `hid-sensor-hub` grabs the Touch Bar's HID interface first. This moves it to `apple-ibridge-hid`, otherwise the bar stays dark while `lsmod` looks fine. |

> **Known issue in the handover script** (found here): it checks for a hard-coded `0003:05AC:8600.0001`, but after a T1 revive the devices are numbered `.0002`/`.0003`, so it exits "T1 not ready" and the bar stays dark. Fix in `/usr/local/sbin/apple-touchbar-handover`: replace `if [[ ! -e /sys/bus/hid/devices/0003:${VIDPID}.0001 ]]; then` with `if [[ ! -e $1 ]]; then`.

**Important for anyone coming from the keyd fallback:** the Touch Bar driver switches to F1–F12 when it sees the real **Fn** key. The fallback remaps Fn to Right Alt, so remove it; see [Moving from the keyd fallback](#moving-from-the-keyd-fallback-to-the-real-touch-bar).

## Step 4: Omarchy keyboard and touchpad settings

These make the keyboard and touchpad behave on Omarchy. They're useful with or without a working Touch Bar.

```bash
git clone https://github.com/seatrips/macbook-pro-t1-touchbar-linux.git ~/macbook-pro-t1-touchbar-linux && ~/macbook-pro-t1-touchbar-linux/install.sh
```

Update later with `cd ~/macbook-pro-t1-touchbar-linux && git pull && ./install.sh`. Every replaced file is backed up to `<file>.bak.<timestamp>`. **Log out and back in once** afterwards.

| File in this repo | Installed to | Purpose |
|---|---|---|
| [`config/hypr/macbook.lua`](config/hypr/macbook.lua) | `~/.config/hypr/` | `usmac` layout, **Compose key off** (Omarchy makes Caps Lock a Compose key; this gives you a normal Caps Lock), natural scrolling, 2-finger tap = right click, 3-finger tap = middle click, 4-finger swipe = switch workspace, tap-and-drag / drag lock / three-finger drag off (they started selections by themselves). `install.sh` adds `require("hypr.macbook")` to `input.lua`. |
| [`config/xkb/symbols/usmac`](config/xkb/symbols/usmac) | `~/.config/xkb/symbols/` | US layout plus § / ± on the extra ISO key. |
| [`etc/libinput/local-overrides.quirks`](etc/libinput/local-overrides.quirks) | `/etc/libinput/` | Fewer accidental taps: a contact must be bigger to count as a touch (`AttrTouchSizeRange=300:250`, default 150:130) and big contacts count as a palm sooner (`AttrPalmSizeThreshold=900`, default 1600). Raise the numbers if taps still happen by accident, lower them if real taps get missed. The second section only matters with the keyd fallback. |
| [`etc/modprobe.d/hid_apple.conf`](etc/modprobe.d/hid_apple.conf) | `/etc/modprobe.d/` | `fnmode=2`: F-keys first on *external* Apple keyboards. |

## What works now

| Hardware | Status | How |
|---|---|---|
| Touch Bar | ✅ | Esc, brightness, volume, media; **hold Fn = F1–F12**; dims after 5 minutes idle |
| Keyboard | ✅ | In-kernel `applespi`. **Fn + ↑/↓ = Page Up/Down, Fn + ←/→ = Home/End, Fn + Backspace = Delete** |
| Touchpad | ✅ | In-kernel `applespi` + Step 4 |
| FaceTime camera | ✅ | `uvcvideo` on the T1 (`/dev/video0`) |
| Wi-Fi (BCM43602) | ✅ | Needs the NVRAM file for good signal and 5 GHz; see [Wi-Fi fix](#optional-fix-weak-wi-fi-signal) |
| USB-C Ethernet adapter | ✅ | Out of the box (`cdc_ncm`, 1 Gbit/s) |
| Ambient light sensor | ✅ | `apple-ib-als` (`/sys/bus/iio/devices/iio:device0`), automatic brightness with wluma, see [below](#optional-ambient-light-sensor-and-automatic-brightness) |
| Touch ID | ❌ with this driver | ✅ with [t1bridge](https://github.com/standardagents/t1bridge) instead |

Check the Touch Bar stack at any time with `~/macbook-t1-touchbar/standalone/t1-touchbar.sh status`.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Touch Bar black, `lsusb` shows `05ac:1281` | The T1 has no firmware: [Step 2](#step-2-revive-the-t1-if-its-in-recovery-mode), or restore your backup with `t1-touchbar.sh restore-firmware`. |
| Touch Bar black, T1 is `05ac:8600`, `lsmod` shows `apple_ib_tb` | The HID interface is still held by `hid-sensor-hub`. `systemctl status apple-touchbar.service`; if it says "T1 not ready?", apply the [handover fix](#step-3-install-a-touch-bar-driver). |
| Holding Fn doesn't switch the bar to F1–F12 | Fn is still remapped: `cat /sys/module/applespi/parameters/fnremap` must print `0`. Remove the keyd fallback. |
| Everything stopped after a kernel update | DKMS didn't rebuild: `dkms status`, then `sudo dkms autoinstall` and reboot. |
| Two DKMS packages claim the same modules | Older AUR packages (`macbook12-spi-driver-dkms`) ship the same module names: `sudo ~/macbook-t1-touchbar/standalone/resolve-dkms-conflict.sh`. |
| Caps Lock gives `ﬀ`, `æ` or other odd characters | Compose is still on: check `require("hypr.macbook")` is in `~/.config/hypr/input.lua`, then `hyprctl reload`. |
| Touchpad clicks by accident / misses taps | Adjust `AttrTouchSizeRange` up / down, then log out and in. |

## Fallback: no Touch Bar? Keys on the keyboard instead

The real Touch Bar (Steps 1–3) is the recommended setup. This is for when you can't revive the T1, or you'd simply rather not have the Touch Bar: no firmware restore, no out-of-tree kernel driver, and every key under your fingers. Skip Steps 1–3, do Step 4, and put the missing keys on the physical keyboard with [keyd](https://github.com/rvaiya/keyd):

```bash
~/macbook-pro-t1-touchbar-linux/install.sh --keyd-fallback
```

| Keys | Does |
|---|---|
| Fn + 1 … 0, -, = | F1 … F12 |
| Fn + ↑ / ↓ | Volume |
| Fn + → / ← | Brightness |
| Fn + Backspace | Delete |
| Caps Lock + Tab | Esc |

How: `applespi fnremap=7` ([`fallback/etc/modprobe.d/applespi.conf`](fallback/etc/modprobe.d/applespi.conf)) makes Fn send Right Alt so it's visible at all, and keyd ([`fallback/etc/keyd/default.conf`](fallback/etc/keyd/default.conf)) turns that into a layer. Omarchy loads `applespi` from the initramfs, so the script rebuilds it (`limine-mkinitcpio`). Trade-offs: Right Option doubles as Fn, and there's no Page Up/Down/Home/End. The libinput quirks' second section is needed with this, because keyd re-sends keys from a virtual *USB* keyboard and libinput would otherwise not pause the touchpad while you type.

### Moving from the keyd fallback to the real Touch Bar

```bash
sudo rm /etc/modprobe.d/applespi.conf
echo 0 | sudo tee /sys/module/applespi/parameters/fnremap
sudo systemctl disable --now keyd
sudo limine-mkinitcpio          # or: sudo mkinitcpio -P
```

Fn is a real Fn key again: holding it switches the Touch Bar to F1–F12, and Right Option is a normal key.

## Uninstall

Step 4 settings:

```bash
sudo rm /etc/modprobe.d/hid_apple.conf /etc/libinput/local-overrides.quirks
rm ~/.config/hypr/macbook.lua ~/.config/xkb/symbols/usmac
sed -i '/hypr.macbook/d;/MacBook Pro Touch Bar keyboard/d' ~/.config/hypr/input.lua
```

The Touch Bar driver: `sudo systemctl disable apple-touchbar.service`, `sudo dkms remove appleibridge/0.1 --all`, remove the files listed in Step 3, rebuild the initramfs and reboot. The `*.bak.<timestamp>` files are the versions from before the first install.

## FAQ

**Does this need macOS?** No. t1-revive regenerates the T1 firmware from Linux. It does need Apple's signing servers once, which is why the off-disk backup (Step 1) matters: if Apple ever stops signing this firmware, a backup is the only way back.

**Does the T1 talk to Apple at every boot?** No. It boots from the files on the EFI partition, offline, about a second after power-on.

**Can I get Touch ID / the fingerprint reader?** Yes, but only with [t1bridge](https://github.com/standardagents/t1bridge), which replaces the driver used here. It provides `fprintd` support for sudo, polkit and the lock screen. The driver in Step 3 can't: it has no code for the T1's Secure Enclave.

**What about the ambient light sensor?** It sits on the same T1 interface as the Touch Bar, so once the handover moves that interface to `apple-ibridge`, the generic `hid-sensor-als` can't reach it and only `apple-ib-als` can. That module fails with `Unknown symbol iio_triggered_buffer_setup_ext` when loaded with `insmod`, because `industrialio-triggered-buffer` isn't loaded first; `modprobe` loads it automatically and it works. See [the light sensor section](#optional-ambient-light-sensor-and-automatic-brightness).

**Will an Omarchy update undo this?** No. The driver is DKMS (rebuilt for each kernel), the configs live in `/etc` and in your own `~/.config/hypr`.

**Why did my installer wipe the T1 firmware?** A "use the whole disk" install recreates the EFI partition, and `EFI/APPLE` goes with it. Next time, keep that folder (or install next to macOS) and Step 2 is never needed.

## Optional extras

These aren't needed for the Touch Bar, keyboard or touchpad, and `install.sh` doesn't do them.

### Optional: ambient light sensor and automatic brightness

The light sensor next to the camera is on the T1. Load its driver (tested on the 14,3: readings drop to 0 when you cover it):

```bash
sudo modprobe apple-ib-als
watch -n0.5 cat /sys/bus/iio/devices/iio:device0/in_illuminance_input    # lux
```

Keep it across reboots:

```bash
sudo rm /etc/modprobe.d/apple-ib-als.conf
echo apple-ib-als | sudo tee -a /etc/modules-load.d/apple-touchbar.conf
sudo limine-mkinitcpio          # or: sudo mkinitcpio -P
```

For automatic brightness, [wluma](https://github.com/max-baz/wluma) reads the sensor and learns: change the brightness with the Touch Bar and it remembers that level for that amount of light. It also dims the keyboard backlight.

```bash
yay -S wluma
mkdir -p ~/.config/wluma && cp extras/wluma/config.toml ~/.config/wluma/
install -Dm755 extras/auto-brightness ~/.local/bin/auto-brightness
auto-brightness on
```

[`extras/wluma/config.toml`](extras/wluma/config.toml) sets `capturer = "none"`, so brightness follows the light sensor only. With screen capture on, wluma found no working capture protocol on this dual-GPU MacBook and exited every few seconds. It also turns off wluma's idle dimming, because Omarchy already handles idle.

[`extras/auto-brightness`](extras/auto-brightness) turns it `on`, `off`, `toggle` (default) or shows the `status`, with a notification. The choice survives reboots. To put it on a key, add this to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + ALT + B", "Toggle auto brightness", os.getenv("HOME") .. "/.local/bin/auto-brightness")
```

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

**The real fix: add the missing NVRAM file.** Linux ships the firmware for this chip but no board calibration file (`brcmfmac43602-pcie.txt`). Without it the chip runs uncalibrated: weak signal, 2.4 GHz only, and the Broadcom placeholder MAC `00:90:4c:0d:f4:3e` (check with `ip link show wlp3s0`, look for `permaddr`). [`firmware/brcmfmac43602-pcie.txt`](firmware/brcmfmac43602-pcie.txt) is an NVRAM dump from a 15" MacBook Pro, taken from [nohzafk/omarchy-macbookpro-t1](https://github.com/nohzafk/omarchy-macbookpro-t1) (originally a gist by MikeRatcliffe). Its `macaddr=` line is set to `02:90:4c:0d:f4:3e`, a locally administered address, because the real Apple MAC isn't known.

```bash
sudo install -o root -g root -m 644 firmware/brcmfmac43602-pcie.txt /lib/firmware/brcm/
```

Reboot (reloading the driver also works, but drops Wi-Fi, so have a cable handy). Then `iw phy | grep Band` should list `Band 2` (5 GHz) as well as `Band 1`. On the 14,3, in the same spot:

| | Before (no NVRAM, txpower cap on) | After NVRAM file |
|---|---|---|
| Band | 2.4 GHz only | 2.4 + 5 GHz (connected on ch 64, 40 MHz) |
| Signal | -84 dBm | -68 dBm |
| Download (rx) | 1 Mbit/s | 108 Mbit/s |
| Upload (tx) | 24 Mbit/s | 162 Mbit/s |
| Networks visible | 6 | 19 |

To undo: `sudo rm /lib/firmware/brcm/brcmfmac43602-pcie.txt` and reboot. The file isn't owned by any package, so updates won't overwrite or remove it.

**The transmit power cap is optional once the NVRAM file is in.** The NVRAM file doesn't change the transmit power (without the cap the chip still reports 31 dBm), but on the 14,3 it no longer makes a measurable difference. A real speed test (curl against speed.cloudflare.com, 3 × 50 MB down and 3 × 20 MB up each way, same spot, 5 GHz ch 64, -62 dBm both times):

| | Cap on (10 dBm) | Cap off (31 dBm) |
|---|---|---|
| Download | 140–165, avg 153 Mbit/s | 128–147, avg 136 Mbit/s |
| Upload | 97–153, avg 120 Mbit/s | 132–141, avg 136 Mbit/s |

The spread within each set is bigger than the gap between them, so it's noise. The cap is kept on here anyway: it costs nothing and may still help at the edge of range, which wasn't tested.

To turn the cap off without deleting the script: `sudo chmod -x /etc/NetworkManager/dispatcher.d/90-wifi-txpower && sudo iw dev wlp3s0 set txpower auto`. To turn it back on: `sudo chmod +x /etc/NetworkManager/dispatcher.d/90-wifi-txpower && sudo iw dev wlp3s0 set txpower fixed 1000`. Neither drops the connection.

**Background: why the cap was added.** Before the NVRAM file was found, this was the workaround. The Linux firmware for this chip is from 2015 and can't detect the country it's in. It then transmits at a bogus **31 dBm**, which also drowns out its own receiver: the signal shows around -93 dBm even with a phone hotspot right next to the laptop, and speeds drop to a few Mbit/s ([kernel bug 193121](https://bugzilla.kernel.org/show_bug.cgi?id=193121)). Capping transmit power at 10 dBm fixes most of it. On the 14,3 this setup was written on:

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

Reboot once to confirm it sticks (tested on the 14,3: after a reboot the cap was applied without doing anything). Then check with `iw dev wlp3s0 info | grep txpower`, which should say `10.00 dBm`. If it still says `31.00 dBm`, the interface name in the script doesn't match yours, or the file isn't executable and owned by root (NetworkManager skips it otherwise). To undo: `sudo rm /etc/NetworkManager/dispatcher.d/90-wifi-txpower`. On its own the cap leaves Wi-Fi on 2.4 GHz only; the NVRAM file above fixes that.

### Optional: Security Watch (firewall and daily security checks)

This isn't specific to MacBooks, and `install.sh` doesn't do it. It's for when you use the laptop for work or private things and want to hear about problems without checking yourself. It sets up:

- **[OpenSnitch](https://github.com/evilsocket/opensnitch)**, an application firewall. The first time a program connects to the internet, a popup asks whether to allow it. Three rules come preinstalled so the basics work without popups: local DNS, the system resolver (`systemd-resolved`) and clock sync (`systemd-timesyncd`).
- **Security Watch**, a script that a systemd timer runs once a day (and catches up after the laptop was off). It sends a desktop notification **only for new findings**, so it stays quiet until something needs doing:
  - `arch-audit --upgradable`: installed packages with known vulnerabilities that an update fixes. Run `omarchy update`.
  - `rkhunter`: rootkits and system files that were swapped out. A pacman hook refreshes its baseline after every update, so updates don't cause alerts.
  - `lynis`: a system hardening audit, on Sundays.

Install it with:

```bash
cd ~/macbook-pro-t1-touchbar-linux && ./security/install.sh
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


## Credits

- **Ronald Tschalär** ([roadrunner2/macbook12-spi-driver](https://github.com/roadrunner2/macbook12-spi-driver)): the `apple-ibridge` / `apple-ib-tb` / `apple-ib-als` drivers, and `applespi`, now in the mainline kernel.
- **[niconistal/t1-revive](https://github.com/niconistal/t1-revive)**: reviving a T1 in recovery mode from Linux, without macOS.
- **[creolben/macbook-t1-touchbar](https://github.com/creolben/macbook-t1-touchbar)**: the patched driver build, DKMS setup, boot-time interface handover, firmware backup and diagnostics.
- **[standardagents/t1bridge](https://github.com/standardagents/t1bridge)**: the full T1 stack with Touch ID.
- **[rvaiya/keyd](https://github.com/rvaiya/keyd)**: the key remapper behind the fallback.

Found a mistake or got it working on another model? Open an issue.
