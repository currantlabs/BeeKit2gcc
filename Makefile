CPU:=-mcpu=cortex-m4 -mthumb -Wa,-mthumb

CC:=arm-none-eabi-gcc $(CPU)
CPP := arm-none-eabi-cpp
OBJCOPY := arm-none-eabi-objcopy

ProjDirPath:=.
LINKER_SCRIPT=$(ProjDirPath)/PLM/Linker_Config/MKW24D512V.ld

MODULES = PLM SSM MacPhy BeeApps
MAKEFILE_DIR := $(dir $(firstword $(MAKEFILE_LIST)))

include $(foreach mod,$(MODULES),$(mod).mk)

OBJ = $(foreach mod,$(MODULES),$(OBJ_$(mod)))

include config.mk

LDFLAGS+=-L$(ProjDirPath)

all: main.srec

main.elf: $(LINKER_SCRIPT) $(OBJ)
	$(CC) $(LDFLAGS) -o $@ -T $^ -Wl,--start-group $(LDLIBS) -Wl,--end-group

main.srec: main.elf
	$(OBJCOPY) -O srec $< $@

# Run preprocessor on the linker script
# The parameters here are extracted from the CodeWarrior project file
$(LINKER_SCRIPT): $(patsubst %.ld,%.bld,$(LINKER_SCRIPT))
	$(CPP) -P  -DgUseNVMLink_d=1  $< -o $@

# Generate per-directory list of sources
%.mk: %
	@echo -n 'Generating make instructions for $^...'
	@echo -e 'SRCDIR_$< := \\' > $@
	@find $^ -name *.c | sed 's|^\(.*\)/[^/]*|\t\1 \\|' | sort -u >> $@
	@echo >> $@
	@echo -e 'OBJ_$< := $$(foreach dir,$$(SRCDIR_$<), \\' >> $@
	@echo -e '\t\t$$(patsubst %.c,%.o, \\' >> $@
	@echo -e '\t\t$$(wildcard $$(dir)/*.c)))' >> $@
	@echo ' Done.'

# Extract arguments, defines, libraries from the CodeWarrior project file
config.mk: .cproject
	$(MAKEFILE_DIR)generate.py $^ $@

cscope.out:
	cscope -b -R -I /usr/arm-none-eabi/include -s $(ProjDirPath)

clean:
	rm -f $(OBJ)

dist-clean: clean
	rm -f $(LINKER_SCRIPT)
	rm -f *.mk

clean-all: dist-clean clean
	rm -f main.elf main.srec

.PHONY = clean dist-clean clean-all
