@echo off
for /f "tokens=2 delims=:" %%c in ('chcp') do set "OLDCP=%%c"
chcp 65001 >nul
:: =====================================================================
::  eco_off.bat  -  ВЫКЛЮЧИТЬ ЭКОНОМ-РЕЖИМ, вернуть всё как было
::
::  Читает C:\ProgramData\EcoMode\state.txt (создаётся eco_on.bat):
::   - возвращает исходную схему электропитания и удаляет схему "Eco"
::   - возвращает яркость экрана
::   - возвращает тип запуска служб и запускает те, что были автоматическими
::   - возвращает политики: фоновые приложения Store, виджеты, Edge и Chrome, телеметрия
::   - включает обратно задания планировщика, которые были включены
::   - Защитник Windows: возвращает защиту в реальном времени и настройки проверок
::  Если файла состояния нет - делает безопасный возврат к умолчаниям.
::
::  Запуск: двойной клик, права администратора запрашиваются автоматически.
::  Файл должен быть сохранён в кодировке UTF-8 без BOM.
:: =====================================================================
setlocal EnableDelayedExpansion

set "ECO_GUID=ec0ec0ec-0000-4000-8000-0000000ec0ba"
set "BALANCED=381b4222-f694-41f0-9685-ff5bb260df2e"
set "STATE_DIR=%ProgramData%\EcoMode"
set "STATE=%STATE_DIR%\state.txt"
set "REG_BG=HKLM\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy"
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
rem   список политик нужен только если файл состояния не найден (тогда они удаляются)
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
rem   список заданий нужен только если файл состояния не найден (тогда они включаются)
set "SERVICES=WSearch SysMain DiagTrack WerSvc DoSvc wuauserv InstallService MapsBroker WMPNetworkSvc XblAuthManager XblGameSave XboxNetApiSvc XboxGipSvc edgeupdate edgeupdatem gupdate gupdatem"
rem   список нужен только если файл состояния не найден

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

title Eco mode - OFF
echo.
echo ====================== ЭКОНОМ-РЕЖИМ: ВЫКЛЮЧЕНИЕ ======================
echo.

set "FALLBACK="
set "ORIG_SCHEME="
set "ORIG_BRIGHT="
set "BGAPPS="
set "DEF_CPU="
if exist "%STATE%" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%STATE%") do set "%%a=%%b"
) else (
    echo [i] Файл состояния не найден: эконом-режим не включался или уже выключен.
    echo     Выполняю безопасный возврат к настройкам по умолчанию.
    set "FALLBACK=1"
)
if not defined ORIG_SCHEME set "ORIG_SCHEME=%BALANCED%"
if /i "%ORIG_SCHEME%"=="%ECO_GUID%" set "ORIG_SCHEME=%BALANCED%"

:: ---------------------- 1. Схема электропитания ----------------------
echo [1/5] Возвращаю исходную схему электропитания
powercfg /setactive %ORIG_SCHEME% >nul 2>&1 || (
    echo       Исходная схема не найдена, включаю "Сбалансированную"
    powercfg /setactive %BALANCED% >nul 2>&1
)
powercfg /delete %ECO_GUID% >nul 2>&1

:: ---------------------- 2. Яркость ----------------------
if not defined ORIG_BRIGHT (
    echo [2/5] Яркость: исходное значение не сохранено, остаётся значение схемы питания
    goto :services
)
echo [2/5] Яркость экрана: %ORIG_BRIGHT%%%
powershell -NoProfile -Command "Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightnessMethods -ErrorAction SilentlyContinue | ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName WmiSetBrightness -Arguments @{Timeout=[uint32]1; Brightness=[byte]%ORIG_BRIGHT%} | Out-Null }"

:: ---------------------- 3. Службы ----------------------
:services
echo [3/5] Восстанавливаю службы
if defined FALLBACK goto :services_fallback
for /f "usebackq tokens=1,2,3 delims==;" %%a in (`findstr /b "SVC_" "%STATE%"`) do (
    set "name=%%a"
    set "name=!name:SVC_=!"
    call :svc_restore "!name!" "%%b" "%%c"
)
goto :services_done

:services_fallback
for %%s in (%SERVICES%) do call :svc_default %%s

:services_done

:: ---------------------- 4. Политики: фоновые приложения, виджеты, браузеры ----------------------
echo [4/7] Возвращаю политики: фоновые приложения Store, виджеты, Edge и Chrome
if defined FALLBACK goto :policies_fallback
for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b "POL" "%STATE%"`) do (
    for /f "tokens=1-3 delims=;" %%k in ("%%b") do (
        if /i "%%m"=="NONE" (
            reg delete "%%k" /v "%%l" /f >nul 2>&1
        ) else (
            reg add "%%k" /v "%%l" /t REG_DWORD /d %%m /f >nul 2>&1
        )
    )
)
if not defined BGAPPS goto :policies_done
rem  файл состояния от старой версии eco_on.bat: одна политика фоновых приложений
if /i "%BGAPPS%"=="NONE" (
    reg delete "%REG_BG%" /v LetAppsRunInBackground /f >nul 2>&1
) else (
    reg add "%REG_BG%" /v LetAppsRunInBackground /t REG_DWORD /d %BGAPPS% /f >nul 2>&1
)
goto :policies_done
:policies_fallback
for /l %%i in (1,1,%POL_COUNT%) do (
    for /f "tokens=1-3 delims=;" %%k in ("!POL%%i!") do reg delete "%%k" /v "%%l" /f >nul 2>&1
)
:policies_done

:: ---------------------- 5. Задания планировщика ----------------------
echo [5/7] Включаю обратно задания планировщика
if defined FALLBACK goto :tasks_fallback
powershell -NoProfile -Command "Get-Content -LiteralPath '%STATE%' | Where-Object { $_ -like 'TASK=*' } | ForEach-Object { $v = $_.Substring(5); $i = $v.LastIndexOf(';'); $t = $v.Substring(0, $i); $s = $v.Substring($i + 1); if ($s -ne 'Disabled') { $j = $t.LastIndexOf('\'); Enable-ScheduledTask -TaskPath $t.Substring(0, $j + 1) -TaskName $t.Substring($j + 1) -ErrorAction SilentlyContinue | Out-Null; Write-Host ('      - ' + $t) } }"
goto :tasks_done
:tasks_fallback
powershell -NoProfile -Command "foreach ($t in '%TASKS%' -split ';') { $i = $t.LastIndexOf('\'); Enable-ScheduledTask -TaskPath $t.Substring(0, $i + 1) -TaskName $t.Substring($i + 1) -ErrorAction SilentlyContinue | Out-Null }"
:tasks_done

:: ---------------------- 6. Защитник Windows ----------------------
echo [6/7] Защитник Windows: возвращаю защиту в реальном времени и настройки проверок
if defined DEF_CPU goto :defender_restore
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue; Set-MpPreference -ScanAvgCPULoadFactor 50 -ErrorAction SilentlyContinue; Set-MpPreference -ScanOnlyIfIdleEnabled $true -ErrorAction SilentlyContinue; Set-MpPreference -DisableCatchupQuickScan $true -ErrorAction SilentlyContinue; Set-MpPreference -DisableCatchupFullScan $true -ErrorAction SilentlyContinue; Set-MpPreference -ScanScheduleDay 0 -ErrorAction SilentlyContinue"
goto :defender_done
:defender_restore
powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring ([bool]%DEF_RT%) -ErrorAction SilentlyContinue; Set-MpPreference -ScanAvgCPULoadFactor %DEF_CPU% -ErrorAction SilentlyContinue; Set-MpPreference -ScanOnlyIfIdleEnabled ([bool]%DEF_IDLE%) -ErrorAction SilentlyContinue; Set-MpPreference -DisableCatchupQuickScan ([bool]%DEF_CQ%) -ErrorAction SilentlyContinue; Set-MpPreference -DisableCatchupFullScan ([bool]%DEF_CF%) -ErrorAction SilentlyContinue; Set-MpPreference -ScanScheduleDay %DEF_DAY% -ErrorAction SilentlyContinue"
:defender_done

:: ---------------------- 7. Файл состояния ----------------------
echo [7/7] Убираю файл состояния
if exist "%STATE%" move /y "%STATE%" "%STATE_DIR%\state.last.txt" >nul

echo.
echo ====================== ГОТОВО: обычный режим возвращён ======================
echo   Активная схема:
powercfg /getactivescheme
echo.
pause
endlocal
chcp %OLDCP% >nul
exit /b 0

:: ---------------------- подпрограммы ----------------------
:svc_restore
rem  %1 = имя службы, %2 = Start (0x2 auto, 0x3 demand, 0x4 disabled), %3 = DelayedAutostart
set "svc=%~1"
set "st=%~2"
set "dl=%~3"
set "mode="
if "%st%"=="0x2" set "mode=auto"
if "%st%"=="0x2" if "%dl%"=="0x1" set "mode=delayed-auto"
if "%st%"=="0x3" set "mode=demand"
if "%st%"=="0x4" set "mode=disabled"
if not defined mode exit /b 0
sc config %svc% start= %mode% >nul 2>&1
if "%st%"=="0x2" sc start %svc% >nul 2>&1
echo       - %svc% (%mode%)
exit /b 0

:svc_default
rem  без файла состояния: трогаем только службы из списка, которые сейчас отключены
set "svc=%~1"
set "cur="
for /f "tokens=3" %%v in ('reg query "HKLM\SYSTEM\CurrentControlSet\Services\%svc%" /v Start 2^>nul ^| findstr /i "REG_DWORD"') do set "cur=%%v"
if not "%cur%"=="0x4" exit /b 0
set "mode=demand"
if /i "%svc%"=="WSearch"   set "mode=delayed-auto"
if /i "%svc%"=="SysMain"   set "mode=auto"
if /i "%svc%"=="DiagTrack" set "mode=auto"
sc config %svc% start= %mode% >nul 2>&1
if not "%mode%"=="demand" sc start %svc% >nul 2>&1
echo       - %svc% (%mode%, значение по умолчанию)
exit /b 0
