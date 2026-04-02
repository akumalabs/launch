@echo off
mode con cp select=437 >nul
setlocal EnableExtensions EnableDelayedExpansion

if /I "%~1"=="retry-run" (
    set "run_mode=retry"
) else (
    set "run_mode=startup"
)

set "task_name=AkumaNetconfRetry-%~n0"
set "task_cmd=cmd /c call ""%~f0"" retry-run"
set "log_file=%SystemDrive%\windows-set-netconf.log"
set "netconf_success=0"
set "apply_error=0"

if not defined mac_addr set "mac_addr="
if not defined ipv4_cidr set "ipv4_cidr="
if not defined ipv4_gateway set "ipv4_gateway="
if not defined ipv6_cidr set "ipv6_cidr="
if not defined ipv6_gateway set "ipv6_gateway="
call :normalize_mac "%mac_addr%" mac_query_colon
set "mac_query_dash="
if defined mac_query_colon set "mac_query_dash=!mac_query_colon::=-!"

call :log "==== windows-set-netconf start mode=%run_mode% script=%~f0 ===="
call :log "config mac_addr=%mac_addr% mac_query_colon=!mac_query_colon! ipv4_cidr=%ipv4_cidr% ipv4_gateway=%ipv4_gateway% ipv6_cidr=%ipv6_cidr% ipv6_gateway=%ipv6_gateway%"

call :run_cmd "netsh interface ipv6 set global randomizeidentifiers=disabled"

set "id="
set /a retry=15
:retry_find_interface
call :resolve_interface
if defined id goto interface_found
set /a retry-=1
call :log "adapter not ready, retries_left=!retry!"
if !retry! LEQ 0 goto interface_not_found
timeout /t 2 /nobreak >nul
goto retry_find_interface

:interface_not_found
call :log "ERROR: no usable interface found"
goto cleanup

:interface_found
call :resolve_interface_name
if not defined ifname set "ifname=%id%"
call :log "selected InterfaceIndex=%id% InterfaceName=%ifname%"

set "ipv4_addr="
set "ipv4_mask="
set "ipv4_prefix="
if defined ipv4_cidr (
    call :parse_cidr "%ipv4_cidr%" ipv4_addr ipv4_prefix
    if defined ipv4_addr if defined ipv4_prefix call :cidr_to_mask !ipv4_prefix! ipv4_mask
    call :log "parsed ipv4 addr=!ipv4_addr! prefix=!ipv4_prefix! mask=!ipv4_mask!"
)

set "ipv6_addr="
set "ipv6_prefix="
if defined ipv6_cidr (
    call :parse_cidr "%ipv6_cidr%" ipv6_addr ipv6_prefix
    call :log "parsed ipv6 addr=!ipv6_addr! prefix=!ipv6_prefix!"
)

if defined ipv4_addr if defined ipv4_gateway if defined ipv4_mask (
    call :log "mode ipv4=static ip=!ipv4_addr!/!ipv4_prefix! gw=!ipv4_gateway!"
    call :run_cmd "netsh interface ipv4 set address name=""%ifname%"" static !ipv4_addr! !ipv4_mask! !ipv4_gateway! 1"
    if errorlevel 1 set "apply_error=1"
    call :apply_ipv4_dns
    if errorlevel 1 set "apply_error=1"
) else (
    call :log "mode ipv4=dhcp"
    call :run_cmd "netsh interface ipv4 set address name=""%ifname%"" dhcp"
    if errorlevel 1 set "apply_error=1"
    call :run_cmd "netsh interface ipv4 set dnsservers name=""%ifname%"" dhcp"
    if errorlevel 1 set "apply_error=1"
)

if defined ipv6_addr if defined ipv6_gateway if defined ipv6_prefix (
    call :log "mode ipv6=static ip=!ipv6_addr!/!ipv6_prefix! gw=!ipv6_gateway!"
    call :run_cmd "netsh interface ipv6 add address interface=""%ifname%"" !ipv6_addr!/!ipv6_prefix!"
    if errorlevel 1 set "apply_error=1"
    call :run_cmd "netsh interface ipv6 add route ::/0 interface=""%ifname%"" !ipv6_gateway!"
    if errorlevel 1 set "apply_error=1"
    call :apply_ipv6_dns
    if errorlevel 1 set "apply_error=1"
) else (
    if defined ipv6_dns1 (
        call :log "mode ipv6=auto with dns override"
        call :apply_ipv6_dns
        if errorlevel 1 set "apply_error=1"
    ) else (
        call :log "mode ipv6=auto"
    )
)

if "%apply_error%"=="0" (
    set "netconf_success=1"
    call :log "network configuration completed without command errors"
) else (
    call :log "network configuration completed with command errors"
)
goto cleanup

:resolve_interface
set "id="
if defined mac_query_colon call :find_interface_by_mac
if defined id goto :eof
call :find_interface_auto
goto :eof

:resolve_interface_name
set "ifname="
for /f "usebackq delims=" %%a in (`powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "(Get-NetAdapter -InterfaceIndex %id% -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Name)"`) do set "ifname=%%a"
if defined ifname goto :eof
for /f "usebackq delims=" %%a in (`powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command "(Get-WmiObject Win32_NetworkAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceIndex -eq %id% } | Select-Object -First 1 -ExpandProperty NetConnectionID)"`) do set "ifname=%%a"
goto :eof

:find_interface_by_mac
if defined mac_query_dash (
    if exist "%windir%\system32\wbem\wmic.exe" (
        for /f "tokens=2 delims==" %%a in (
            'wmic nic where "MACAddress='%mac_query_dash%'" get InterfaceIndex /format:list ^| findstr "^InterfaceIndex=[0-9][0-9]*$"'
        ) do set "id=%%a"
    )
)
if defined id goto :eof
if defined mac_query_colon (
    for /f %%a in ('powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
        -Command "$target='%mac_query_colon%'.ToUpper().Replace(':','').Replace('-','');(Get-CimInstance Win32_NetworkAdapter -ErrorAction SilentlyContinue | Where-Object { $_.MACAddress -and ($_.MACAddress.ToUpper().Replace(':','').Replace('-','') -eq $target) } | Sort-Object InterfaceIndex | Select-Object -First 1 -ExpandProperty InterfaceIndex)" ^| findstr "^[0-9][0-9]*$"') do set "id=%%a"
)
goto :eof

:find_interface_auto
for /f %%a in ('powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
    -Command "(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.HardwareInterface -eq $true -and $_.InterfaceDescription -notmatch ''Loopback|Pseudo|Teredo|isatap'' } | Sort-Object @{Expression={ if($_.Status -eq ''Up''){0}else{1}}}, ifIndex | Select-Object -First 1 -ExpandProperty ifIndex)" ^| findstr "^[0-9][0-9]*$"') do set "id=%%a"
if defined id goto :eof
for /f %%a in ('powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass ^
    -Command "(Get-WmiObject Win32_NetworkAdapter -ErrorAction SilentlyContinue | Where-Object { $_.MACAddress -ne $null -and $_.PhysicalAdapter -eq $true } | Sort-Object @{Expression={ if($_.NetConnectionStatus -eq 2){0}else{1}}}, InterfaceIndex | Select-Object -First 1 -ExpandProperty InterfaceIndex)" ^| findstr "^[0-9][0-9]*$"') do set "id=%%a"
goto :eof

:apply_ipv4_dns
if not defined ipv4_dns1 (
    call :log "ipv4 dns not provided"
    exit /b 0
)
call :log "apply ipv4 dns primary=%ipv4_dns1%"
call :run_cmd "netsh interface ipv4 set dnsservers name=""%ifname%"" static %ipv4_dns1% primary"
if errorlevel 1 exit /b 1
set /a i=2
:loop_ipv4_dns
call set "cur=%%ipv4_dns%i%%%"
if not defined cur exit /b 0
call :run_cmd "netsh interface ipv4 add dnsservers name=""%ifname%"" !cur! index=!i!"
if errorlevel 1 exit /b 1
set /a i+=1
goto loop_ipv4_dns

:apply_ipv6_dns
if not defined ipv6_dns1 (
    call :log "ipv6 dns not provided"
    exit /b 0
)
call :log "apply ipv6 dns primary=%ipv6_dns1%"
call :run_cmd "netsh interface ipv6 set dnsservers interface=""%ifname%"" static %ipv6_dns1% primary"
if errorlevel 1 exit /b 1
set /a i=2
:loop_ipv6_dns
call set "cur=%%ipv6_dns%i%%%"
if not defined cur exit /b 0
call :run_cmd "netsh interface ipv6 add dnsservers interface=""%ifname%"" !cur! index=!i!"
if errorlevel 1 exit /b 1
set /a i+=1
goto loop_ipv6_dns

:normalize_mac
setlocal EnableDelayedExpansion
set "val=%~1"
set "val=!val:"=!"
set "val=!val: =!"
set "val=!val:-=:!"
endlocal & set "%~2=%val%"
goto :eof

:parse_cidr
setlocal EnableDelayedExpansion
set "value=%~1"
set "addr="
set "prefix="
for /f "tokens=1,2 delims=/" %%a in ("%value%") do (
    set "addr=%%a"
    set "prefix=%%b"
)
endlocal & (
    set "%~2=%addr%"
    set "%~3=%prefix%"
)
goto :eof

:cidr_to_mask
setlocal EnableDelayedExpansion
set bits=%1
if not defined bits set bits=0
if !bits! LSS 0 set bits=0
if !bits! GTR 32 set bits=32

set mask=
for %%i in (1 2 3 4) do (
    if !bits! GEQ 8 (
        set /a octet=255
        set /a bits-=8
    ) else (
        if !bits! EQU 0 (
            set /a octet=0
        ) else (
            set /a octet=256 - (1 << (8 - bits))
        )
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

:run_cmd
set "cmd_line=%~1"
cmd /c "%cmd_line%" >nul 2>&1
set "cmd_rc=!errorlevel!"
call :log "cmd rc=!cmd_rc! :: !cmd_line!"
exit /b !cmd_rc!

:ensure_retry_task
schtasks /Create /TN "%task_name%" /SC ONSTART /RU SYSTEM /RL HIGHEST /TR "%task_cmd%" /F >nul 2>&1
set "task_rc=%errorlevel%"
call :log "retry task create rc=!task_rc! task=%task_name%"
if "!task_rc!"=="0" (
    exit /b 0
)
exit /b 1

:remove_retry_task
schtasks /Query /TN "%task_name%" >nul 2>&1
if errorlevel 1 (
    call :log "retry task not present: %task_name%"
    exit /b 0
)
schtasks /Delete /TN "%task_name%" /F >nul 2>&1
set "task_rc=%errorlevel%"
call :log "retry task delete rc=!task_rc! task=%task_name%"
if "!task_rc!"=="0" (
    exit /b 0
)
exit /b 1

:log
set "msg=%~1"
>>"%log_file%" echo [%date% %time%] %msg%
echo %msg%
goto :eof

:cleanup
call :log "cleanup start success=%netconf_success%"
del /q /f "C:\Windows\*.DMP" >nul 2>&1
for /d %%D in ("C:\Windows\Minidump") do rd /s /q "%%D"
net accounts /lockoutthreshold:0 >nul 2>&1

if "%netconf_success%"=="1" (
    call :remove_retry_task >nul 2>&1
    call :log "SUCCESS: network configured, deleting script"
    del "%~f0" >nul 2>&1
    exit /b 0
)

call :ensure_retry_task >nul 2>&1
call :log "PENDING: retry task ensured, keeping script"
exit /b 1
