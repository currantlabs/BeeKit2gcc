CPU:=-mcpu=cortex-m4 -mthumb -Wa,-mthumb

CC:=arm-none-eabi-gcc $(CPU)
CPP := arm-none-eabi-cpp
OBJCOPY := arm-none-eabi-objcopy

ProjDirPath:=.
LINKER_SCRIPT=PLM/Linker_Config/MKW24D512V.ld

MODULES = PLM SSM MacPhy BeeApps Application
MAKEFILE_DIR := $(dir $(firstword $(MAKEFILE_LIST)))
BUILD_DIR ?= build

-include $(foreach mod,$(MODULES),$(BUILD_DIR)/$(mod).mk)

OBJ = $(foreach mod,$(MODULES),$(OBJ_$(mod)))

-include $(BUILD_DIR)/config.mk

all: $(BUILD_DIR)/main.srec

$(BUILD_DIR)/main.elf: $(BUILD_DIR)/$(LINKER_SCRIPT) $(OBJ)
	@echo "LD	$@ ..."
	@$(CC) $(LDFLAGS) $(EXTRA_LDFLAGS) -o $@ -T $^ -Wl,--start-group $(LDLIBS) -Wl,--end-group

$(BUILD_DIR)/main.srec: $(BUILD_DIR)/main.elf
	@echo "OBJCOPY	$@ ..."
	@$(OBJCOPY) -O srec $< $@

# Run preprocessor on the linker script
# The parameters here are extracted from the CodeWarrior project file
$(BUILD_DIR)/$(LINKER_SCRIPT): $(patsubst %.ld,%.bld,$(LINKER_SCRIPT))
	@echo "CPP	$@ ..."
	@mkdir -p $(dir $@)
	@$(CPP) -P  -DgUseNVMLink_d=1 $< -o $@

# Generate per-directory list of sources
$(BUILD_DIR)/%.mk: %
	@echo "GEN	$@ ..."
	@echo 'OBJ_$< := \\' >> $@
	@find $^ -name *.c | sed 's/\(.*\)\.c/	${BUILD_DIR}\/\1\.o\\/' >> $@
	@echo >> $@

$(BUILD_DIR)/%.o: %.c
	@echo "CC	$@ ..."
	@mkdir -p $(dir $@)
	@$(CC) $(CPPFLAGS) $(CFLAGS) $^ -o $@

# Extract arguments, defines, libraries from the CodeWarrior project file
$(BUILD_DIR)/config.mk: .cproject
	@echo "GEN	$@ ..."
	@mkdir -p $(BUILD_DIR)
	@beekit2gcc.py $^ $@

clean:
	@rm -f $(OBJ)
	@rm -f $(BUILD_DIR)/$(LINKER_SCRIPT)
	@rm -f $(BUILD_DIR)/*.mk
	@rm -f $(BUILD_DIR)/main.elf $(BUILD_DIR)/main.srec
	@rm -r $(BUILD_DIR)

.PHONY = clean
