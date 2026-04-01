@echo off
mode con cp select=437 >nul
setlocal EnableDelayedExpansion

rem Define MAC address
set mac_addr=11:22:33:aa:bb:cc

rem Define IPv4 settings
set ipv4_addr=192.168.1.2/24
set ipv4_gateway=192.168.1.1

rem Define IPv6 settings
set ipv6_addr=2222::2/64
set ipv6_gateway=2222::1

rem Disable IPv6 address randomization
netsh interface ipv6 set global randomizeidentifiers=disabled

rem Find network interface ID based on MAC address
if defined mac_addr (
    for /f %%a in ('wmic nic where "MACAddress='%mac_addr%'" get InterfaceIndex ^| findstr [0-9]') do set id=%%a
    if defined id (
        rem Configure static IPv4 address and gateway
        if defined ipv4_addr if defined ipv4_gateway (
            netsh interface ipv4 set address !id! static !ipv4_addr! gateway=!ipv4_gateway! gwmetric=0
        )

        rem Set static IPv4 DNS to Cloudflare and Google
        netsh interface ipv4 set dnsserver !id! static 1.1.1.1 primary
        netsh interface ipv4 add dnsserver !id! 8.8.8.8 index=2

        rem Configure IPv6 address and gateway
        if defined ipv6_addr if defined ipv6_gateway (
            netsh interface ipv6 set address !id! !ipv6_addr!
            netsh interface ipv6 add route ::/0 !id! !ipv6_gateway!
        )

        rem Set static IPv6 DNS to Cloudflare and Google
        netsh interface ipv6 set dnsserver !id! static 2606:4700:4700::1111 primary
        netsh interface ipv6 add dnsserver !id! 2001:4860:4860::8888 index=2
    )
)

#REM Download and install Qemu Agent
#powershell -Command "(New-Object System.Net.WebClient).DownloadFile('https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.262-2/virtio-win-guest-tools.exe', 'C:\Windows\Temp\virtio-win-guest-tools.exe')" <NUL
#cmd /c C:\Windows\Temp\virtio-win-guest-tools.exe /quiet /norestart
#del C:\Windows\Temp\virtio-win-guest-tools.exe

#REM Remove OneDrive
3set onedrive=%SystemRoot%\SysWOW64\OneDriveSetup.exe
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

#REM Remove memory dump files
#del /q /f "C:\Windows\*.DMP"
#for /d %%D in ("C:\Windows\Minidump") do rd /s /q "%%D"

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
