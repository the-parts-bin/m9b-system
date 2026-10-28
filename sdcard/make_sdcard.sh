#!/usr/bin/env bash
# Builds the SD card for the m9b: the five game ports, their data and their
# pre-rendered music, as a file tree (OUT/card/) and as a disk image
# (OUT/m9b-sd.img: one FAT32 partition) to write to a card. See README.md
# for the game versions each option expects.
#
# Usage: make_sdcard.sh [options]
# Each game's data is taken from its data/ directory (data/README.md there
# says what goes in it); these options take it from elsewhere instead:
#   --doom SOURCE     DOOM1.WAD (shareware 1.9), doom19s.zip, or its unpacked directory
#                     (default: doom/data/DOOM1.WAD or doom/data/doom19s.zip)
#   --shock DIR       System Shock's CD version: the SSHOCK directory (holds DATA/, SOUND/)
#                     (default: sshock/data/SSHOCK)
#   --u7-bg DIR       Ultima VII: The Black Gate, the DOS install (holds STATIC/)
#                     (default: exult/data/ULTIMA7)
#   --u7-si DIR       Ultima VII Part Two: Serpent Isle, the DOS install (holds STATIC/)
#                     (default: exult/data/SERPENT)
#   --exult-audio DIR Exult's MT-32 music and sound effects packs for Ultima VII (see
#                     README.md; default: exult/data/exult-audio); without them, The Black
#                     Gate's AdLib music, rendered
#   --descent DIR     Descent shareware 1.4 (descent.hog, descent.pig); default:
#                     descent/data, downloaded there if missing
#   --tyrian DIR      Tyrian 2.1 freeware data; default: tyrian/data, downloaded there
#                     if missing
#   --no-download     download nothing: Descent, Tyrian and Ultima VII are left out
#                     unless their data is there already (Ultima VII needs Exult's own
#                     data files from GitHub, exult/data/exult)
#   --no-music        leave out the music (rendering it takes a while: see README.md)
#   --no-logs         System Shock without its audio logs and barks (61 MB less)
#   --no-image        only the file tree, no image
#   --size MB         the image's size (default: the files plus some room, in 64 MB steps)
#   --out DIR         where everything goes (default: sdcard/out)
# A game whose data isn't there is left out. Music renders are kept in
# OUT/music and reused; delete OUT/music/GAME to render again. Files keep
# their sources' times, so that core/tools/sdput/sdput.py sync OUT/card (or
# make sync) sends only what changed to the card in the board.
set -euo pipefail

usage() { sed -n '2,36p' "$0" | sed 's/^# \{0,1\}//'; }
HERE=$(dirname "$(realpath "$0")")
TOP=$(realpath "$HERE/..")
OUT=$HERE/out
DOOM="" SHOCK="" BG="" SI="" DESCENT="" TYRIAN="" EXULT_AUDIO=""
DOWNLOAD=1 MUSIC=1 IMAGE=1 SIZE="" SHOCK_OPTS=()
while [ $# -gt 0 ]; do
    case $1 in
    --doom) DOOM=$(realpath "$2"); shift ;;
    --shock) SHOCK=$(realpath "$2"); shift ;;
    --u7-bg) BG=$(realpath "$2"); shift ;;
    --u7-si) SI=$(realpath "$2"); shift ;;
    --exult-audio) EXULT_AUDIO=$(realpath "$2"); shift ;;
    --descent) DESCENT=$(realpath "$2"); shift ;;
    --tyrian) TYRIAN=$(realpath "$2"); shift ;;
    --no-download) DOWNLOAD=0 ;;
    --no-music) MUSIC=0 ;;
    --no-logs) SHOCK_OPTS+=(--no-logs) ;;
    --no-image) IMAGE=0 ;;
    --size) SIZE=$2; shift ;;
    --out) OUT=$(realpath -m "$2"); shift ;;
    -h | --help) usage; exit 0 ;;
    *) echo "unknown option $1" >&2; usage >&2; exit 1 ;;
    esac
    shift
done
export PATH=$PATH:/usr/sbin:/sbin   # sfdisk, mkfs.fat

# The tools, before anything is built (README.md, Requirements)
missing=()
need() { command -v "$1" > /dev/null || missing+=("$2"); }
need make make
need git git
need python3 python3
need riscv64-unknown-elf-gcc gcc-riscv64-unknown-elf
if command -v riscv64-unknown-elf-gcc > /dev/null &&
    ! riscv64-unknown-elf-gcc -specs=picolibc.specs -E -x c /dev/null > /dev/null 2>&1; then
    missing+=(picolibc-riscv64-unknown-elf libstdc++-riscv64-unknown-elf-picolibc)
fi
need g++ g++
need curl curl
need unzip unzip
need 7z 7zip
if [ $MUSIC = 1 ]; then
    need cmake cmake
    need ffmpeg ffmpeg
fi
if [ $IMAGE = 1 ]; then
    need mcopy mtools
    need mkfs.fat dosfstools
    need sfdisk fdisk
fi
if [ ${#missing[@]} -gt 0 ]; then
    echo "missing tools; on Debian or Ubuntu: sudo apt install ${missing[*]}" >&2
    exit 1
fi

CARD=$OUT/card
MUS=$OUT/music
SDPUT=$TOP/core/tools/sdput/sdput.py

say() { printf '\n== %s ==\n' "$*"; }
# check FILE SIZE MD5: warn when the data isn't the version the ports were tested with
check() {
    local f=$1 size=$2 md5=$3
    [ -f "$f" ] || { echo "missing: $f" >&2; exit 1; }
    if [ "$(stat -c %s "$f")" != "$size" ] || [ "$(md5sum < "$f" | cut -d' ' -f1)" != "$md5" ]; then
        echo "warning: $f isn't the tested version (see sdcard/README.md); carrying on" >&2
    fi
}
# static DIR: the STATIC/ directory of a U7 install, whatever its case
static() { find "$1" -maxdepth 1 -iname static -type d | head -1; }
# program DIR BIN NAME: builds DIR/build/BIN.bin and puts it in the root as NAME.BIN
program() {
    make -C "$TOP/$1" -j"$(nproc)" -s
    cp -p "$TOP/$1/build/$2.bin" "$CARD/$3.BIN"
}
# first PATH...: the first of the paths that exists, or nothing
first() {
    local p
    for p; do [ -e "$p" ] && { realpath "$p"; return; }; done
    return 0
}
# music GAME COMMAND...: runs GAME's make_music.sh into MUS/GAME (once), then
# links the files it put in MUS/GAME/card into the card
music() {
    local g=$1
    shift
    [ $MUSIC = 1 ] || return 0
    if [ ! -e "$MUS/$g/done" ]; then
        rm -rf "$MUS/$g"
        "$@" "$MUS/$g" --to "$MUS/$g/card"
        touch "$MUS/$g/done"
    fi
    cp -al "$MUS/$g/card/." "$CARD/"
}

# The data directories in the game repositories (data/README.md in each)
[ -n "$DOOM" ] || DOOM=$(first "$TOP/doom/data/DOOM1.WAD" "$TOP/doom/data/doom19s.zip")
[ -n "$SHOCK" ] || SHOCK=$(first "$TOP/sshock/data/SSHOCK")
[ -n "$BG" ] || BG=$(first "$TOP/exult/data/ULTIMA7")
[ -n "$SI" ] || SI=$(first "$TOP/exult/data/SERPENT")
[ -n "$EXULT_AUDIO" ] || EXULT_AUDIO=$(first "$TOP/exult/data/exult-audio")
for d in doom descent tyrian sshock exult; do
    [ -f "$TOP/$d/Makefile" ] || { echo "$d/ is empty: git submodule update --init" >&2; exit 1; }
done

rm -rf "$CARD"
mkdir -p "$CARD" "$MUS"
GAMES=()

if [ -n "$DOOM" ]; then
    say "Doom"
    WAD=$TOP/doom/data/DOOM1.WAD
    [ "$DOOM" = "$WAD" ] || "$TOP/doom/tools/get_data.sh" "$DOOM" "$TOP/doom/data"
    check "$WAD" 4196020 f0cefca49926d00903cf57551d901abe
    program doom doom DOOM
    mkdir -p "$CARD/DOOMS"
    cp -p "$WAD" "$CARD/DOOMS/"
    music doom "$TOP/doom/tools/make_music.sh" "$WAD"
    GAMES+=(Doom)
fi

[ -n "$DESCENT" ] || [ $DOWNLOAD = 1 ] || DESCENT=$(first "$TOP/descent/data/descent.pig")
[ -z "$DESCENT" ] || [ -d "$DESCENT" ] || DESCENT=$(dirname "$DESCENT")
if [ -n "$DESCENT" ] || [ $DOWNLOAD = 1 ]; then
    say "Descent"
    if [ -z "$DESCENT" ]; then   # downloaded unless it's there already
        DESCENT=$TOP/descent/data
        "$TOP/descent/tools/get_data.sh" "$DESCENT"
    fi
    check "$DESCENT/descent.hog" 2339773 cf1caf9c7a0681de80fac8cb593b33eb
    check "$DESCENT/descent.pig" 5092871 f8dc0f2b3ee8baa2c622f57b470fe147
    program descent descent DESCENT
    mkdir -p "$CARD/DESCENT"
    cp -p "$DESCENT/descent.hog" "$DESCENT/descent.pig" "$CARD/DESCENT/"
    music descent "$TOP/descent/tools/make_music.sh" "$DESCENT/descent.hog"
    GAMES+=(Descent)
fi

[ -n "$TYRIAN" ] || [ $DOWNLOAD = 1 ] || [ -z "$(find "$TOP/tyrian/data" -maxdepth 1 -iname tyrian1.lvl)" ] || TYRIAN=$TOP/tyrian/data
if [ -n "$TYRIAN" ] || [ $DOWNLOAD = 1 ]; then
    say "Tyrian"
    if [ -z "$TYRIAN" ]; then   # downloaded unless it's there already
        TYRIAN=$TOP/tyrian/data
        "$TOP/tyrian/opentyrian/get_data.sh" "$TYRIAN"
    fi
    check "$(find "$TYRIAN" -maxdepth 1 -iname tyrian1.lvl | head -1)" 538262 a1e73e0586ce715ab7daaedfe9b98595
    program tyrian tyrian TYRIAN
    mkdir -p "$CARD/TYRIAN"
    # The data files, without the DOS programs and documents (and our README;
    # OpenTyrian
    # opens lower-case names; FatFs doesn't mind either way).
    for f in "$TYRIAN"/*; do
        b=$(basename "$f" | tr '[:upper:]' '[:lower:]')
        case $b in *.exe | *.com | *.doc | *.txt | *.diz | *.ico | *.ovl | readme.md) continue ;; esac
        [ -f "$f" ] && cp -p "$f" "$CARD/TYRIAN/$b"
    done
    music tyrian "$TOP/tyrian/tools/make_music.sh" "$TYRIAN"
    GAMES+=(Tyrian)
fi

if [ -n "$SHOCK" ]; then
    say "System Shock"
    check "$SHOCK/DATA/CITMAT.RES" 105834 e8727598d54c360eff5916b9b1570082
    check "$SHOCK/DATA/ARCHIVE.DAT" 613566 d290ef2e3c4fe605473d7cf0b65a96dc
    program sshock sshock SSHOCK
    "$TOP/sshock/tools/put_data.sh" "$SHOCK" "${SHOCK_OPTS[@]}" --to "$CARD"
    music shock "$TOP/sshock/tools/make_music.sh" "$SHOCK"
    GAMES+=("System Shock")
fi

if { [ -n "$BG" ] || [ -n "$SI" ]; } && [ $DOWNLOAD = 0 ] && [ ! -s "$TOP/exult/data/exult/exult.flx" ]; then
    echo "Ultima VII left out: Exult's data files have to be downloaded (no --no-download)" >&2
    BG="" SI=""
fi
if [ -n "$BG" ] || [ -n "$SI" ]; then
    say "Ultima VII"
    u7=()
    if [ -n "$BG" ]; then
        check "$(static "$BG")/USECODE" 1521368 07ea98fe080ea7dc720492856ebf0fb8
        u7+=(--bg "$BG")
    fi
    if [ -n "$SI" ]; then
        check "$(static "$SI")/USECODE" 2103075 3a9a735b83817c7ad3a94b6f5f88e675
        u7+=(--si "$SI")
    fi
    [ -s "$TOP/exult/data/exult/exult.flx" ] || "$TOP/exult/tools/get_data.sh" "$TOP/exult/data/exult"
    program exult exult EXULT
    [ -z "$EXULT_AUDIO" ] || u7+=(--sfx "$EXULT_AUDIO")
    "$TOP/exult/tools/put_data.sh" --flx "$TOP/exult/data/exult" "${u7[@]}" --to "$CARD"
    if [ -n "$EXULT_AUDIO" ]; then   # the MT-32 recordings, both games
        music u7-mt32 "$TOP/exult/tools/make_music.sh" "$EXULT_AUDIO"
    elif [ -n "$BG" ]; then          # The Black Gate's AdLib music, rendered
        music u7 "$TOP/exult/tools/make_music.sh" "$(dirname "$(static "$BG")")"
    fi
    GAMES+=("Ultima VII")
    # The original engine too (u7/), from the decompilation, which
    # u7/tools/get_source.sh fetches: each game's sound configuration (Roland
    # music, Sound Blaster speech) beside its STATIC/
    if [ ! -f "$TOP/u7/Makefile" ]; then
        echo "Ultima VII's original engine left out: u7/ is empty (git submodule update --init)" >&2
    elif [ -d "$TOP/u7/decomp/.git" ] || [ $DOWNLOAD = 1 ]; then
        say "Ultima VII, the original engine"
        "$TOP/u7/tools/get_source.sh" > /dev/null
        cfg() { [ "$(cat "$1" 2>/dev/null)" = "$(printf 'r 330\r\n220 7 1\r\n')" ] || printf 'r 330\r\n220 7 1\r\n' > "$1"; }
        if [ -n "$BG" ]; then
            make -C "$TOP/u7" -j"$(nproc)" -s
            cp -p "$TOP/u7/build/u7bg.bin" "$CARD/U7BG.BIN"
            cfg "$CARD/U7/BLACKGATE/U7.CFG"
        fi
        if [ -n "$SI" ]; then
            make -C "$TOP/u7" GAME=si -j"$(nproc)" -s
            cp -p "$TOP/u7/build-si/u7si.bin" "$CARD/U7SI.BIN"
            cfg "$CARD/U7/SERPENT/SERPENT.CFG"
        fi
    else
        echo "Ultima VII's original engine left out: its source has to be downloaded (no --no-download)" >&2
    fi
fi

[ ${#GAMES[@]} -gt 0 ] || { echo "no games: see --help" >&2; exit 1; }
say "Card: $CARD"
echo "${GAMES[*]}: $(find "$CARD" -type f | wc -l) files, $(du -sh --apparent-size "$CARD" | cut -f1)"
echo "To the card in the board, sending only what changed: core/tools/sdput/sdput.py sync $CARD"
[ $IMAGE = 1 ] || exit 0

say "Image"
if [ -z "$SIZE" ]; then   # the files, 5% for FAT32's clusters and tables, 32 MB spare
    used=$(du -sm --apparent-size "$CARD" | cut -f1)
    SIZE=$(((used * 105 / 100 + 32 + 1 + 63) / 64 * 64))
fi
IMG=$OUT/m9b-sd.img
rm -f "$IMG"
truncate -s "${SIZE}M" "$IMG"
printf 'label: dos\nstart=2048, type=c\n' | sfdisk -q "$IMG"        # one partition from 1 MB
mkfs.fat -F 32 -n M9B --offset 2048 "$IMG" $(((SIZE - 1) * 1024)) > /dev/null
MTOOLS_SKIP_CHECK=1 mcopy -s -Q -i "$IMG@@1M" "$CARD"/* ::/
echo "$IMG: $SIZE MB. Write it to a card (all of the card's contents are lost) with, e.g.,"
echo "  sudo dd if=$IMG of=/dev/sdX bs=4M conv=fsync status=progress"
