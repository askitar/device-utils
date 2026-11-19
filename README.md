# Device Utils

Small, practical scripts I wrote (with Claude Code) to diagnose and tune my own devices: an Android phone over `adb` and a Windows PC. Everything is designed to be **measurable and reversible**: measure first, change one thing at a time, keep a log, and ship a script that undoes it.

## Android diagnostics (`android-diagnostics/`)

### Case study: camera lag on a Galaxy S22+

The camera lagged after a minute of recording at 3x zoom. Instead of guessing, I collected evidence over `adb` in phases:

1. **Baseline**: battery health, thermal status, memory, idle CPU, camera cold-start time and frame stats.
2. **Hypotheses, tested one by one**: keyboard memory use, apps waking the phone, background apps, charging while recording, 60 Hz vs 120 Hz. All ruled out with data.
3. **Root cause**: the Snapdragon 8 Gen 1 heats from about 32 °C to 58 °C in 60 to 90 seconds of camera use, and the thermal manager throttles CPU and GPU right when the lag starts. A hardware trait, not a setting.
4. **Reversible changes** that still helped: adaptive 120 Hz, freezing two apps that used CPU constantly, faster animations, RAM Plus off.

| Measure | Before | After |
|---|---|---|
| Camera cold start | 375 to 543 ms | 253 to 333 ms (about 35% faster) |
| Free RAM at idle | 2.4 GB | 3.1 to 3.2 GB |
| Swap in use | 3.5 GB | 1.6 GB |
| Constant CPU from one background app | 18 to 21% | 0 |

Honest result: everyday smoothness and camera start improved; heat-related lag in long recordings could not be fixed, because the cause is the chip.

### Scripts

- **`diagnose.ps1`**: read-only snapshot over `adb`. Device info (no serial, IMEI or accounts), battery, thermal status, memory, idle CPU, display settings, disabled packages, camera cold-start runs and camera frame stats after a guided 60 s test. Saves everything to a timestamped folder plus a `SUMMARY.txt` to compare *before* vs *after*.

  ```powershell
  powershell -ExecutionPolicy Bypass -File android-diagnostics\diagnose.ps1 -Label before
  powershell -ExecutionPolicy Bypass -File android-diagnostics\diagnose.ps1 -Label after
  ```

- **`revert-example.bat`**: the undo script from the case study. Re-enables the frozen apps, restores animation scales and the refresh rate, and prints a verification. Use it as a template: every change you make should have a matching line here.

Requirements: Android platform-tools (`winget install Google.PlatformTools`) and USB debugging enabled on the phone.

## Windows maintenance (`windows-maintenance/`)

PowerShell scripts for a cluttered Windows PC. **Read each script before running it**, and run the admin ones from an elevated PowerShell.

| Script | What it does |
|---|---|
| `organizar.ps1` | Sorts loose files in Downloads, Videos, Desktop and Pictures into folders by type (images, videos, documents, installers, archives) and writes a CSV log of every move. |
| `DESHACER-organizacion.ps1` | Reads that CSV and moves every file back to where it was. |
| `dedup.ps1` | Finds duplicate files by size and MD5 content hash and **permanently deletes** the extra copies (no Recycle Bin), logging each one to a CSV. Back up first. |
| `optimizar-admin.ps1` | Ultimate Performance power plan, turns off Windows telemetry (DiagTrack and CEIP tasks), clears Delivery Optimization and Windows Update caches and old system logs, and runs a DISM component-store cleanup, logging the free space recovered. |
| `cleanup-admin.ps1` | Removes specific unwanted startup entries and uninstalls known bloatware silently, with a log. |

The folder paths and the lists of startup entries and programs are the ones from my machine; edit them before using the scripts on yours.

## License

[MIT](LICENSE)
