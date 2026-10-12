# iPhone + Android apps from Windows, no Mac

Build, sign and install iPhone apps from a Windows PC, plus Android from the same
Flutter codebase. Uses [xtool](https://github.com/xtool-org/xtool) inside WSL2 for
iOS and Joshua Warren's [omarchy-apple-dev](https://github.com/joshuaswarren/omarchy-apple-dev)
kit for Flutter-on-iOS. Works with a free Apple ID.

Written for both humans and coding agents (Claude Code reads `CLAUDE.md`, Codex reads
`AGENTS.md`; both point here). If a `LOCAL.md` exists next to this file, it describes
the specific machine and wins over anything generic below.

Verified 2026-10-11 on Windows 11 25H2, WSL2 Ubuntu 26.04, Swift 6.4, xtool 1.21,
Xcode 27, Flutter 3.47.6.

## Setup from scratch

1. **Turn on virtualization** in the BIOS (Intel VT-x / AMD SVM). Check in Task
   Manager > Performance > CPU: "Virtualization: Enabled".
2. **WSL + Ubuntu** (admin PowerShell, reboot after the first line):
   ```
   wsl --install --no-distribution
   wsl --install -d Ubuntu
   ```
   If C: is small, move the distro: `wsl --shutdown; wsl --manage Ubuntu --move E:\WSL\Ubuntu`.
3. **Cap WSL memory** on low-RAM machines. `%USERPROFILE%\.wslconfig`:
   ```
   [wsl2]
   memory=6GB
   swap=8GB
   swapFile=E:\\WSL\\swap.vhdx
   ```
4. **Toolchain in Ubuntu** (Swift 6.4, xtool, usbmuxd, libimobiledevice):
   `bash scripts/setup-wsl.sh`
5. **USB passthrough on Windows:** `winget install dorssel.usbipd-win`
6. **Xcode .xip** (needed only for the iOS SDK inside it): sign in at
   developer.apple.com and download
   `https://download.developer.apple.com/Developer_Tools/Xcode_27/Xcode_27.xip`
   from any browser. Save it outside C: if C: is tight.
7. **Apple sign-in + SDK**, in Ubuntu (interactive; Apple may send a 2FA code):
   ```
   xtool auth login -m password -u you@example.com
   xtool sdk install /mnt/e/Xcode_27.xip
   ```
   Use a spare Apple ID: password mode uses Apple's private sign-in APIs.
   `scripts/xtool-login.sh <id> <password>` does the same non-interactively and
   reads the 2FA code from `/tmp/xin` (`echo 123456 > /tmp/xin`).
8. **Flutter (optional, both platforms):**
   - Android, Windows: `powershell -File scripts\flutter-windows.ps1` (Flutter to
     `E:\flutter`; needs an Android SDK, e.g. from Android Studio).
   - iPhone, Ubuntu: `bash scripts/flutter-wsl.sh` (Flutter in `~/flutter`, then
     builds a Linux-hosted iOS compiler: ~7 GB download, long compile, lots of RAM).

## Running commands from Windows

```
wsl -d Ubuntu -- bash -lic "cd ~/apps/MyApp && xtool dev build"
```

PowerShell mangles `$`, backticks and nested quotes on the way to bash. For
anything non-trivial, write a `.sh` file and run `wsl -d Ubuntu -- bash /mnt/e/path/script.sh`.
"Failed to translate 'D:\...'" warnings are harmless.

**Keep projects inside WSL (`~/apps/<Name>`), not under `/mnt/c` or `/mnt/e`.**
Builds over `/mnt` are many times slower.

### When WSL breaks

| Symptom | Fix |
|---|---|
| `HCS_E_CONNECTION_TIMEOUT`, `E_UNEXPECTED` | `wsl --shutdown`, retry. Usually starts on the second try. |
| `Failed to attach disk ... Access is denied`, or `wsl` hangs | admin PowerShell: `wsl --shutdown; Restart-Service vmcompute -Force; Restart-Service WSLService -Force` |
| `Bus error` / `Input/output error` inside Ubuntu | the drive holding `ext4.vhdx` is full. Free space or move the distro. |

## Route 1: native iPhone app (SwiftUI + xtool)

```
cd ~/apps
xtool new MyApp --skip-setup      # Package.swift, xtool.yml, Sources/MyApp/
cd MyApp
# write SwiftUI in Sources/MyApp/
xtool dev build                   # unsigned xtool/MyApp.app, no phone needed
xtool dev                         # build, sign, install and launch on the iPhone
```

Porting an existing app: read its screens and logic, rewrite the UI in SwiftUI
under `Sources/<Name>/`. Bundle id and name live in `xtool.yml`, packages in
`Package.swift`. No storyboards, no .xcodeproj.

## Connecting the iPhone

Plug in by USB, unlock, tap **Trust**. Then in an **admin** PowerShell:

```
usbipd list                                  # Apple row has VID 05ac; note its BUSID
usbipd bind --busid <BUSID>                  # once per device
usbipd attach --wsl --busid <BUSID>          # every time it is plugged in
```

Check from Ubuntu with `xtool devices` or `ideviceinfo`. On
`AFCClient.Error.muxError`, see xtool issue #19 (comment by rena2019).

First install only, on the phone:
1. Settings > Privacy & Security > Developer Mode > On (phone restarts).
2. Settings > General > VPN & Device Management > trust your Apple ID.

Free Apple ID limits: apps expire after 7 days (re-run `xtool dev`), 3 apps
installed at once, 10 app ids per week.

## Route 2: Flutter (one codebase, iPhone + Android)

1. **Android, on Windows:** with `E:\flutter\bin` on PATH and the phone plugged in
   with USB debugging: `flutter run --release`, or `flutter build apk` then
   `adb install build\app\outputs\flutter-apk\app-release.apk`.
2. **iPhone, in Ubuntu:** after `scripts/flutter-wsl.sh` ends with `ALL DONE`
   (log `~/flutter-setup.log`):
   ```
   ~/omarchy-apple-dev/flutter/build.sh --install ~/apps/my_flutter_app   # build, sign, install
   ~/omarchy-apple-dev/flutter/build.sh ~/apps/my_flutter_app             # Runner.ipa only
   ```
   Release builds only: no hot reload, no iOS simulator. Plugins must ship a
   `Package.swift`. A Flutter upgrade in Ubuntu undoes the iOS compiler; rerun
   `~/omarchy-apple-dev/flutter/setup.sh`. The kit targets Arch Linux, so
   translate any `pacman` line to apt.

Simplest layout: one copy of the app in Ubuntu. Build Android from Windows
against `\\wsl$\Ubuntu\home\<user>\apps\...`, or keep two copies in sync.

## App Store / TestFlight

Needs a paid Apple Developer account and an App Store Connect API key. See
`ship.sh` and `GETTING-STARTED.md` in omarchy-apple-dev.

## Extras

- `scripts/fix-pagefile.ps1` (admin): moves the Windows paging file off a full C:
  to the internal drive with the most space, sized 1.5x/3x RAM.

## Rules for agents

- Never type, store or log an Apple ID password. If login has expired, ask the
  user to run `xtool auth login` themselves in Ubuntu.
- Physical steps (plugging in, Trust, Developer Mode) are the user's. Say exactly
  what to tap, then continue.
- RAM is usually tight. Don't run two Swift or Flutter builds at once.
- Don't change `.wslconfig`, the WSL disk location or the paging file without asking.

## Credits

[xtool](https://github.com/xtool-org/xtool) by Kabir Oberai and contributors.
[omarchy-apple-dev](https://github.com/joshuaswarren/omarchy-apple-dev) by Joshua
Warren, Flutter pipeline by dl-alexandre.
