@echo off
cls
SETLOCAL EnableDelayedExpansion

:: Configuration - Update these paths to match your environment
set STM32_PROGRAMMER="C:\Program Files\STMicroelectronics\STM32Cube\STM32CubeProgrammer\bin\STM32_Programmer_CLI.exe"
set PROG_ARGS=-c port=SWD freq=480 reset=HWrst
set DEVICE=STM32WB55CG

:: Firmware paths - Update these to your specific firmware versions
set FUS_BIN=".\STM32WB5x_FUS_fw.bin"
set WIRELESS_STACK_BIN=".\stm32wb5x_BLE_Stack_full_fw.bin"
set APPLICATION_BIN=".\Firmware.hex"

:: FUS and Wireless Stack versions to verify (update to your target versions)
set TARGET_FUS_VERSION=1.2.0
set TARGET_WIRELESS_STACK_VERSION=1.20.0

echo.
echo ==============================================
echo STM32WB55CG Firmware Upgrade Process
echo ==============================================
echo.

:: Step 0: Ensure FUS is running (delete wireless stack if needed)
echo.
echo.
echo [0/5] ------------------------ Checking FUS state ----------------------- 
echo Try to start FUS
%STM32_PROGRAMMER% %PROG_ARGS% mode=UR -startfus
if errorlevel 1 (
	echo Start FUS failed!
    %STM32_PROGRAMMER% %PROG_ARGS% mode=UR -fwdelete
    if errorlevel 1 (
        echo Warning: Wireless stack delete failed - trying to continue anyway
		pause
		exit /b 1
    )	
	%STM32_PROGRAMMER% %PROG_ARGS% mode=UR -startfus
	if errorlevel 1 (	
		echo 2nd Start FUS failed!
		pause
		exit /b 1		
	)
)

%STM32_PROGRAMMER% %PROG_ARGS% mode=UR -fusgetstate | find "FUS_STATE_RUNNING" >nul
if errorlevel 1 (
    echo FUS is not running. Attempting to revert...
    echo Deleting wireless stack to activate FUS...
    %STM32_PROGRAMMER% %PROG_ARGS% mode=UR -fwdelete
    if errorlevel 1 (
        echo Warning: Wireless stack delete failed - trying to continue anyway
    )
)

:: Step 1: Upgrade FUS (Firmware Upgrade Service)
echo.
echo.
echo [1/5] --------------------- Upgrading FUS firmware ---------------------- 
%STM32_PROGRAMMER% %PROG_ARGS% mode=UR -ob nSWboot0=1 nboot1=1 nboot0=0 -fwupgrade %FUS_BIN% 0x080EC000 firstinstall=0
if errorlevel 1 (
    echo FUS upgrade failed!
    echo Possible solutions:
    echo 1. Power cycle the board and try again
    echo 2. Check if another debugger is connected
    echo 3. Verify your FUS bin file is correct
    pause
    exit /b 1
)

:: Step 2: Verify FUS version
echo.
echo.
echo [2/5] ----------------------- Verifying FUS version ----------------------- 
%STM32_PROGRAMMER% %PROG_ARGS% -fusgetstate
if errorlevel 1 (
    echo FUS version verification failed!
    pause
    exit /b 1
)

:: Step 3: Upgrade Wireless Stack
echo.
echo.
echo [3/5] ----------------------- Upgrading Wireless Stack ----------------------- 
%STM32_PROGRAMMER% %PROG_ARGS% mode=UR -ob nSWboot0=1 nboot1=1 nboot0=0 -fwupgrade %WIRELESS_STACK_BIN% 0x080CE000  firstinstall=1
if errorlevel 1 (
    echo Wireless Stack upgrade failed!
    pause
    exit /b 1
)

:: Step 4: start Wireless Stack version
echo.
echo.
echo [4/5] ------------------------ start Wireless Stack ------------------------
%STM32_PROGRAMMER% %PROG_ARGS% -startwirelessstack
if errorlevel 1 (
    echo Wireless Stack start failed!
    pause
    exit /b 1
)

:: Step 5: Program & Verify Application
echo.
echo.
echo [5/5] ----------------------- Programming Application ----------------------- 
::%STM32_PROGRAMMER% %PROG_ARGS% -hardRst

%STM32_PROGRAMMER% %PROG_ARGS% mode=UR -ob nSWboot0=1 nboot1=1 nboot0=0  -d %APPLICATION_BIN% 0x08000000 -v -s
if errorlevel 1 (
    echo Application programming failed!
    pause
    exit /b 1
)

echo.
echo ==============================================
echo Firmware upgrade completed successfully!
echo ==============================================
echo.
pause