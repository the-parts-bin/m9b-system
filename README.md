# m9b: a RISC-V computer on the Tang Nano 9K

m9b is a small computer built in the FPGA of Sipeed's Tang Nano 9K (a Gowin
GW1NR-9): a VexiiRiscv CPU at 36 MHz with caches, the board's 8 MB of
on-package PSRAM, 720×480 HDMI video and 48 kHz audio, two USB ports for
keyboards and mice, and the SD card slot. It boots into a screen that lists
the programs on the SD card, and it runs five DOS-era games, ported to it
(Ultima VII on two engines):

| Game | Port of | Speed on the board |
|---|---|---|
| [Doom](doom/) (shareware) | [doomgeneric](https://github.com/ozkl/doomgeneric) | about 22 fps in the timedemo |
| [Descent](descent/) (shareware) | [D1X Rebirth](https://github.com/dxx-rebirth/dxx-rebirth) 0.40 | about 10 fps |
| [Tyrian 2.1](tyrian/) | [OpenTyrian](https://github.com/opentyrian/opentyrian) | full speed (35 fps) |
| [System Shock](sshock/) | [Shockolate](https://github.com/Interrupt/systemshock) | about 7 fps |
| [Ultima VII](exult/): The Black Gate, Serpent Isle | [Exult](https://github.com/exult/exult) 1.12.1 | 7–13 fps |
| [Ultima VII](u7/): The Black Gate, Serpent Isle | the original engine, decompiled ([Ultima7_Decomp](https://github.com/Kitrinx/Ultima7_Decomp)) | 8–10 fps (the engine's own limit is 10) |

All have sound effects and music; Ultima VII's (both engines) come from Exult's
Roland MT-32 recordings (without them, it has The Black Gate's AdLib music
and no sound effects). The music is rendered or converted on the PC ahead
of time and streamed from the card.

## Repositories

This repository ties the parts together: each is a repository of its own,
included here as a git submodule, so clone with `--recursive` (or run
`git submodule update --init` afterwards; `make` does that too).

| Directory | Repository | Contents |
|---|---|---|
| [`core/`](core/) | m9b-core | the SoC: RTL, boot firmware, the runtime the programs link with (`runtime/`), simulations, and tools for loading programs over the serial port. Its README is the hardware reference (memory map, registers, clocks, timing). On its own it is enough for the boot screen. |
| [`doom/`](doom/), [`descent/`](descent/), [`tyrian/`](tyrian/), [`sshock/`](sshock/), [`exult/`](exult/) | m9b-doom, m9b-descent, m9b-tyrian, m9b-sshock, m9b-exult | the game ports (`exult/`: Ultima VII on Exult): the upstream source (trimmed, with changes marked `M9B`), the platform layer in `port/`, scripts for the game data and music in `tools/`, and `data/`, where the game's own files go (`data/README.md` in each). They build against `../core` (`make CORE=...` for a core elsewhere). |
| [`u7/`](u7/) | m9b-u7 | Ultima VII's original engine: the platform layer in `port/`, the changes to the decompilation in `patches/` (the decompilation itself is fetched, not included). It uses the Ultima VII data from `exult/`. |
| [`sdcard/`](sdcard/) | (here) | builds the SD card from the game data you provide |

Each README has the same layout: what the part is and its status, a
**Sources** table (the upstream projects it is built from or uses, with
the versions), how to build it, how it works, and **Changes to ...**: what
was changed in the upstream code (marked `M9B` there). The SoC's parts
from elsewhere (VexiiRiscv, the HDMI and USB host cores, FatFs) are in
`core/README.md`, Sources.

No game data is in any of them. Each game's `data/README.md` says which
version of the game is needed and what goes there; `sdcard/README.md` has
the overview.

## What you need

- A **Tang Nano 9K**, an HDMI display, and a microSD card (1 GB or more).
- **USB keyboard and mouse:** two USB-A sockets wired to header J5, with
  15 kΩ pull-downs on D+ and D− (`core/README.md`, USB host). The serial
  console also works as a keyboard for the menus.
- Optionally a **3.3 V USB-serial adapter** on J5, for fast program uploads
  (`core/README.md`, Serial loader). The board's own USB serial port works too,
  more slowly.

Software, on Debian or Ubuntu:

```
sudo apt install make git gcc-riscv64-unknown-elf picolibc-riscv64-unknown-elf \
    libstdc++-riscv64-unknown-elf-picolibc python3 openfpgaloader \
    curl unzip 7zip cmake g++ ffmpeg mtools dosfstools fdisk
```

(The second line is for the SD card: downloads, music rendering and the
disk image. `7zip` is `p7zip-full` on older releases.)

The FPGA bitstream is built with the **Gowin IDE**: Gowin EDA V1.9.11.03
Education, a free download from Gowin. Set `GOWIN_HOME` to the directory
that holds its `bin/gw_sh` (default `~/gowin/IDE`). The SD card needs a few
more tools (see `sdcard/README.md`). The simulations need Icarus Verilog,
and the System Shock and Ultima VII host test harnesses need
`gcc-multilib g++-multilib`.

## From scratch to a working card

```
git clone --recursive https://github.com/the-parts-bin/m9b-system.git
cd m9b-system
```

Put the game data in place: each game's `data/README.md` says what goes
there (symbolic links work). Descent and Tyrian need nothing: they are
downloaded. For example:

```
cp ~/Downloads/doom19s.zip doom/data/
ln -s ~/.local/share/Steam/steamapps/common/SS1/SSHOCK sshock/data/SSHOCK
ln -s path/to/ULTIMA7 exult/data/ULTIMA7          # The Black Gate
ln -s path/to/SERPENT exult/data/SERPENT          # Serpent Isle
ln -s path/to/exult-audio exult/data/exult-audio  # Exult's MT-32 packs (optional)
```

Then

```
make sdcard
```

builds the ports, collects the data, renders the music, and writes
`sdcard/out/m9b-sd.img` (and the card's files in `sdcard/out/card/`). It
checks for the tools it needs first, and leaves out a game whose data
isn't there. Write the image to the card (`dd` replaces everything on it:
check the device name with `lsblk`):

```
sudo dd if=sdcard/out/m9b-sd.img of=/dev/sdX bs=4M conv=fsync status=progress
```

The board needs the bitstream and the firmware in its flash once:

```
make bitstream        # the FPGA bitstream (Gowin IDE)
make flash            # bitstream + firmware into the board's flash (openFPGALoader)
```

Insert the card and power the board on: the boot screen runs its
self-tests and lists the programs. Pick one with the arrow keys and Enter.

## Building

```
make                  # firmware, the five game ports, the board tools (u7/: make sdcard)
make bitstream        # the FPGA bitstream (Gowin IDE)
make flash            # bitstream + firmware into the board's flash (openFPGALoader)
make sdcard           # the SD card (sdcard/README.md; SDCARD="--doom ..." for data elsewhere)
```

During development, `core/tools/run.py PROGRAM.bin` uploads a program over
the serial port and runs it without touching the card, and `make sync`
brings the card in the board up to date with `sdcard/out/card/` through the
serial port, sending only what changed (`core/tools/sdput/sdput.py`).
`core/README.md` covers both. Each game's README covers its build options,
how it was made to fit, and its changes to the upstream code.

The bitstream is close to full (about 88% of the logic, 25 of 26 block
RAMs) with little timing margin: check the timing summary after a build
(`core/README.md`, Clocks).

## Licenses

Each repository has its own license; this one (the SD card scripts and the
top-level files) is under the Apache License 2.0 (`LICENSE`).

| Part | License |
|---|---|
| `core/` | Apache 2.0, with third-party parts under MIT, BSD-style and CC0 licenses (`core/README.md`, License) |
| `doom/` | GPL v2 (`doom/doomgeneric/LICENSE`) |
| `descent/` | the Parallax license, non-commercial use only (`descent/d1x/license.txt`) |
| `tyrian/` | GPL v2 (`tyrian/opentyrian/COPYING`) |
| `sshock/` | GPL v3 (`sshock/shockolate/LICENSE`) |
| `exult/` | GPL v2 (`exult/exult/COPYING`); `exult/port/SDL2/` zlib; `exult/port/dlmalloc/` MIT-0 |
| `u7/` | the platform layer and tools: Apache 2.0 (`u7/LICENSE`); the decompiled games are not in the repository (`u7/tools/get_source.sh` fetches them), and `u7/patches/` holds only the changes to them |
| `sdcard/`, the top-level files | Apache 2.0 (`LICENSE`) |

The game ports keep their upstream licenses, which also cover the
platform code added in each (`port/`, `tools/`). The game data isn't
covered by any of these, and none of it is included.
