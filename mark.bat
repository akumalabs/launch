@echo off
mode con cp select=437 >nul
setlocal EnableDelayedExpansion

set confhome=https://raw.githubusercontent.com/akumalabs/launch/main

cd /d %~dp0

fltmc >nul 2>&1
if errorlevel 1 (
    echo Please run as administrator^^!
    exit /b
)

if not exist %tmp% (
    md %tmp%
)

where wmic >nul 2>nul
if errorlevel 1 (
    DISM /Online /Add-Capability /CapabilityName:WMIC
)

if not exist %tmp%\geoip (
    call :download http://dash.cloudflare.com/cdn-cgi/trace %tmp%\geoip
    if errorlevel 1 goto :download_failed
)
findstr /c:"loc=CN" %tmp%\geoip >nul
if not errorlevel 1 (
    set mirror=http://mirror.nju.edu.cn
    if defined confhome_cn (
        set confhome=!confhome_cn!
    ) else if defined github_proxy (
        echo !confhome! | findstr /c:"://raw.githubusercontent.com/" >nul
        if not errorlevel 1 (
            set confhome=!confhome:http://=https://!
            set confhome=!confhome:https://raw.githubusercontent.com=%github_proxy%!
        )
    )
) else (
    set mirror=https://mirrors.kernel.org
)

set pkgs=curl,wget,cpio,p7zip,bind-utils,ipcalc,dos2unix,binutils,jq,xz,gzip,zstd,openssl,libiconv
set tags=%tmp%\cygwin-installed-%pkgs%
if not exist "%tags%" (
    for /f "tokens=2 delims==" %%a in ('wmic os get BuildNumber /format:list ^| find "BuildNumber"') do (
        set /a BuildNumber=%%a
    )

    set CygwinEOL=1

    wmic ComputerSystem get SystemType | find "ARM" > nul
    if not errorlevel 1 (
        if !BuildNumber! GEQ 22000 (
            set CygwinEOL=0
        )
    ) else (
        wmic ComputerSystem get SystemType | find "x64" > nul
        if not errorlevel 1 (
            if !BuildNumber! GEQ 9600 (
                set CygwinEOL=0
            )
        )
    )

    if !CygwinEOL! == 1 (
        set CygwinArch=x86
        set dir=/sourceware/cygwin-archive/20221123
    ) else (
        set CygwinArch=x86_64
        set dir=/sourceware/cygwin
    )

    call :download http://www.cygwin.com/setup-!CygwinArch!.exe %tmp%\setup-cygwin.exe
    if errorlevel 1 goto :download_failed

    set site=!mirror!!dir!
    %tmp%\setup-cygwin.exe --allow-unsupported-windows ^
                           --quiet-mode ^
                           --only-site ^
                           --site !site! ^
                           --root %SystemDrive%\cygwin ^
                           --local-package-dir %tmp%\cygwin-local-package-dir ^
                           --packages %pkgs% ^
                           && type nul >"%tags%"
)

for /f %%a in ('%SystemDrive%\cygwin\bin\cygpath -ua ./') do set thisdir=%%a

if not exist kernel.sh (
    call :download_with_curl %confhome%/kernel.sh %thisdir%kernel.sh
    if errorlevel 1 goto :download_failed
    call :chmod a+x %thisdir%kernel.sh
)

%SystemDrive%\cygwin\bin\dos2unix -q "%thisdir%kernel.sh"
%SystemDrive%\cygwin\bin\bash -l -c "%thisdir%kernel.sh"

exit /b

:download
del /q "%~2" 2>nul
if exist "%~2" (echo Cannot delete %~2 & exit /b 1)
if not exist "%~2" certutil -urlcache -f -split "%~1" "%~2" >nul
if not exist "%~2" certutil -urlcache -split "%~1" "%~2" >nul
if not exist "%~2" exit /b 1
exit /b

:download_with_curl
echo Download: %~1 %~2
%SystemDrive%\cygwin\bin\curl -L "%~1" -o "%~2"
exit /b

:chmod
%SystemDrive%\cygwin\bin\chmod "%~1" "%~2"
exit /b

:download_failed
echo Download failed.
exit /b 1
