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
::  Журнал: C:\ProgramData\EcoMode\eco.log (общий с eco_on.bat)
::
::  Запуск: двойной клик, права администратора запрашиваются автоматически.
::  Файл должен быть сохранён в кодировке UTF-8 без BOM.
:: =====================================================================
setlocal EnableDelayedExpansion

set "ECO_GUID=ec0ec0ec-0000-4000-8000-0000000ec0ba"
set "BALANCED=381b4222-f694-41f0-9685-ff5bb260df2e"
set "STATE_DIR=%ProgramData%\EcoMode"
set "STATE=%STATE_DIR%\state.txt"
set "LOG=%STATE_DIR%\eco.log"
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
rem   список служб нужен только если файл состояния не найден

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

:: ---------------------- Журнал ----------------------
title Eco mode - OFF
if not exist "%STATE_DIR%" mkdir "%STATE_DIR%" >nul 2>&1
if exist "%LOG%" for %%A in ("%LOG%") do if %%~zA GTR 1048576 move /y "%LOG%" "%LOG%.old" >nul 2>&1
set "ERRORS=0"
>>"%LOG%" echo.
>>"%LOG%" echo ===== eco_off.bat  %DATE% %TIME%  %COMPUTERNAME%\%USERNAME% =====
echo.
echo ====================== ЭКОНОМ-РЕЖИМ: ВЫКЛЮЧЕНИЕ ======================
echo   Журнал: %LOG%
echo.
where powershell >nul 2>&1 || call :fail PowerShell не найден, часть шагов не выполнится

set "FALLBACK="
set "ORIG_SCHEME="
set "ORIG_BRIGHT="
set "BGAPPS="
set "DEF_CPU="
if exist "%STATE%" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%STATE%") do set "%%a=%%b"
    >>"%LOG%" echo --- содержимое %STATE% ---
    >>"%LOG%" type "%STATE%"
    >>"%LOG%" echo --- конец state.txt ---
) else (
    call :say [i] Файл состояния не найден: эконом-режим не включался или уже выключен.
    call :note Выполняю безопасный возврат к настройкам по умолчанию.
    set "FALLBACK=1"
)
if not defined ORIG_SCHEME set "ORIG_SCHEME=%BALANCED%"
if /i "%ORIG_SCHEME%"=="%ECO_GUID%" set "ORIG_SCHEME=%BALANCED%"

:: ---------------------- 1. Схема электропитания ----------------------
call :say [1/7] Возвращаю исходную схему электропитания
call :try powercfg /setactive %ORIG_SCHEME%
powercfg /getactivescheme | findstr /i "%ORIG_SCHEME%" >nul || (
    call :note Исходная схема не найдена, включаю "Сбалансированную"
    call :run powercfg /setactive %BALANCED%
)
call :try powercfg /delete %ECO_GUID%
powercfg /getactivescheme | findstr /i "%ECO_GUID%" >nul && call :fail Схема Eco всё ещё активна, проверьте вывод powercfg /list

:: ---------------------- 2. Яркость ----------------------
if not defined ORIG_BRIGHT (
    call :say [2/7] Яркость: исходное значение не сохранено, остаётся значение схемы питания
    goto :services
)
call :say [2/7] Яркость экрана: %ORIG_BRIGHT% проц.
call :run powershell -NoProfile -Command "Get-CimInstance -Namespace root/wmi -ClassName WmiMonitorBrightnessMethods -ErrorAction SilentlyContinue | ForEach-Object { Invoke-CimMethod -InputObject $_ -MethodName WmiSetBrightness -Arguments @{Timeout=[uint32]1; Brightness=[byte]%ORIG_BRIGHT%} | Out-Null }"

:: ---------------------- 3. Службы ----------------------
:services
call :say [3/7] Восстанавливаю службы
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

:: ---------------------- 4. Политики: фоновые приложения, виджеты, браузеры, телеметрия ----------------------
call :say [4/7] Возвращаю политики: фоновые приложения Store, виджеты, Edge и Chrome, телеметрия
if defined FALLBACK goto :policies_fallback
for /f "usebackq tokens=1,* delims==" %%a in (`findstr /b "POL" "%STATE%"`) do (
    for /f "tokens=1-3 delims=;" %%k in ("%%b") do (
        if /i "%%m"=="NONE" (
            call :try reg delete "%%k" /v "%%l" /f
        ) else (
            call :run reg add "%%k" /v "%%l" /t REG_DWORD /d %%m /f
        )
    )
)
if not defined BGAPPS goto :policies_done
rem  файл состояния от старой версии eco_on.bat: одна политика фоновых приложений
if /i "%BGAPPS%"=="NONE" (
    call :try reg delete "%REG_BG%" /v LetAppsRunInBackground /f
) else (
    call :run reg add "%REG_BG%" /v LetAppsRunInBackground /t REG_DWORD /d %BGAPPS% /f
)
goto :policies_done
:policies_fallback
for /l %%i in (1,1,%POL_COUNT%) do (
    for /f "tokens=1-3 delims=;" %%k in ("!POL%%i!") do call :try reg delete "%%k" /v "%%l" /f
)
:policies_done

:: ---------------------- 5. Задания планировщика ----------------------
call :say [5/7] Включаю обратно задания планировщика
if defined FALLBACK goto :tasks_fallback
powershell -NoProfile -Command "function L($m) { Write-Host $m; Add-Content -LiteralPath '%LOG%' -Value $m -Encoding UTF8 }; $n = 0; Get-Content -LiteralPath '%STATE%' | Where-Object { $_ -like 'TASK=*' } | ForEach-Object { $v = $_.Substring(5); $i = $v.LastIndexOf(';'); $t = $v.Substring(0, $i); $s = $v.Substring($i + 1); if ($s -ne 'Disabled') { $j = $t.LastIndexOf('\'); try { Enable-ScheduledTask -TaskPath $t.Substring(0, $j + 1) -TaskName $t.Substring($j + 1) -ErrorAction Stop | Out-Null; $n++ } catch { L ('      [x] не удалось включить ' + $t + ': ' + $_.Exception.Message) } } }; L ('      включено заданий: ' + $n)" 2>>"%LOG%"
goto :tasks_done
:tasks_fallback
call :run powershell -NoProfile -Command "foreach ($t in '%TASKS%' -split ';') { $i = $t.LastIndexOf('\'); Enable-ScheduledTask -TaskPath $t.Substring(0, $i + 1) -TaskName $t.Substring($i + 1) -ErrorAction SilentlyContinue | Out-Null }"
:tasks_done

:: ---------------------- 6. Защитник Windows ----------------------
call :say [6/7] Защитник Windows: возвращаю защиту в реальном времени и настройки проверок
if defined DEF_CPU goto :defender_restore
call :run powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring $false -ErrorAction SilentlyContinue; Set-MpPreference -ScanAvgCPULoadFactor 50 -ErrorAction SilentlyContinue; Set-MpPreference -ScanOnlyIfIdleEnabled $true -ErrorAction SilentlyContinue; Set-MpPreference -DisableCatchupQuickScan $true -ErrorAction SilentlyContinue; Set-MpPreference -DisableCatchupFullScan $true -ErrorAction SilentlyContinue; Set-MpPreference -ScanScheduleDay 0 -ErrorAction SilentlyContinue"
goto :defender_done
:defender_restore
call :run powershell -NoProfile -Command "Set-MpPreference -DisableRealtimeMonitoring ([bool]%DEF_RT%) -ErrorAction SilentlyContinue; Set-MpPreference -ScanAvgCPULoadFactor %DEF_CPU% -ErrorAction SilentlyContinue; Set-MpPreference -ScanOnlyIfIdleEnabled ([bool]%DEF_IDLE%) -ErrorAction SilentlyContinue; Set-MpPreference -DisableCatchupQuickScan ([bool]%DEF_CQ%) -ErrorAction SilentlyContinue; Set-MpPreference -DisableCatchupFullScan ([bool]%DEF_CF%) -ErrorAction SilentlyContinue; Set-MpPreference -ScanScheduleDay %DEF_DAY% -ErrorAction SilentlyContinue"
:defender_done
powershell -NoProfile -Command "$s = Get-MpComputerStatus -ErrorAction SilentlyContinue; if ($s -and $s.AMRunningMode -eq 'Normal' -and -not $s.RealTimeProtectionEnabled) { Write-Host '      [x] Защита в реальном времени не включилась. Включите вручную: Безопасность Windows - Защита от вирусов и угроз' }" 2>>"%LOG%"

:: ---------------------- 7. Файл состояния ----------------------
call :say [7/7] Убираю файл состояния
if exist "%STATE%" call :run move /y "%STATE%" "%STATE_DIR%\state.last.txt"

:: ---------------------- Итог ----------------------
echo.
if %ERRORS%==0 (
    echo ====================== ГОТОВО: обычный режим возвращён, ошибок нет ======================
    >>"%LOG%" echo [%TIME%] ГОТОВО, ошибок нет
) else (
    echo ====================== ГОТОВО: обычный режим возвращён, ошибок: %ERRORS% ======================
    >>"%LOG%" echo [%TIME%] ГОТОВО, ошибок: %ERRORS%
    echo   Подробности в журнале: %LOG%
)
echo   Активная схема:
powercfg /getactivescheme
>>"%LOG%" powercfg /getactivescheme
>>"%LOG%" echo ===== конец eco_off.bat, ошибок: %ERRORS% =====
echo.
pause
endlocal
chcp %OLDCP% >nul
exit /b 0

:: ---------------------- подпрограммы ----------------------
:say
rem  сообщение на экран и в журнал
echo %*
>>"%LOG%" echo [%TIME%] %*
exit /b 0

:fail
rem  ошибка: счётчик, экран, журнал
set /a ERRORS+=1
echo       [x] %*
>>"%LOG%" echo [%TIME%] [x] %*
exit /b 0

:note
rem  пояснение с отступом на экран и в журнал
echo       %*
>>"%LOG%" echo [%TIME%]   %*
exit /b 0

:run
rem  выполнить команду, вывод в журнал; ошибка считается и показывается
>>"%LOG%" echo [%TIME%] ^> %*
%* >>"%LOG%" 2>&1
set "RC=!errorlevel!"
if not "!RC!"=="0" (
    set /a ERRORS+=1
    >>"%LOG%" echo [%TIME%]   ОШИБКА, код !RC!
    echo       [x] ошибка, код !RC!: %1 %2 %3 - подробности в журнале
)
exit /b 0

:try
rem  выполнить команду, вывод в журнал; ошибка допустима (служба не запущена и т.п.)
>>"%LOG%" echo [%TIME%] ^> %*
%* >>"%LOG%" 2>&1
set "RC=!errorlevel!"
if not "!RC!"=="0" (>>"%LOG%" echo [%TIME%]   пропущено, код !RC!)
exit /b 0

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
if not defined mode (
    call :note [i] %svc%: неизвестный тип запуска %st%, пропускаю
    exit /b 0
)
call :run sc config %svc% start= %mode%
if "%st%"=="0x2" call :try sc start %svc%
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
call :run sc config %svc% start= %mode%
if not "%mode%"=="demand" call :try sc start %svc%
echo       - %svc% (%mode%, значение по умолчанию)
exit /b 0
