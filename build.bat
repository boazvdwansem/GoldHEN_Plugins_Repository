@echo off
setlocal EnableDelayedExpansion

rem GoldHEN Plugins build script

cd /D "%~dp0"

echo [+] Workdir: !CD!

rd /s /q bin
mkdir bin\plugins
set BINDIR=!CD!\bin\plugins
echo [+] Output directory: !BINDIR!

rem change these if you wish:
set CC=clang
set CXX=clang++
set LD=ld.lld

rem Resolve SDK/toolchain locations. This makes Windows builds less dependent
rem on whether the current shell inherited the environment variables correctly.
set "GH_SDK=%GOLDHEN_SDK%"
if not defined GH_SDK if exist "C:\GoldHEN_Plugins_SDK\include\Common.h" set "GH_SDK=C:\GoldHEN_Plugins_SDK"
if not defined GH_SDK if exist "C:\GoldHEN_SDK\include\Common.h" set "GH_SDK=C:\GoldHEN_SDK"
set "GH_SDK_SRC=!GH_SDK!\source"

set "OO_TOOLCHAIN=%OO_PS4_TOOLCHAIN%"
if not defined OO_TOOLCHAIN if exist "C:\OpenOrbis\PS4Toolchain\include" set "OO_TOOLCHAIN=C:\OpenOrbis\PS4Toolchain"

echo [+] GOLDHEN_SDK: !GH_SDK!
echo [+] OO_PS4_TOOLCHAIN: !OO_TOOLCHAIN!

if not defined GH_SDK (
    echo [!] GOLDHEN_SDK is not set and no default SDK path was found.
    echo [!] Expected a folder containing include\Common.h
    exit /b 1
)

if not exist "!GH_SDK!\include\Common.h" (
    echo [!] Could not find GoldHEN SDK header: "!GH_SDK!\include\Common.h"
    exit /b 1
)

if not exist "!GH_SDK!\include\GoldHEN.h" (
    echo [!] Could not find GoldHEN SDK header: "!GH_SDK!\include\GoldHEN.h"
    exit /b 1
)

if not defined OO_TOOLCHAIN (
    echo [!] OO_PS4_TOOLCHAIN is not set and no default toolchain path was found.
    exit /b 1
)

if not exist "!OO_TOOLCHAIN!\include" (
    echo [!] Could not find OpenOrbis include directory: "!OO_TOOLCHAIN!\include"
    exit /b 1
)

if not exist "!OO_TOOLCHAIN!\link.x" (
    echo [!] Could not find OpenOrbis linker script: "!OO_TOOLCHAIN!\link.x"
    exit /b 1
)

rem Export the resolved locations so any child tools that still read the
rem original environment variables continue to work.
set "GOLDHEN_SDK=!GH_SDK!"
set "OO_PS4_TOOLCHAIN=!OO_TOOLCHAIN!"

rem usually you won't need to change anything below this line
set DEFS=-D_BSD_SOURCE=1 -D__BSD_VISIBLE=1 -D__PS4__=1 -DOO=1 -D__OPENORBIS__=1 -D__OOPS4__=1 -D__FINAL__=1
set BASELIBS=-lGoldHEN_Hook -lkernel -lc -lc++ -lSceLibcInternal -lSceVideoOut -lSceScreenShot -lSceVideoRecording -lSceSysmodule -lSceSystemService
set COMMONFLAGS=--target=x86_64-pc-freebsd12-elf -fPIC -funwind-tables -isysroot "!OO_TOOLCHAIN!" -isystem "!OO_TOOLCHAIN!\include" -I"!GH_SDK!\include" -I"common" -Wno-c99-designator %DEFS%
set CXXFLAGS=-fexceptions -fcxx-exceptions -isystem "!OO_TOOLCHAIN!\include\c++\v1"
set BASELDFLAGS=-m elf_x86_64 -pie -e _init --script "!OO_TOOLCHAIN!\link.x" --eh-frame-hdr -L"!OO_TOOLCHAIN!\lib" -L"!GH_SDK!"
set "BUILD_FAILED="
set "FAILED_PLUGINS="
set "SKIPPED_PLUGINS="

set datetimef=%DATE% %TIME%
for /f %%i in ('git rev-parse HEAD') do set COMMIT=%%i
for /f %%i in ('git branch --show-current') do set BRANCH=%%i
for /f %%i in ('git rev-list HEAD --count') do set VER=%%i

echo #pragma once /* git_ver.h */     >  common\git_ver.h
echo #define GIT_COMMIT "%COMMIT%"    >> common\git_ver.h
echo #define GIT_VER    "%BRANCH%"    >> common\git_ver.h
echo #define GIT_NUM    %VER%         >> common\git_ver.h
echo #define BUILD_DATE "%datetimef%" >> common\git_ver.h

echo [+] Building the plugins
for /D %%G in ("plugin_src\*") do (
    rd /s /q "%%G\build"
    mkdir "%%G\build"
    mkdir "%%G\build\ghsdk"
    set OBJS=
    set "SKIP_PLUGIN="
    set "PLUGIN_EXTRA_INCLUDES="
    set "PLUGIN_LIBS=%BASELIBS%"
    rem C source, this ensures we build the CRT first and it's the first object file
    for %%f in ("common\*.c", "%%G\source\*.c") do (
        %CC% %COMMONFLAGS% !PLUGIN_EXTRA_INCLUDES! -I"%%G\include" -c "%%f" -o "%%G\build\%%~nf.c.o"
        set OBJS=!OBJS! "%%G\build\%%~nf.c.o"
    )
    rem ugly but works, get the *name* of the directory
    for %%f in ("%%G") do set PLUGIN_NAME=%%~nxf

    if "!PLUGIN_NAME!"=="game_patch" (
        if not exist "external\mxml.h" (
            echo [WARN] Skipping game_patch: missing external\mxml.h
            set "SKIPPED_PLUGINS=!SKIPPED_PLUGINS! game_patch"
            set "SKIP_PLUGIN=1"
        )
        if not exist "!OO_TOOLCHAIN!\lib\libmxml.so" (
            echo [WARN] Skipping game_patch: missing !OO_TOOLCHAIN!\lib\libmxml.so
            if not defined SKIP_PLUGIN set "SKIPPED_PLUGINS=!SKIPPED_PLUGINS! game_patch"
            set "SKIP_PLUGIN=1"
        )
    )

    if not defined SKIP_PLUGIN (
        if "!PLUGIN_NAME!"=="frame_logger" set "PLUGIN_LIBS=!PLUGIN_LIBS! -lSceGnmDriver -lScePad -lSceUserService"
        if "!PLUGIN_NAME!"=="gamepad_helper" set "PLUGIN_LIBS=!PLUGIN_LIBS! -lScePad"
        if "!PLUGIN_NAME!"=="no_share_watermark" set "PLUGIN_LIBS=!PLUGIN_LIBS! -lSceRemoteplay"
        if "!PLUGIN_NAME!"=="game_patch" (
            set "PLUGIN_LIBS=!PLUGIN_LIBS! -lmxml"
            if exist "external" set "PLUGIN_EXTRA_INCLUDES=-I""external"""
        )

        rem C++ sources for plugins that use them
        for %%f in ("%%G\source\*.cpp") do (
            if exist "%%f" (
                %CXX% %COMMONFLAGS% %CXXFLAGS% !PLUGIN_EXTRA_INCLUDES! -I"%%G\include" -c "%%f" -o "%%G\build\%%~nf.cpp.o"
                set OBJS=!OBJS! "%%G\build\%%~nf.cpp.o"
            )
        )

        echo [+] !PLUGIN_NAME!
        echo [+] !OBJS!
        %LD% %BASELDFLAGS% !PLUGIN_LIBS! !OBJS! -o "%%G\build\!PLUGIN_NAME!.elf"
        if exist "%%G\build\!PLUGIN_NAME!.elf" (
            "!OO_TOOLCHAIN!\bin\windows\create-fself" -in="%%G\build\!PLUGIN_NAME!.elf" -out="%%G\build\!PLUGIN_NAME!.oelf" -lib="%%G\build\!PLUGIN_NAME!.prx" --paid 0x3800000000000011
            if exist "%%G\build\!PLUGIN_NAME!.prx" (
                copy "%%G\build\!PLUGIN_NAME!.prx" "!BINDIR!"
            ) else (
                echo [ERROR] Failed to package !PLUGIN_NAME!
                set "BUILD_FAILED=1"
                set "FAILED_PLUGINS=!FAILED_PLUGINS! !PLUGIN_NAME!"
            )
        ) else (
            echo [ERROR] Failed to link !PLUGIN_NAME!
            set "BUILD_FAILED=1"
            set "FAILED_PLUGINS=!FAILED_PLUGINS! !PLUGIN_NAME!"
        )
    )
)

if defined BUILD_FAILED (
    echo [WARN] Build finished with failures:!FAILED_PLUGINS!
    exit /b 1
)

if defined SKIPPED_PLUGINS (
    echo [WARN] Build finished with skipped plugins:!SKIPPED_PLUGINS!
)

echo [+] All done
