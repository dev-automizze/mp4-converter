# Convertze Automizze Studio (v1.0)

A lightweight, bulletproof PowerShell automation tool designed to batch-convert `.ts` video files into highly compressed `.mp4` files using Nvidia NVENC hardware acceleration. Built to reclaim hard drive space without sacrificing video quality.

## ✨ Key Features

* **Hardware Accelerated (RTX Optimized):** Utilizes FFmpeg's `hevc_nvenc` codec with the `p5` preset for the perfect balance of blazing-fast conversion speeds and high visual quality.
* **Zero-Admin Auto-Installer:** Includes a built-in FFmpeg downloader. It automatically fetches, extracts, and wires FFmpeg into the user's local Windows environment (`AppData`)—no Administrator privileges required.
* **Natural Sorting Engine:** Processes files exactly how a human reads them (e.g., `Episode 1`, `Episode 2`, `Episode 10`) rather than raw alphabetical order.
* **GUI Folder Picker:** Replaces clunky path-pasting with a native Windows folder selection popup.
* **Bulletproof Manual Presets:** Avoids the dangers of automated bitrate guessing by offering explicit, safe profiles (1080p Balanced / 720p Compact) to guarantee original video quality is protected.
* **Smart Auto-Cleanup:** Optional feature to automatically delete the bulky `.ts` source files only *after* confirming the `.mp4` conversion was successful and saved space.

## 🚀 How to Run

1. Open **PowerShell** on your Windows machine.
2. Run the script via your custom shortcut:
   ```powershell
   irm convertze.automizze.us | iex
