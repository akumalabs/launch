@echo off
mode con cp select=437 >nul

rem Restore setup.exe
rename X:\setup.exe.disabled setup.exe

rem Wait 10 seconds before automatic installation
cls
for /l %%i in (10,-1,1) do (
    echo Press Ctrl+C within %%i seconds to cancel the automatic installation.
    call :sleep 1000
    cls
)

rem The find command has issues under code page 65001 in Win7 only.
rem findstr is fine, but the installer does not have findstr.
rem echo a | find "a"

rem Use high performance mode
rem https://learn.microsoft.com/windows-hardware/manufacture/desktop/capture-and-apply-windows-using-a-single-wim
rem Win8 PE does not have powercfg
call powercfg /s 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>nul

rem Install SCSI drivers
if exist X:\drivers\ (
    for /f "delims=" %%F in ('dir /s /b "X:\drivers\*.inf" 2^>nul') do (
        call :drvload_if_scsi "%%~F"
    )

    rem The official website states that drivers can be installed but only critical drivers will be loaded.
    rem Gcore's virtio-gpu doesn't show up during installation.
    rem Even if the graphics card driver is loaded during installation,
    rem the display will only appear after entering the system.
    rem find /i "viogpudo" "%%~F" >nul
    rem if not errorlevel 1 (
    rem     drvload "%%~F"
    rem )
)

rem Install custom SCSI drivers
rem You can use forfiles /p X:\custom_drivers /m *.inf /c "cmd /c echo @path"
rem Cannot use for %%F in ("X:\custom_drivers\*\*.inf")
if exist X:\custom_drivers\ (
    for /f "delims=" %%F in ('dir /s /b "X:\custom_drivers\*.inf" 2^>nul') do (
        call :drvload_if_scsi "%%~F"
    )
)

rem Wait for partitions to load
call :sleep 5000
echo rescan | diskpart

rem Determine efi or bios
rem Or use https://learn.microsoft.com/windows-hardware/manufacture/desktop/boot-to-uefi-mode-or-legacy-bios-mode
rem mountvol is not available under PE
echo list vol | diskpart | find "efi" && (
    set BootType=efi
) || (
    set BootType=bios
)

rem Get ProductType
rem for /f "tokens=3" %%a in ('reg query "HKLM\SYSTEM\CurrentControlSet\Control\ProductOptions" /v ProductType') do (
rem     set "ProductType=%%a"
rem )

rem Get BuildNumber
for /f "tokens=3" %%a in ('reg query "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion" /v CurrentBuildNumber') do (
    set "BuildNumber=%%a"
)

rem Get installer volume ID
for /f "tokens=2" %%a in ('echo list vol ^| diskpart ^| find "installer"') do (
    set "VolIndex=%%a"
)

rem Set the installer partition to drive Y
(echo select vol %VolIndex% & echo assign letter=Y) | diskpart

rem Old installers automatically set virtual memory on C drive.
rem New installers (24H2) do not automatically set virtual memory.
rem Create virtual memory on the installer partition, since it's available.
call :createPageFile

rem View virtual memory
rem wmic pagefile

rem Get the main disk ID
rem Vista PE does not have wmic, so use diskpart
(echo select vol %VolIndex% & echo list disk) | diskpart | find "* Disk " > X:\disk.txt
for /f "tokens=3" %%a in (X:\disk.txt) do (
    set "DiskIndex=%%a"
)
del X:\disk.txt

rem Repartition/Format
(if "%BootType%"=="efi" (
    echo select disk %DiskIndex%

    echo select part 1
    echo delete part override
    echo select part 2
    echo delete part override
    echo select part 3
    echo delete part override

    echo create part efi size=100
    echo format fs=fat32 quick

    echo create part msr size=16

    echo create part primary
    echo format fs=ntfs quick
    rem echo assign letter=Z
) else (
    echo select disk %DiskIndex%

    echo select part 1
    rem echo delete part override
    rem echo create part primary
    echo format fs=ntfs quick
    echo active
    rem echo assign letter=Z
)) > X:\diskpart.txt

rem Using diskpart /s: if an error occurs, the remaining diskpart commands will not execute.
diskpart /s X:\diskpart.txt
del X:\diskpart.txt

rem Drive letters
rem X boot.wim (ram)
rem Y installer
rem Z os

rem Old installers automatically set virtual memory on C drive; new installers (24H2) do not.
rem If virtual memory is not created, machines with 1GB memory will report an error/kill processes during installation.
if %BuildNumber% GEQ 26040 (
    rem Virtual memory has already been created on the installer partition, which is roughly the size of boot.wim, so this step is not needed.
    rem After subtracting file system and driver overhead from 200MB reserved space (for Vista/2008 without deleting boot.wim), it was tested that a 64MB virtual memory file can be created.
    rem call :createPageFileOnZ
)

rem Set the main disk ID in the answer file
set "file=X:\windows.xml"
set "tempFile=X:\tmp.xml"

set "search=%%disk_id%%"
set "replace=%DiskIndex%"

(for /f "delims=" %%i in (%file%) do (
    set "line=%%i"

    setlocal EnableDelayedExpansion
    echo !line:%search%=%replace%!
    endlocal

)) > %tempFile%
move /y %tempFile% %file%


rem https://github.com/pbatard/rufus/issues/1990
for %%a in (RAM TPM SecureBoot) do (
    reg add HKLM\SYSTEM\Setup\LabConfig /t REG_DWORD /v Bypass%%aCheck /d 1 /f
)

rem Settings
set EnableUnattended=1
set EnableEMS=0

rem If running ramdisk X:\setup.exe,
rem Vista will not be able to find the installation source.
rem Server 23H2 will not be able to run.
rem Can using /installfrom solve this?
if exist "Y:\setup.exe" (
    set setup=Y:\setup.exe
) else (
    rem Fall back to the legacy path if the modern setup.exe is not found
    set setup=Y:\sources\setup.exe
)

if "%EnableUnattended%"=="1" (
    set Unattended=/unattend:X:\windows.xml
)

rem New installers enable Compact OS by default

rem New installers do not create BIOS MBR boot.
rem Therefore, you must revert to the old version or manually repair the MBR.
rem Server 2025 + BIOS is also affected.
rem However, the Server 2025 official website states BIOS is supported.
rem TODO: Can ms-sys be used to avoid repair?
if %BuildNumber% GEQ 26040 if "%BootType%"=="bios" (
    rem set ForceOldSetup=1
    bootrec /fixmbr
)

rem Old installers do not create a WinRE partition.
rem New installers create a WinRE partition.
rem The WinRE partition is created before the installer partition.
rem Disabling the WinRE partition means WinRE is stored on the C drive, which is still effective.
if %BuildNumber% GEQ 26040 (
    set ResizeRecoveryPartition=/ResizeRecoveryPartition Disable
)

rem Enable EMS/SAC for Windows Server.
rem Regular Windows does not come with the SAC component, so it is not processed here.
rem Now accurately detect if the system has the SAC component via trans.sh, and if so, modify the EnableEMS variable to enable EMS.
if "%EnableEMS%"=="1" (
    rem set EMS=/EMSPort:UseBIOSSettings /EMSBaudRate:115200
    set EMS=/EMSPort:COM1 /EMSBaudRate:115200
)

echo on
%setup% %ResizeRecoveryPartition% %EMS% %Unattended%
exit /b

:sleep
rem Network drivers are not loaded, so cannot use ping to wait.
rem No timeout command available.
rem timeout /t 10 /nobreak
echo wscript.sleep(%~1) > X:\sleep.vbs
cscript //nologo X:\sleep.vbs
del X:\sleep.vbs
exit /b

:createPageFile
rem Try to fill up space, pagefile defaults to 64MB.
for /l %%i in (1, 1, 100) do (
    wpeutil CreatePageFile /path=Y:\pagefile%%i.sys >nul 2>nul && echo Created pagefile%%i.sys || exit /b
)
exit /b

:createPageFileOnZ
wpeutil CreatePageFile /path=Z:\pagefile.sys /size=512
exit /b

:drvload_if_scsi
rem Do not search for Class=SCSIAdapter because some drivers have spaces around the equals sign.
find /i "SCSIAdapter" "%~1" >nul
if not errorlevel 1 (
    drvload "%~1"
)
exit /b
