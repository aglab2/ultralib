NON_MATCHING ?= 1

ABI ?= eabi

TARGET := libgultra_rom
BASE_DIR := base_$(TARGET)
BASE_AR := $(TARGET).a
BUILD_DIR := build
BUILD_AR := $(BUILD_DIR)/$(TARGET)_$(ABI).a

WORKING_DIR := $(shell pwd)

CPP := cpp -P
AR := ar
AS := tools/gcc/as
CC := tools/gcc/gcc
AR_OLD := tools/gcc/ar

# export COMPILER_PATH := $(WORKING_DIR)/tools/gcc

ifeq ($(ABI),eabi)
IFLAGS := -I $(WORKING_DIR)/include -I $(WORKING_DIR)/include/gcc -I $(WORKING_DIR)/include/PR -I.
ABIFLAGS := -mabi=eabi -mgp32 -mfp32 -msingle-float -modd-spreg
AR_OLD := ar
AS := mips-n64-as
CC := mips-n64-gcc
endif

ifeq ($(ABI),n32)
IFLAGS := -I $(WORKING_DIR)/include -I $(WORKING_DIR)/include/gcc -I $(WORKING_DIR)/include/PR -I.
ABIFLAGS := -mabi=n32
AR_OLD := ar
AS := mips-n64-as
CC := mips-n64-gcc
endif

ifeq ($(ABI),o32)
IFLAGS := -I $(WORKING_DIR)/include -I $(WORKING_DIR)/include/gcc -I $(WORKING_DIR)/include/PR -I.
ABIFLAGS := -mabi=32
AR_OLD := ar
AS := mips-n64-as
CC := mips-n64-gcc
endif

ifeq ($(DEBUG_BUILD),1)
OPTFLAGS := -Og -g
else
OPTFLAGS := -Os -ffast-math -ftrapping-math -fno-associative-math -mno-check-zero-division
DFLAGS := -DNDEBUG -D_FINALROM
endif

CFLAGS  :=           -c -G 0 -mips3 -march=vr4300 $(ABIFLAGS) -mfix4300 -mno-abicalls -fno-PIC -ffreestanding -fwrapv -fno-stack-protector -mno-check-zero-division -D_LANGUAGE_C -Wall -Wno-missing-braces
ASFLAGS := -nostdinc -c -G 0 -mips3 -march=vr4300 $(ABIFLAGS) -mfix4300 -mno-abicalls -fno-PIC -ffreestanding -DMIPSEB -D_LANGUAGE_ASSEMBLY -D_ULTRA64 -x assembler-with-cpp
GBIDEFINE := -DF3DEX_GBI_2
CPPFLAGS = -D_MIPS_SZLONG=32 -D__USE_ISOC99 $(DFLAGS) $(IFLAGS) $(GBIDEFINE)

SRC_DIRS := $(shell find src -type d)
ASM_DIRS := $(shell find asm -type d -not -path "asm/non_matchings*")
C_FILES  := $(foreach dir,$(SRC_DIRS),$(wildcard $(dir)/*.c))
S_FILES  := $(foreach dir,$(SRC_DIRS) $(ASM_DIRS),$(wildcard $(dir)/*.s))
O_FILES  := $(foreach f,$(S_FILES:.s=.o),$(BUILD_DIR)/$f) \
            $(foreach f,$(C_FILES:.c=.o),$(BUILD_DIR)/$f) \
            $(foreach f,$(wildcard $(BASE_DIR)/*),$(BUILD_DIR)/$f)
# Because we patch the object file timestamps, we can't use them as the targets since they'll always be older than the C file
# Therefore instead we use marker files that have actual timestamps as the dependencies for the archive
MARKER_FILES := $(O_FILES:.o=.marker)

ifneq ($(NON_MATCHING),1)
COMPARE_OBJ = cmp $(BASE_DIR)/$(@F:.marker=.o) $(@:.marker=.o) && echo "$(@:.marker=.o): OK"
COMPARE_AR = cmp $(BASE_AR) $@ && echo "$@: OK"
else
COMPARE_OBJ :=
COMPARE_AR :=
AR_OLD := $(AR)
endif

BASE_OBJS := $(wildcard $(BASE_DIR)/*.o)
# Try to find a file corresponding to an archive file in any of src/ asm/ or the base directory, prioritizing src then asm then the original file
AR_ORDER = $(foreach f,$(shell $(AR) t $(BASE_AR)),$(shell find $(BUILD_DIR)/src $(BUILD_DIR)/asm $(BUILD_DIR)/$(BASE_DIR) -name $f -type f -print -quit))
MATCHED_OBJS = $(filter-out $(BUILD_DIR)/$(BASE_DIR)/%,$(AR_ORDER))
UNMATCHED_OBJS = $(filter-out $(MATCHED_OBJS),$(AR_ORDER))
NUM_OBJS = $(words $(AR_ORDER))
NUM_OBJS_MATCHED = $(words $(MATCHED_OBJS))
NUM_OBJS_UNMATCHED = $(words $(UNMATCHED_OBJS))

$(shell mkdir -p asm $(BASE_DIR) src $(BUILD_DIR)/$(BASE_DIR) $(foreach dir,$(ASM_DIRS) $(SRC_DIRS),$(BUILD_DIR)/$(dir)))

.PHONY: all clean distclean setup
all: $(BUILD_AR)

$(BUILD_AR): $(MARKER_FILES)
	$(AR_OLD) rcs $@ $(AR_ORDER)
ifneq ($(NON_MATCHING),1)
# patch archive creation time and individual files' ownership & permissions
	dd bs=1 skip=24 seek=24 count=12 conv=notrunc if=$(BASE_AR) of=$@ status=none
	python3 tools/patch_ar_meta.py $@
	@$(COMPARE_AR)
	@echo "Matched: $(NUM_OBJS_MATCHED)/$(NUM_OBJS)"
endif

clean:
	$(RM) -rf $(BUILD_DIR)

distclean: clean
	$(MAKE) -C tools distclean
	$(RM) -rf $(BASE_DIR)

setup:
	$(MAKE) -C tools
	cd $(BASE_DIR) && $(AR) xo ../$(BASE_AR)
	chmod -R +rw $(BASE_DIR)

# KMC gcc has a custom flag, N64ALIGN, which forces 8 byte alignment on arrays. This can be used to match, but
# an explicit aligned(8) attribute can be used instead. We opted for the latter for better compatibilty with
# other versions of GCC that do not have this flag.
# export N64ALIGN := ON
export VR4300MUL := ON

$(BUILD_DIR)/$(BASE_DIR)/%.marker: $(BASE_DIR)/%.o
	cp $< $(@:.marker=.o)
ifneq ($(NON_MATCHING),1)
#	@$(COMPARE_OBJ)
# change file timestamps to match original
	@touch -r $(BASE_DIR)/$(@F:.marker=.o) $(@:.marker=.o)
	@$(COMPARE_OBJ)
endif
	@touch $@

ifeq ($(NON_MATCHING),0)
$(BUILD_DIR)/src/os/assert.marker: OPTFLAGS := -O0
$(BUILD_DIR)/src/os/ackramromread.marker: OPTFLAGS := -O0
$(BUILD_DIR)/src/os/ackramromwrite.marker: OPTFLAGS := -O0
$(BUILD_DIR)/src/os/exit.marker: OPTFLAGS := -O0
$(BUILD_DIR)/src/os/seterrorhandler.marker: OPTFLAGS := -O0
endif
$(BUILD_DIR)/src/gu/us2dex_emu.marker: GBIDEFINE :=
$(BUILD_DIR)/src/gu/us2dex2_emu.marker: GBIDEFINE :=
$(BUILD_DIR)/src/sp/sprite.marker: GBIDEFINE := 
$(BUILD_DIR)/src/sp/spriteex.marker: GBIDEFINE := 
$(BUILD_DIR)/src/sp/spriteex2.marker: GBIDEFINE := 
$(BUILD_DIR)/src/sp/spriteex2.marker: GBIDEFINE := 
$(BUILD_DIR)/src/mgu/%.marker: export VR4300MUL := OFF
$(BUILD_DIR)/src/mgu/rotate.marker: export VR4300MUL := ON
$(BUILD_DIR)/src/os/%.marker: ASFLAGS += -P
$(BUILD_DIR)/src/gu/%.marker: ASFLAGS += -P
$(BUILD_DIR)/src/libc/%.marker: ASFLAGS += -P
$(BUILD_DIR)/src/voice/%.marker: CC := tools/compile_sjis.py -D__CC=$(CC) -Isrc/voice/

$(BUILD_DIR)/%.marker: %.c
ifneq ($(NON_MATCHING),1)
	cd $(<D) && $(WORKING_DIR)/$(CC) $(CFLAGS) $(CPPFLAGS) $(OPTFLAGS) $(<F) -o $(WORKING_DIR)/$(@:.marker=.o)
# check if this file is in the archive; patch corrupted bytes and change file timestamps to match original if so
	@$(if $(findstring $(BASE_DIR)/$(@F:.marker=.o), $(BASE_OBJS)), \
	 python3 tools/fix_objfile.py $(@:.marker=.o) $(BASE_DIR)/$(@F:.marker=.o) && \
	 $(COMPARE_OBJ) && \
	 touch -r $(BASE_DIR)/$(@F:.marker=.o) $(@:.marker=.o), \
	 echo "Object file $(<F:.marker=.o) is not in the current archive" \
	)
# create or update the marker file
else
	$(CC) $(CFLAGS) $(CPPFLAGS) $(OPTFLAGS) $< -o $(@:.marker=.o)
endif
	@touch $@

$(BUILD_DIR)/%.marker: %.s
ifneq ($(NON_MATCHING),1)
	cd $(<D) && $(WORKING_DIR)/$(CC) $(ASFLAGS) $(CPPFLAGS) -I. $(OPTFLAGS) $(<F) -o $(WORKING_DIR)/$(@:.marker=.o)
# check if this file is in the archive; patch corrupted bytes and change file timestamps to match original if so
	@$(if $(findstring $(BASE_DIR)/$(@F:.marker=.o), $(BASE_OBJS)), \
	 python3 tools/fix_objfile.py $(@:.marker=.o) $(BASE_DIR)/$(@F:.marker=.o) && \
	 $(COMPARE_OBJ) && \
	 touch -r $(BASE_DIR)/$(@F:.marker=.o) $(@:.marker=.o), \
	 echo "Object file $(<F:.marker=.o) is not in the current archive" \
	)
# create or update the marker file
else
	$(CC) $(ASFLAGS) $(CPPFLAGS) $(OPTFLAGS) $< -o $(@:.marker=.o)
endif
	@touch $@

# Disable built-in rules
.SUFFIXES:
print-% : ; $(info $* is a $(flavor $*) variable set to [$($*)]) @true
