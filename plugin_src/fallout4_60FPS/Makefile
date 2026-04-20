# Library metadata.

DEBUG_FLAGS = -D__FINAL__=1
LOG_TYPE = -D__USE_PRINTF__
BUILD_TYPE = _final

ifeq ($(DEBUG),1)
    DEBUG_FLAGS = -D__FINAL__=0
    BUILD_TYPE = _debug
endif

TYPE         := $(BUILD_TYPE)
FINAL        := $(DEBUG_FLAGS)
BUILD_FOLDER := $(shell pwd)/../../bin/plugins
OUTPUT_PRX   := $(shell basename $(CURDIR))
TARGET       := $(BUILD_FOLDER)/prx$(TYPE)/$(OUTPUT_PRX)
TARGET_ELF   := $(BUILD_FOLDER)/elf$(TYPE)/$(OUTPUT_PRX)
TARGETSTUB   := $(OUTPUT_PRX).so

# Libraries linked into the ELF.
LIBS := -lSceLibcInternal -lGoldHEN_Hook -lkernel -lSceSysmodule

EXTRAFLAGS := $(DEBUG_FLAGS) $(LOG_TYPE) -fcolor-diagnostics -Wall

# You likely won't need to touch anything below this point.
# Root vars
TOOLCHAIN     := $(OO_PS4_TOOLCHAIN)
GH_SDK        := $(GOLDHEN_SDK)
PROJDIR       := ../$(shell basename $(CURDIR))/source
INTDIR        := ../$(shell basename $(CURDIR))/build
INCLUDEDIR    := ../$(shell basename $(CURDIR))/include
COMMON_DIR    := ../../common

# Define objects to build
CFILES      := $(wildcard $(PROJDIR)/*.c)
CPPFILES    := $(wildcard $(PROJDIR)/*.cpp)
COMMONFILES := $(wildcard $(COMMONDIR)/*.cpp)
OBJS        := $(patsubst $(PROJDIR)/%.c, $(INTDIR)/%.o, $(CFILES)) $(patsubst $(PROJDIR)/%.cpp, $(INTDIR)/%.o, $(CPPFILES)) $(patsubst $(COMMONDIR)/%.cpp, $(INTDIR)/%.o, $(COMMONFILES))
STUBOBJS    := $(patsubst $(PROJDIR)/%.c, $(INTDIR)/%.o, $(CFILES)) $(patsubst $(PROJDIR)/%.cpp, $(INTDIR)/%.o.stub, $(CPPFILES)) $(patsubst $(COMMONDIR)/%.cpp, $(INTDIR)/%.o.stub, $(COMMONFILES))

# Define final C/C++ flags
CFLAGS      := $(FINAL) --target=x86_64-pc-freebsd12-elf -fPIC -funwind-tables -c $(EXTRAFLAGS) -isysroot $(TOOLCHAIN) -isystem $(TOOLCHAIN)/include -I$(GH_SDK)/include -I$(INCLUDEDIR) -I$(COMMON_DIR) $(O_FLAG)
CXXFLAGS    := $(CFLAGS) -isystem $(TOOLCHAIN)/$(INCLUDEDIR)/c++/v1
LDFLAGS     := -m elf_x86_64 -pie --script $(TOOLCHAIN)/link.x -e _init --eh-frame-hdr -L$(TOOLCHAIN)/lib -L$(GH_SDK) $(LIBS) 

# Create the intermediate directory incase it doesn't already exist.
_unused     := $(shell mkdir -p $(INTDIR))

# Check for linux vs macOS and account for clang/ld path
UNAME_S     := $(shell uname -s)

ifeq ($(UNAME_S),Linux)
    CC      := $(TOOLCHAIN)/bin/clang
    CXX     := $(TOOLCHAIN)/bin/clang++
    LD      := $(TOOLCHAIN)/bin/ld.lld
    OBJCOPY := $(TOOLCHAIN)/bin/objcopy
endif
ifeq ($(UNAME_S),Darwin)
    CC      := $(TOOLCHAIN)/bin/clang
    CXX     := $(TOOLCHAIN)/bin/clang++
    LD      := $(TOOLCHAIN)/bin/ld.lld
    OBJCOPY := $(TOOLCHAIN)/bin/objcopy
endif

$(TARGET): $(OBJS)
	$(LD) $(LDFLAGS) $^ -o $(TARGET_ELF)
	$(TOOLCHAIN)/bin/$(OO_PS4_TOOLCHAIN_TYPE)/create-fself -in=$(TARGET_ELF) -out=$(TARGET) --paid 0x3800000000000011

$(INTDIR)/%.o: $(PROJDIR)/%.c
	$(CC) $(CFLAGS) -c $< -o $@

$(INTDIR)/%.o: $(PROJDIR)/%.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(INTDIR)/%.o: $(COMMONDIR)/%.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(INTDIR)/%.o.stub: $(PROJDIR)/%.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(INTDIR)/%.o.stub: $(COMMONDIR)/%.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

.PHONY: clean

clean:
	rm -f $(TARGET) $(TARGET_ELF) $(OBJS) $(STUBOBJS)