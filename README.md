# Arch Linux App & System Analyzer 🚀

A lightweight, terminal-based Bash utility designed for Arch Linux and Arch-based distributions (Manjaro, EndeavourOS, Garuda, etc.) to inspect installed applications, system resource usage, and boot performance.

![Version](https://img.shields.io/badge/version-1.0-blue.svg)
![OS](https://img.shields.io/badge/OS-Arch%20Linux-archlinux.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

---

## ⚡ Features

1. **System Information:** Comprehensive breakdown of OS, kernel, desktop environment, CPU, GPU, RAM, Swap, disk usage, and package counts.
2. **Pacman Package Analyzer:** List all native packages sorted either alphabetically or by actual installed size (largest to smallest) with binary paths.
3. **Flatpak Inspector:** View installed Flatpak applications, IDs, disk usage, and installation paths.
4. **AppImage Finder:** Scan common directories (`~`, `/opt`, `/usr/local/bin`) for executable `.AppImage` files.
5. **Unused App Detector:** Identify rarely used applications based on executable access timestamps (`atime`/`mtime`).
6. **Live RAM Monitor:** Aggregate active process memory consumption sorted by total RAM usage (MB and % share).
7. **Boot Time & Service Analyzer:** Analyze total startup duration and identify slow systemd services delaying boot (`systemd-analyze blame`).

---

## 🛠️ Prerequisites

Most utilities come pre-installed on Arch Linux. Make sure you have `pciutils` installed for GPU detection:

```bash
sudo pacman -S pciutils
