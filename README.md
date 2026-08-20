# PocketTerm35 Pi OS Image

[![Build Images](https://github.com/scillidan/pocketterm35-pi-img/actions/workflows/build.yml/badge.svg)](https://github.com/scillidan/pocketterm35-pi-img/actions/workflows/build.yml)

Authors: DeepSeek-V4🧙‍♂️, Kimi-K2.7-Code🧙‍♂️, scillidan🤡

Raspberry Pi OS 64-bit Desktop / Lite images for the PocketTerm35 handheld, built by GitHub Actions. A single universal image works on both Pi 4 and Pi 5 — the matching Waveshare 3.5" display overlay is baked into the boot partition via `[pi4]` / `[pi5]` config filters. The OS codename is derived from the image URL, so Bookworm and Trixie builds name themselves correctly.

## Build

Manual-only workflow (`workflow_dispatch`) in the **Actions** tab. Inputs:

| Input | Description |
| :- | :- |
| `build_desktop` / `build_lite` | Toggle each edition (both on by default). |
| `desktop_url` / `lite_url` | Image URL (`.img.xz`). Skip an edition with the `build_*` toggles — a blank URL falls back to the default. Defaults point at Trixie images. |
| `shrink_image` | Shrink the image to minimum size (default off). |
| `release_tag` | Override the release tag (default: derived from the image date). |
| `create_release` | Publish a GitHub release with the images (default on). |
| `dry_run` | Build but skip upload and release (default off). |

## Flash

Download the `.img.xz` from the release. Flash it directly with Raspberry Pi Imager, or decompress it first and write the raw `.img` with `dd`.

Lite images have no first-boot wizard, so you must create a user while flashing (Imager advanced options or a `userconf.txt` file), otherwise the first-boot service aborts.

## First boot

The display config is baked into the boot partition at build time (DTBOs in `overlays/`, plus a `config.txt` block using `[pi4]` / `[pi5]` conditional filters to pick `waveshare-35dpi-4b` / `waveshare-35dpi-5b`), so the 3.5" screen works from the very first power-on — you can verify it from a PC by reading `config.txt` on the BOOT drive before even booting the Pi.

On first boot a oneshot service expands the root filesystem, adds the primary user to hardware groups, then reboots. It also re-applies the display overlay as a fallback, skipping it when the baked config is already present.

## Debugging

A `pocketterm35-debug` service runs on every boot and appends diagnostics (board model, `config.txt`, input devices, USB, loaded modules, filtered `dmesg`, first-boot service log) to `pocketterm35-debug.txt` on the FAT boot partition. If the display/keyboard/touch does not work, shut the Pi down, plug the SD card into any PC, and read that file directly from the BOOT drive — no SSH or monitor needed. The script also logs a one-line summary to the journal (`journalctl -u pocketterm35-debug`). The build workflow prints the baked image contents (config.txt, overlays, input-related packages) in the "Debug: inspect baked image contents" step of each build log.