@echo off
mode con cp select=437 >nul
setlocal EnableDelayedExpansion

rem ===== USER CONFIG =====
set mac_addr=

set ipv4_cidr=192.168.1.2/24
set ipv4_gateway=192.168.1.1

set ipv6_cidr=2222::2/64
set ipv6_gateway=2222::1
rem =======================

rem Disable IPv6 randomization
netsh interface ipv6 set global randomizeidentifiers=disabled

rem ===== PARSE IPv4 CIDR =====
for /f "tokens=1,2 delims=/" %%a in ("%ipv4_cidr%") do (
    set ipv4_addr=%%a
    set cidr=%%b
)

rem Convert CIDR → subnet mask
call :cidr_to_mask %cidr% ipv4_mask

rem ===== PARSE IPv6 CIDR =====
for /f "tokens=1,2 delims=/" %%a in ("%ipv6_cidr%") do (
    set ipv6_addr=%%a
    set ipv6_prefix=%%b
)

rem ===== FIND INTERFACE =====

rem Try MAC first (if provided)
if defined mac_addr (
    if exist "%windir%\system32\wbem\wmic.exe" (
        for /f "tokens=2 delims==" %%a in (
            'wmic nic where "MACAddress='%mac_addr%'" get InterfaceIndex /format:list ^| findstr "^InterfaceIndex=[0-9][0-9]*$"'
        ) do set id=%%a
    )

    if not defined id (
        for /f %%a in ('powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
            -Command "(Get-CimInstance Win32_NetworkAdapter | Where-Object { $_.MACAddress -eq ''%mac_addr%'' }).InterfaceIndex" ^| findstr "^[0-9][0-9]*$"'
        ) do set id=%%a
    )
)

rem Fallback: auto-pick active NIC
if not defined id (
    echo MAC not set/found, detecting active NIC...

    for /f %%a in ('powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
        -Command "(Get-NetAdapter | Where-Object { $_.Status -eq 'Up' -and $_.HardwareInterface -eq $true } | Select -First 1 -ExpandProperty ifIndex)"') do set id=%%a
)

rem Final fallback (older systems without Get-NetAdapter)
if not defined id (
    for /f %%a in ('powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
        -Command "(Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.NetEnabled -eq $true } | Select -First 1 -ExpandProperty InterfaceIndex)"') do set id=%%a
)

if not defined id (
    echo ERROR: No usable network interface found
    goto :eof
)

echo Using InterfaceIndex: %id%

rem ===== CONFIGURE IPv4 =====
if defined ipv4_addr if defined ipv4_gateway (
    netsh interface ipv4 set address %id% static %ipv4_addr% %ipv4_mask% %ipv4_gateway% 1

    rem DNS (Cloudflare + Google)
    netsh interface ipv4 set dnsservers %id% static 1.1.1.1 primary
    netsh interface ipv4 add dnsservers %id% 8.8.8.8 index=2
)

rem ===== CONFIGURE IPv6 =====
if defined ipv6_addr if defined ipv6_gateway (
    netsh interface ipv6 add address %id% %ipv6_addr%/%ipv6_prefix%
    netsh interface ipv6 add route ::/0 %id% %ipv6_gateway%

    rem DNS (Cloudflare + Google)
    netsh interface ipv6 set dnsservers %id% static 2606:4700:4700::1111 primary
    netsh interface ipv6 add dnsservers %id% 2001:4860:4860::8888 index=2
)

echo.
echo Network configuration applied successfully.
pause
goto :eof

rem ===== CIDR → SUBNET MASK FUNCTION =====
:cidr_to_mask
setlocal EnableDelayedExpansion
set bits=%1

set mask=
for %%i in (1 2 3 4) do (
    if !bits! GEQ 8 (
        set /a octet=255
        set /a bits-=8
    ) else (
        set /a octet=256 - (1 << (8 - bits))
        set bits=0
    )
    if defined mask (
        set mask=!mask!.!octet!
    ) else (
        set mask=!octet!
    )
)

endlocal & set %2=%mask%
goto :eof

#REM Download and install Qemu Agent
#powershell -Command "(New-Object System.Net.WebClient).DownloadFile('https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.262-2/virtio-win-guest-tools.exe', 'C:\Windows\Temp\virtio-win-guest-tools.exe')" <NUL
#cmd /c C:\Windows\Temp\virtio-win-guest-tools.exe /quiet /norestart
#del C:\Windows\Temp\virtio-win-guest-tools.exe

#REM Remove OneDrive
#3set onedrive=%SystemRoot%\SysWOW64\OneDriveSetup.exe
#if not exist "%onedrive%" (
#    set onedrive=%SystemRoot%\System32\OneDriveSetup.exe
#)

#taskkill /F /IM OneDrive.exe /T
#timeout /t 2 > nul
#"%onedrive%" /uninstall
#timeout /t 2 > nul

#rmdir "%USERPROFILE%\OneDrive" /S /Q
#rmdir "%LOCALAPPDATA%\Microsoft\OneDrive" /S /Q
#rmdir "%PROGRAMDATA%\Microsoft OneDrive" /S /Q
#if exist "%SYSTEMDRIVE%\OneDriveTemp" (
#   rmdir "%SYSTEMDRIVE%\OneDriveTemp" /S /Q
#)

REM Remove memory dump files
del /q /f "C:\Windows\*.DMP"
for /d %%D in ("C:\Windows\Minidump") do rd /s /q "%%D"

#REM Download and run system optimizer
#powershell -Command "(New-Object System.Net.WebClient).DownloadFile('https://install.virtfusion.net/optimize.exe', 'C:\Windows\Temp\optimize.exe')" <NUL
#cmd /c C:\Windows\Temp\optimize.exe -v -o -g -windowsupdate disable -storeapp remove-all -antivirus disable
#cmd /c C:\Windows\Temp\optimize.exe -f 3 4 5 6 9
#del C:\Windows\Temp\optimize.exe

REM Set account lockout threshold to 0 (disable)
net accounts /lockoutthreshold:0
net accounts | find /i "Lockout threshold"

rem Delete script file after execution
del "%~f0"
