# The m9b SD card

The m9b loads its programs from the SD card: the boot screen lists the
`.BIN` files in the card's root, and each game reads its data from its own
directory. `make_sdcard.sh` builds the whole card from the game data you
provide: the game ports (Ultima VII on both engines), their data, and
their music, which is rendered on the PC (the ports stream it, since none
of the original synthesizers fits the CPU).

No game data is in the repositories. Doom, Descent and Tyrian are freely
distributable shareware or freeware, and System Shock and Ultima VII are
commercial games that you need to own.

## Quick start

Put each game's data in its `data/` directory (each has a `README.md`
saying what goes there; symbolic links work):

```
cp ~/Downloads/doom19s.zip doom/data/
ln -s ~/.local/share/Steam/steamapps/common/SS1/SSHOCK sshock/data/SSHOCK
ln -s path/to/ULTIMA7 exult/data/ULTIMA7
ln -s path/to/SERPENT exult/data/SERPENT
ln -s path/to/exult-audio exult/data/exult-audio
make sdcard           # or sdcard/make_sdcard.sh [options]
sudo dd if=sdcard/out/m9b-sd.img of=/dev/sdX bs=4M conv=fsync status=progress
```

Descent and Tyrian are downloaded into their `data/` when it's empty. A
game whose data isn't there is left out, so with no data at all the card
has just those two. The options below take a game's data from elsewhere
instead (`make sdcard SDCARD="--doom ..."`).

The script builds each port, collects the data, renders the music and
writes:

- `sdcard/out/card/`: the card's files. Copy them onto any FAT32 or exFAT
  card (`cp -r sdcard/out/card/. /media/$USER/CARD/`) instead of writing the
  image, if you prefer.
- `sdcard/out/m9b-sd.img`: a disk image with one FAT32 partition holding
  those files, sized to fit (about 830 MB with all the games), for a card of
  1 GB or more. `dd` replaces everything on the card; check the device name
  (`lsblk`) first.

With all five games the card holds 902 files, 705 MB. On a 32-thread PC the
whole run took 3.5 minutes, downloads and music included. Downloads, game
data stay in the games' `data/` directories and the music in
`sdcard/out/music/`, and the next run reuses them; delete
`sdcard/out/music/GAME/` to render a game's music again.

## The game data

The ports were tested with exactly these versions. The script checks the
files below and warns if they differ; other versions may work, but haven't
been tried.

The default place for each is in the game's `data/` (the `data/README.md`
there has the same details):

| Game | Default | Option | What to give | Tested version: file, size, MD5 |
|---|---|---|---|---|
| Doom | `doom/data/DOOM1.WAD` or `doom/data/doom19s.zip` | `--doom` | id Software's shareware distribution `doom19s.zip`, the directory it unpacks to, or the `DOOM1.WAD` from it | shareware 1.9: `DOOM1.WAD`, 4,196,020 bytes, `f0cefca49926d00903cf57551d901abe` |
| Descent | `descent/data/` | `--descent` (optional) | a directory holding `descent.hog` and `descent.pig`. When `descent/data/` doesn't have them, they are downloaded there (`desc14sw.zip` from classicdosgames.com) and unpacked by `descent/tools/get_data.sh` | shareware 1.4: `descent.hog`, 2,339,773 bytes, `cf1caf9c7a0681de80fac8cb593b33eb`; `descent.pig`, 5,092,871 bytes, `f8dc0f2b3ee8baa2c622f57b470fe147` |
| Tyrian | `tyrian/data/` | `--tyrian` (optional) | a directory holding the game's files. When `tyrian/data/` doesn't have them, they are downloaded there (`tyrian21.zip` from camanis.net, the mirror OpenTyrian names) by `tyrian/opentyrian/get_data.sh` | freeware Tyrian 2.1: `tyrian1.lvl`, 538,262 bytes, `a1e73e0586ce715ab7daaedfe9b98595` |
| System Shock | `sshock/data/SSHOCK/` | `--shock` | the `SSHOCK` directory of the DOS CD version, which holds `DATA/` and `SOUND/`. Steam's *System Shock: Classic* installs it as `steamapps/common/SS1/SSHOCK` | CD version, as installed by Steam: `DATA/CITMAT.RES`, 105,834 bytes, `e8727598d54c360eff5916b9b1570082`; `DATA/ARCHIVE.DAT`, 613,566 bytes, `d290ef2e3c4fe605473d7cf0b65a96dc` |
| Ultima VII: The Black Gate | `exult/data/ULTIMA7/` | `--u7-bg` | the DOS game's install directory, which holds `STATIC/` (e.g. `ULTIMA7`) | DOS, with The Forge of Virtue: `STATIC/USECODE`, 1,521,368 bytes, `07ea98fe080ea7dc720492856ebf0fb8` |
| Ultima VII Part Two: Serpent Isle | `exult/data/SERPENT/` | `--u7-si` | the DOS game's install directory, which holds `STATIC/` (e.g. `SERPENT`) | DOS, with The Silver Seed: `STATIC/USECODE`, 2,103,075 bytes, `3a9a735b83817c7ad3a94b6f5f88e675` |
| Ultima VII music and sound effects (optional) | `exult/data/exult-audio/` | `--exult-audio` | a directory holding Exult's Roland MT-32 packs, unpacked: `U7MusicOGG_1of2`, `U7MusicOGG_2of2` (the music, 76 `.ogg` files) and `sqsfxbg`, `sqsfxsi` (`sqsfxbg.flx`, `sqsfxsi.flx`), from Exult's download page | Music Pack 1.0; SFX packs 1.1 |

Notes:

- **Doom** is the shareware episode only: the port opens `DOOM1.WAD`, and
  Doom identifies the game by that name.
- **Descent** is built for the shareware data (`-DSHAREWARE`); the full
  game's data hasn't been tried.
- **System Shock:** only the English files and the low-resolution movies
  are copied (92 MB of the CD's data). `--no-logs` leaves out the audio
  logs and barks (61 MB less); emails then show their text without the
  audio.
- **Ultima VII:** either game can be given alone. Exult, the engine the port
  is built on, also needs its own data files (fonts, menus). They come
  from Exult 1.12.1's source on GitHub and are packed into `exult/data/exult/`
  by `exult/tools/get_data.sh`. In the tested installs, the files in `STATIC/`
  are dated 1994-02-03.
- **Ultima VII's sound:** with `--exult-audio`, both games get their music
  and sound effects as recorded from a Roland MT-32 (the music converted
  to WAV, 208 MB). Without it, The Black Gate's AdLib music is rendered
  (needs `--u7-bg`), and Serpent Isle has no music and neither game has
  sound effects.

## What goes on the card

| Path | From |
|---|---|
| `DOOM.BIN`, `DESCENT.BIN`, `TYRIAN.BIN`, `SSHOCK.BIN`, `EXULT.BIN` (Ultima VII on Exult) | the ports (`make` in each game's directory) |
| `U7BG.BIN`, `U7SI.BIN`, `U7/BLACKGATE/U7.CFG`, `U7/SERPENT/SERPENT.CFG` | Ultima VII's original engine (`make` and `make GAME=si` in `u7/`, after `u7/tools/get_source.sh`, which the script runs: it downloads the decompilation), with each game's sound configuration (Roland MT-32 music, Sound Blaster speech); it uses the same `STATIC/`, music and effects as `EXULT.BIN` |
| `DOOMS/DOOM1.WAD`, `DOOMS/MUSIC/D_*.WAV` | the Doom data; the music: `doom/tools/make_music.sh` (13 files, 81 MB) |
| `DESCENT/descent.hog`, `descent.pig`, `DESCENT/MUSIC/` | the Descent data; `descent/tools/make_music.sh` (8 files, 69 MB) |
| `TYRIAN/`, `TYRIAN/MUSIC/SONGnn.WAV` | the Tyrian data, less the DOS programs and documents; `tyrian/tools/make_music.sh` (41 files, 128 MB) |
| `SSHOCK/RES/DATA/`, `SSHOCK/RES/SOUND/THM*.BIN`, `SSHOCK/MUSIC/` | the System Shock data, by `sshock/tools/put_data.sh`; `sshock/tools/make_music.sh` (227 files, 95 MB) |
| `U7/exult.cfg`, `U7/EXULT/`, `U7/BLACKGATE/STATIC/`, `U7/SERPENT/STATIC/`, `U7/MUSIC/` | `exult/tools/exult.cfg`, `exult/tools/get_data.sh`, the games' `STATIC/`, the effects packs from `exult-audio/`, by `exult/tools/put_data.sh`; `exult/tools/make_music.sh` (the MT-32 pack: 76 files, 208 MB; else the AdLib renders: 61 files, 165 MB) |

The games write their configuration and saves into their own directories
(Descent: the root). Each game's README has the details.

The music is rendered with libADLMIDI (OPL3 emulation, each game's own FM
instruments) at a fixed version (`core/tools/midirender/build.sh`), so a
rebuild gives the same files.

## Options

```
--doom SOURCE     DOOM1.WAD, doom19s.zip, or its unpacked directory
--shock DIR       System Shock's SSHOCK directory
--u7-bg DIR       The Black Gate's install directory
--u7-si DIR       Serpent Isle's install directory
--exult-audio DIR Exult's MT-32 music and sound effects packs, unpacked
--descent DIR     Descent's data
--tyrian DIR      Tyrian's data
                  (each instead of the game's data/ directory)
--no-download     download nothing: leave out the games whose data would be
                  downloaded and isn't there yet
--no-music        no music (the games play silently where it would be)
--no-logs         System Shock without its audio logs and barks
--no-image        only sdcard/out/card/
--size MB         the image's size
--out DIR         instead of sdcard/out
```

## Requirements

On Debian or Ubuntu, beyond what the ports need (see the top-level
README):

```
sudo apt install curl unzip 7zip git cmake g++ ffmpeg python3 mtools dosfstools fdisk
```

The script checks for them before it builds anything, and names the
packages that are missing.

(`7zip` is called `p7zip-full` on older releases.) `mtools`, `dosfstools`
and `fdisk` are needed only for the image, which is made without root
access.

## Updating the card in the board

Without a card reader, `sdcard/out/card/` is the card's copy on the PC:
rebuild into it with `make_sdcard.sh` (the files keep their sources'
times), then

```
make sync      # core/tools/sdput/sdput.py sync sdcard/out/card
```

sends what is missing on the card or differs, through the serial port
(about 80 KB/s at 921600 baud), and leaves the rest, and what the games
wrote (saves, settings), alone. It compares sizes and times, so an
unchanged card takes seconds; the first sync of a card written another way
checksums its files on the board instead (about 2.2 MB/s: some minutes for
a full card). `--dry-run` lists what would be sent. See `core/README.md`,
SD card.

`sdput.py put LOCAL REMOTE ...` sends single files. Each game's
`put_data.sh` and `make_music.sh` can use it (`--upload`), and also take
`--to DIR` to copy into a card's file tree on the PC, which is how
`make_sdcard.sh` uses them.
