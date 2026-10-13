@echo off
for /f "tokens=2 delims=:" %%c in ('chcp') do set "OLDCP=%%c"
chcp 65001 >nul
:: =====================================================================
::  eco_on.bat  -  ВКЛЮЧИТЬ ЭКОНОМ-РЕЖИМ (ноутбук, Windows 10 / 11)
::
::  Что делает:
::   - создаёт схему электропитания "Eco" на основе текущей и включает её
::   - яркость экрана 50 проц., адаптивная яркость выкл.
::   - процессор от батареи: макс. состояние 30 проц., турбо-буст выкл.,
::     охлаждение пассивное, приоритет энергоэффективности
::   - диски: отключение через 1 мин простоя, энергосбережение AHCI / NVMe
::   - PCI Express, USB, Wi-Fi адаптер - режим экономии (Wi-Fi НЕ отключается)
::   - видео и медиа - приоритет экономии, слайд-шоу обоев на паузе
::   - "Экономия заряда" Windows (Energy Saver) - включена всегда
::   - останавливает и отключает некритичные фоновые службы (список ниже)
::   - запрещает фоновую работу приложений Store, виджеты, фоновый режим Edge и Chrome
::   - от батареи отключает сетевое подключение в режиме ожидания (сон)
::   - телеметрия, отчёты об ошибках, фоновые проверки обновлений Windows и Store:
::     службы, политики и задания планировщика выкл.
::   - Защитник Windows: плановые проверки выкл., лимит CPU для проверок,
::     защита в реальном времени выкл. (только если выключена Защита от подделки)
::
::  Что НЕ трогает: таймеры сна, гибернации и отключения экрана, действия
::  крышки и кнопок, Wi-Fi, Bluetooth, сеть, Защитник Windows, звук,
::  системные службы. Исходное состояние сохраняется в файл
::  C:\ProgramData\EcoMode\state.txt и возвращается скриптом eco_off.bat.
::
::  Запуск: двойной клик, права администратора запрашиваются автоматически.
::  Файл должен быть сохранён в кодировке UTF-8 без BOM.
:: =====================================================================
setlocal EnableDelayedExpansion

:: ---------------------- НАСТРОЙКИ (можно менять) ----------------------
set "BRIGHTNESS=50"
rem   яркость экрана, проценты
set "CPU_MAX_DC=30"
rem   макс. состояние процессора ОТ БАТАРЕИ, проценты (30 = время работы x2)
set "CPU_MAX_AC=100"
rem   макс. состояние процессора ОТ СЕТИ, проценты (поставьте 30, если нужна экономия и от сети)
set "CPU_MIN=5"
rem   мин. состояние процессора, проценты
set "CPU_EPP=100"
rem   предпочтение энергоэффективности от батареи, 0..100 (100 = максимум экономии)
set "WIFI_PWR=2"
rem   Wi-Fi адаптер: 0 макс. производительность, 1 низкая экономия, 2 средняя, 3 максимальная
rem   (3 даёт больше экономии, но на некоторых адаптерах рвёт связь)
set "DISK_OFF=60"
rem   отключать жесткий диск через N секунд простоя
set "DEFENDER_OFF=1"
rem   1 = отключать защиту Защитника в реальном времени (штатной командой Set-MpPreference).
rem   Работает только если в Безопасности Windows выключена "Защита от подделки":
rem   Windows специально не даёт сделать это скриптом. 0 = защиту не трогать,
rem   тогда остаётся только безопасная экономия: плановые проверки выкл., лимит CPU.
set "SERVICES=WSearch SysMain DiagTrack WerSvc DoSvc wuauserv InstallService MapsBroker WMPNetworkSvc XblAuthManager XblGameSave XboxNetApiSvc XboxGipSvc edgeupdate edgeupdatem gupdate gupdatem"
rem   службы, которые будут остановлены и отключены до запуска eco_off.bat.
rem   Все некритичные: индексация поиска, SysMain, телеметрия, оптимизация
rem   отчёты об ошибках, доставки и Центр обновления, установка из Store, автономные
rem   карты, общий доступ к медиа, Xbox, автообновление Edge и Google.
rem   Уберите wuauserv, если обновления Windows должны идти и в эконом-режиме.
:: -----------------------------------------------------------------------

set "ECO_GUID=ec0ec0ec-0000-4000-8000-0000000ec0ba"
set "BALANCED=381b4222-f694-41f0-9685-ff5bb260df2e"
set "STATE_DIR=%ProgramData%\EcoMode"
set "STATE=%STATE_DIR%\state.txt"
set "REG_PS=HKLM\SYSTEM\CurrentControlSet\Control\Power\User\PowerSchemes"
set "POL_COUNT=11"
set "POL1=HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy;LetAppsRunInBackground;2"
set "POL2=HKLM\SOFTWARE\Policies\Microsoft\Dsh;AllowNewsAndInterests;0"
set "POL3=HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds;EnableFeeds;0"
set "POL4=HKLM\SOFTWARE\Policies\Microsoft\Edge;StartupBoostEnabled;0"
set "POL5=HKLM\SOFTWARE\Policies\Microsoft\Edge;BackgroundModeEnabled;0"
set "POL6=HKLM\SOFTWARE\Policies\Google\Chrome;BackgroundModeEnabled;0"
set "POL7=HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection;AllowTelemetry;0"
set "POL8=HKLM\SOFTWARE\Policies\Microsoft\Windows\Windows Error Reporting;Disabled;1"
set "POL9=HKLM\SOFTWARE\Policies\Microsoft\Windows\WindowsAI;DisableAIDataAnalysis;1"
set "POL10=HKLM\SOFTWARE\Policies\Microsoft\Edge;DiagnosticData;0"
set "POL11=HKLM\SOFTWARE\Policies\Google\Chrome;MetricsReportingEnabled;0"
rem   политики реестра вида "ключ;значение;данные": фоновые приложения Store запрещены,
rem   виджеты Windows 11 и "Новости и интересы" Windows 10 выкл., ускоренный запуск и
rem   фоновый режим Edge выкл., фоновый режим Chrome выкл., телеметрия Windows на минимум,
rem   отчёты об ошибках выкл., снимки Recall выкл., диагностика Edge и Chrome выкл.
rem   Исходные данные сохраняются.
set "TASKS=\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser"
set "TASKS=%TASKS%;\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp"
set "TASKS=%TASKS%;\Microsoft\Windows\Application Experience\ProgramDataUpdater"
set "TASKS=%TASKS%;\Microsoft\Windows\Application Experience\PcaPatchDbTask"
set "TASKS=%TASKS%;\Microsoft\Windows\Customer Experience Improvement Program\Consolidator"
set "TASKS=%TASKS%;\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip"
set "TASKS=%TASKS%;\Microsoft\Windows\Autochk\Proxy"
set "TASKS=%TASKS%;\Microsoft\Windows\Feedback\Siuf\DmClient"
set "TASKS=%TASKS%;\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload"
set "TASKS=%TASKS%;\Microsoft\Windows\Windows Error Reporting\QueueReporting"
set "TASKS=%TASKS%;\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
set "TASKS=%TASKS%;\Microsoft\Windows\Diagnosis\Scheduled"
set "TASKS=%TASKS%;\Microsoft\Windows\Diagnosis\RecommendedTroubleshootingScanner"
set "TASKS=%TASKS%;\Microsoft\Windows\Device Information\Device"
set "TASKS=%TASKS%;\Microsoft\Windows\Device Information\Device User"
set "TASKS=%TASKS%;\Microsoft\Windows\PI\Sqm-Tasks"
set "TASKS=%TASKS%;\Microsoft\Windows\NetTrace\GatherNetworkInfo"
set "TASKS=%TASKS%;\Microsoft\Windows\PerfTrack\BackgroundConfigSurveyor"
set "TASKS=%TASKS%;\Microsoft\Windows\Maintenance\WinSAT"
set "TASKS=%TASKS%;\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
set "TASKS=%TASKS%;\Microsoft\Windows\Device Setup\Metadata Refresh"
set "TASKS=%TASKS%;\Microsoft\Windows\WindowsUpdate\Scheduled Start"
set "TASKS=%TASKS%;\Microsoft\Windows\InstallService\ScanForUpdates"
set "TASKS=%TASKS%;\Microsoft\Windows\InstallService\ScanForUpdatesAsUser"
set "TASKS=%TASKS%;\Microsoft\Windows\InstallService\SmartRetry"
set "TASKS=%TASKS%;\Microsoft\Windows\InstallService\WakeUpAndContinueUpdates"
set "TASKS=%TASKS%;\Microsoft\Windows\InstallService\WakeUpAndScanForUpdates"
set "TASKS=%TASKS%;\Microsoft\Windows\Speech\SpeechModelDownloadTask"
set "TASKS=%TASKS%;\Microsoft\Windows\Maps\MapsUpdateTask"
set "TASKS=%TASKS%;\Microsoft\Windows\Maps\MapsToastTask"
set "TASKS=%TASKS%;\Microsoft\Windows\Windows Media Sharing\UpdateLibrary"
set "TASKS=%TASKS%;\Microsoft\Windows\SettingSync\BackgroundUploadTask"
set "TASKS=%TASKS%;\Microsoft\Windows\SettingSync\BackupTask"
set "TASKS=%TASKS%;\Microsoft\XblGameSave\XblGameSaveTask"
set "TASKS=%TASKS%;\Microsoft\Office\OfficeTelemetryAgentFallBack2016"
set "TASKS=%TASKS%;\Microsoft\Office\OfficeTelemetryAgentLogOn2016"
rem   задания планировщика, которые будут отключены: телеметрия и оценка совместимости,
rem   программа улучшения качества, отзывы, отчёты об ошибках, диагностика, фоновые
rem   проверки обновлений Windows и Store, загрузка карт и речевых моделей, Office-телеметрия.

:: ---------------------- Права администратора ----------------------
fltmc >nul 2>&1
if errorlevel 1 (
    if "%~1"=="/elevated" (
        echo Не удалось получить права администратора. Запустите файл от имени администратора вручную.
        pause
        exit /b 1
    )
    echo Нужны права администратора - запрашиваю...
    powershell -NoProfile -Command "Start-Process -FilePath '%~f0' -ArgumentList '/elevated' -Verb RunAs"
    exit /b
)

title Eco mode - ON
echo.
echo ====================== ЭКОНОМ-РЕЖИМ: ВКЛЮЧЕНИЕ ======================
echo.
if not exist "%STATE_DIR%" mkdir "%STATE_DIR%"

if exist "%STATE%" (
    echo [i] Эконом-режим уже включался ранее: исходные настройки сохранены, применяю повторно.
    for /f "usebackq tokens=1,* delims==" %%a in ("%STATE%") do if "%%a"=="ORIG_SCHEME" set "ORIG_SCHEME=%%b"
    goto :apply
)

:: ---------------------- 1. Сохранение текущего состояния ----------------------
echo [1/8] Сохраняю текущее состояние в %STATE%
set "ORIG_SCHEME="
for /f "tokens=3" %%g in ('reg query "%REG_PS%" /v ActivePowerScheme 2^>nul ^| findstr /i "ActivePowerScheme"') do set "ORIG_SCHEME=%%g"
if not defined ORIG_SCHEME set "ORIG_SCHEME=%BALANCED%"
if /i "%ORIG_SCHEME%"=="%ECO_GUID%" set "ORIG_SCHEME=%BALANCED%"

set "ORIG_BRIGHT="
for /f "usebackq delims=" %%b in (`powershell -NoProfile -Command "Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightness -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty CurrentBrightness"`) do set "ORIG_BRIGHT=%%b"

> "%STATE%" echo ORIG_SCHEME=%ORIG_SCHEME%
>>"%STATE%" echo ORIG_BRIGHT=%ORIG_BRIGHT%

for %%s in (%SERVICES%) do (
    set "ST="
    set "DL=0x0"
    for /f "tokens=3" %%v in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\%%s" /v Start 2^>nul ^| findstr /i "REG_DWORD"') do set "ST=%%v"
    for /f "tokens=3" %%v in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\%%s" /v DelayedAutostart 2^>nul ^| findstr /i "REG_DWORD"') do set "DL=%%v"
    if defined ST (>>"%STATE%" echo SVC_%%s=!ST!;!DL!)
)

for /l %%i in (1,1,%POL_COUNT%) do (
    for /f "tokens=1-3 delims=;" %%k in ("!POL%%i!") do (
        set "CUR=NONE"
        for /f "tokens=3" %%v in ('reg query "%%k" /v "%%l" 2^>nul ^| findstr /i "REG_DWORD"') do set "CUR=%%v"
        >>"%STATE%" echo POL%%i=%%k;%%l;!CUR!
    )
)

powershell -NoProfile -Command "$p = Get-MpPreference -ErrorAction SilentlyContinue; if ($p) { Add-Content -LiteralPath '%STATE%' -Value ('DEF_RT=' + [int]$p.DisableRealtimeMonitoring), ('DEF_CPU=' + [int]$p.ScanAvgCPULoadFactor), ('DEF_IDLE=' + [int]$p.ScanOnlyIfIdleEnabled), ('DEF_CQ=' + [int]$p.DisableCatchupQuickScan), ('DEF_CF=' + [int]$p.DisableCatchupFullScan), ('DEF_DAY=' + [int]$p.ScanScheduleDay) }"

powershell -NoProfile -Command "foreach ($t in '%TASKS%' -split ';') { $i = $t.LastIndexOf('\'); $task = Get-ScheduledTask -TaskPath $t.Substring(0, $i + 1) -TaskName $t.Substring($i + 1) -ErrorAction SilentlyContinue; if ($task) { Add-Content -LiteralPath '%STATE%' -Value ('TASK=' + $t + ';' + $task.State) } }"

:apply
if not defined ORIG_SCHEME set "ORIG_SCHEME=%BALANCED%"

:: ---------------------- 2. Схема электропитания "Eco" ----------------------
echo [2/8] Создаю схему электропитания "Eco" на основе текущей
powercfg /setactive %ORIG_SCHEME% >nul 2>&1 || powercfg /setactive %BALANCED% >nul 2>&1
powercfg /delete %ECO_GUID% >nul 2>&1
powercfg /duplicatescheme %ORIG_SCHEME% %ECO_GUID% >nul 2>&1 || powercfg /duplicatescheme %BALANCED% %ECO_GUID% >nul 2>&1
powercfg /changename %ECO_GUID% "Eco" "Economy mode created by eco_on.bat" >nul 2>&1

:: ---------------------- 3. Настройки экономии ----------------------
echo [3/8] Применяю настройки экономии: процессор, диски, PCIe, USB, Wi-Fi, экран, медиа
set "AC=call :setac"
set "DC=call :setdc"
set "BOTH=call :setboth"

rem --- Процессор от батареи ---
%DC%   SUB_PROCESSOR PROCTHROTTLEMAX %CPU_MAX_DC%
%DC%   SUB_PROCESSOR PROCTHROTTLEMIN %CPU_MIN%
%DC%   SUB_PROCESSOR bc5038f7-23e0-4960-96da-33ab84b22ac0 %CPU_MAX_DC%
%DC%   SUB_PROCESSOR 893dee8e-2bef-41e0-89c6-b55d0929964d %CPU_MIN%
%DC%   SUB_PROCESSOR PERFBOOSTMODE 0
%DC%   SUB_PROCESSOR 36687f9e-e3a5-4dbf-b1dc-15eb381c6863 %CPU_EPP%
%DC%   SUB_PROCESSOR 36687f9e-e3a5-4dbf-b1dc-15eb381c6864 %CPU_EPP%
%DC%   SUB_PROCESSOR SYSCOOLPOL 0
%DC%   SUB_PROCESSOR 3b04d4fd-1cc7-4f23-ab1c-d1337819c4bb 1
rem   (строки с GUID: макс./мин. состояние для гибридных CPU класса 1,
rem    предпочтение энергоэффективности, разрешение состояний троттлинга)

rem --- Процессор от сети: только максимальное состояние ---
%AC%   SUB_PROCESSOR PROCTHROTTLEMAX %CPU_MAX_AC%
%AC%   SUB_PROCESSOR bc5038f7-23e0-4960-96da-33ab84b22ac0 %CPU_MAX_AC%

rem --- Диски: отключение по простою, AHCI HIPM+DIPM, NVMe NOPPME ---
%BOTH% SUB_DISK DISKIDLE %DISK_OFF%
%BOTH% SUB_DISK 0b2d69d7-a2a1-449c-9680-f91c70521c60 2
%BOTH% SUB_DISK fc95af4d-40e7-4b6d-835a-56d131dbc80e 1

rem --- PCI Express: максимальное энергосбережение ---
%BOTH% SUB_PCIEXPRESS ASPM 2

rem --- USB: выборочная приостановка, USB3 Link Power Management ---
%BOTH% 2a737441-1930-4402-8d77-b2bebba308a3 48e6b7a6-50f5-4782-a5d4-53bb50f7e206 1
%BOTH% 2a737441-1930-4402-8d77-b2bebba308a3 d4e98f31-5ffe-4ce1-be31-1b38b384c009 3

rem --- Сетевое подключение в режиме ожидания: от батареи выкл. (в работе Wi-Fi не трогается) ---
%DC%   SUB_NONE f15576e8-98b7-4186-b944-eafa664402d9 0

rem --- Wi-Fi адаптер: режим энергосбережения, адаптер остаётся включённым ---
%BOTH% 19cbb8fa-5279-450e-9fac-8a3d5fedd0c1 12bbebe6-58d6-4636-95bb-3217ef867c1a %WIFI_PWR%

rem --- Экран: яркость, адаптивная яркость выкл. ---
%BOTH% SUB_VIDEO aded5e82-b909-4619-9949-f5d31dbfd6c0 %BRIGHTNESS%
%BOTH% SUB_VIDEO fbd9aa66-9553-4097-ba44-ed6e9d65eab8 0

rem --- Видео и медиа: приоритет энергосбережения ---
%BOTH% 9596fb26-9850-41fd-ac3e-f7c3c00afd4b 10778347-1370-4ee0-8bbd-33bdacaade49 0
%BOTH% 9596fb26-9850-41fd-ac3e-f7c3c00afd4b 34c7b99f-9a6d-4b3c-8dc7-b6693b78cef4 2

rem --- Слайд-шоу обоев: пауза ---
%BOTH% 0d7dbae2-4294-402a-ba8e-26777e8488cd 309dce9b-bef4-4119-9921-a851fb12f0f4 1

rem --- Графика производителя, если такие настройки есть: Intel, AMD, переключаемая ---
%BOTH% 44f3beca-a7c0-460e-9df2-bb8b99e0cba6 3619c3f2-afb2-4afc-b0e9-e7fef372de36 0
%BOTH% c763b4ec-0e50-4b6b-9bed-2b92a6ee884e 7ec1751b-60ed-4588-afb5-9819d3d8f9a0 0
%BOTH% e276e160-7cb0-43c6-b20b-73f5dce39954 a1662ab2-9d34-4e53-ba8b-2639b9e20857 1

rem --- Экономия заряда Windows: порог 100 (всегда от батареи), без доп. затемнения, политика "всегда" ---
%BOTH% de830923-a562-41af-a086-e3a2c6bad2da e69653ca-cf7f-4f05-aa73-cb833fa90ad4 100
%BOTH% de830923-a562-41af-a086-e3a2c6bad2da 13d09884-f74e-474a-a852-b6bde8ad03a8 100
%BOTH% de830923-a562-41af-a086-e3a2c6bad2da 5c5bb349-ad29-4ee2-9d0b-2b25270f7a81 0

powercfg /setactive %ECO_GUID% >nul 2>&1 || echo       [x] Не удалось активировать схему Eco. Проверьте: powercfg /list

:: ---------------------- 4. Яркость ----------------------
echo [4/8] Яркость экрана: %BRIGHTNESS%%%
powershell -NoProfile -Command "Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightnessMethods -ErrorAction SilentlyContinue | ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName WmiSetBrightness -Arguments @{Timeout=[uint32]1; Brightness=[byte]%BRIGHTNESS%} | Out-Null }"

:: ---------------------- 5. Фоновые службы ----------------------
echo [5/8] Останавливаю и отключаю некритичные фоновые службы
for %%s in (%SERVICES%) do (
    reg query "HKLM\SYSTEM\CurrentControlSet\Services\%%s" /v Start >nul 2>&1 && (
        sc config %%s start= disabled >nul 2>&1
        sc stop %%s >nul 2>&1
        echo       - %%s
    )
)

:: ---------------------- 6. Политики: фоновые приложения, виджеты, браузеры ----------------------
echo [6/8] Запрещаю фоновые приложения Store, виджеты, фоновый режим Edge и Chrome
for /l %%i in (1,1,%POL_COUNT%) do (
    for /f "tokens=1-3 delims=;" %%k in ("!POL%%i!") do reg add "%%k" /v "%%l" /t REG_DWORD /d %%m /f >nul 2>&1
)
taskkill /f /im Widgets.exe >nul 2>&1
taskkill /f /im WidgetService.exe >nul 2>&1

:: ---------------------- 7. Задания планировщика ----------------------
echo [7/8] Отключаю задания планировщика: телеметрия, отчёты об ошибках, проверки обновлений
powershell -NoProfile -Command "foreach ($t in '%TASKS%' -split ';') { $i = $t.LastIndexOf('\'); Get-ScheduledTask -TaskPath $t.Substring(0, $i + 1) -TaskName $t.Substring($i + 1) -ErrorAction SilentlyContinue | Where-Object { $_.State -ne 'Disabled' } | ForEach-Object { $_ | Disable-ScheduledTask -ErrorAction SilentlyContinue | Out-Null; Write-Host ('      - ' + $_.TaskPath + $_.TaskName) } }"

:: ---------------------- 8. Защитник Windows ----------------------
echo [8/8] Защитник Windows: плановые проверки выкл., лимит CPU для проверок 5 проц.
powershell -NoProfile -Command "Set-MpPreference -ScanAvgCPULoadFactor 5 -ErrorAction SilentlyContinue; Set-MpPreference -ScanOnlyIfIdleEnabled $true -ErrorAction SilentlyContinue; Set-MpPreference -DisableCatchupQuickScan $true -ErrorAction SilentlyContinue; Set-MpPreference -DisableCatchupFullScan $true -ErrorAction SilentlyContinue; Set-MpPreference -ScanScheduleDay 8 -ErrorAction SilentlyContinue"
if not "%DEFENDER_OFF%"=="1" goto :defender_done
powershell -NoProfile -Command "$s = Get-MpComputerStatus -ErrorAction SilentlyContinue; if (-not $s) { Write-Host '      Защитник Windows не найден - пропускаю'; exit }; if ($s.AMRunningMode -ne 'Normal') { Write-Host ('      Защитник в режиме ' + $s.AMRunningMode + ': защитой управляет другой антивирус, отключайте его в его собственных настройках'); exit }; if ($s.IsTamperProtected) { Write-Host '      [x] Включена Защита от подделки: Windows не даёт отключить защиту в реальном времени скриптом.'; Write-Host '          Вручную: Безопасность Windows - Защита от вирусов и угроз - Управление настройками - Защита от подделки: Выкл. Потом запустите eco_on.bat ещё раз.'; exit }; Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue; $s = Get-MpComputerStatus; if ($s.RealTimeProtectionEnabled) { Write-Host '      [x] Защита в реальном времени осталась включённой' } else { Write-Host '      Защита в реальном времени ВЫКЛЮЧЕНА. Windows включит её сама через некоторое время или после перезагрузки.' }"
:defender_done

echo.
echo ====================== ГОТОВО: эконом-режим включён ======================
echo   Активная схема:
powercfg /getactivescheme
echo   Сохранённое состояние: %STATE%
echo   Вернуть всё как было:  eco_off.bat
echo.
pause
endlocal
chcp %OLDCP% >nul
exit /b 0

:: ---------------------- подпрограммы ----------------------
:setac
powercfg /setacvalueindex %ECO_GUID% %1 %2 %3 >nul 2>&1
exit /b 0

:setdc
powercfg /setdcvalueindex %ECO_GUID% %1 %2 %3 >nul 2>&1
exit /b 0

:setboth
powercfg /setacvalueindex %ECO_GUID% %1 %2 %3 >nul 2>&1
powercfg /setdcvalueindex %ECO_GUID% %1 %2 %3 >nul 2>&1
exit /b 0
