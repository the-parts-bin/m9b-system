# Builds the m9b's artefacts (see README.md):
#   make              the core firmware, the five game ports and the board tools
#                     (not u7/, whose source is downloaded: make sdcard builds it)
#   make sdcard       the SD card, from the game data in each game's data/
#                     (SDCARD="--doom ... --shock ..." for data elsewhere: sdcard/README.md)
#   make bitstream    the FPGA bitstream (the Gowin IDE: GOWIN_HOME, default ~/gowin/IDE)
#   make flash        writes the bitstream and firmware to the board's flash
#   make sync         sends what changed in sdcard/out/card to the card in the board
#   make sim          the whole-system simulation (Icarus Verilog)
#   make clean
# The parts are git submodules; a missing one is checked out first.

GAMES := doom descent tyrian sshock exult
PARTS := core $(GAMES) u7
TOOLS := core/tools/sdput core/tools/usbdiag

all: firmware $(GAMES) tools

# The submodules, if the repository was cloned without --recursive
submodules:
	@for p in $(PARTS); do [ -e $$p/.git ] || { git submodule update --init && break; }; done

firmware: submodules
	$(MAKE) -C core/firmware

$(GAMES): submodules
	$(MAKE) -C $@

tools: submodules
	for d in $(TOOLS); do $(MAKE) -C $$d || exit 1; done

bitstream: submodules
	core/build.sh --build

flash: submodules
	core/build.sh --flash

sdcard: submodules
	sdcard/make_sdcard.sh $(SDCARD)

sync: submodules
	core/tools/sdput/sdput.py sync sdcard/out/card

sim: submodules
	core/sim/run_soc.sh

clean:
	$(MAKE) -C core/firmware clean
	for d in $(GAMES) $(TOOLS); do $(MAKE) -C $$d clean; done

.PHONY: all submodules firmware $(GAMES) tools bitstream flash sdcard sync sim clean
