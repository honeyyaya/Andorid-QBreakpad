@echo off
chcp 65001 >nul
setlocal EnableExtensions EnableDelayedExpansion

rem =========================
rem  Breakpad Android Helper
rem  - Generate .sym from .so
rem  - Stackwalk .dmp -> report
rem =========================

set "SEP========================================="
echo %SEP%
echo   Breakpad Android Symbol + Report Generator
echo %SEP%
echo.

rem --- Always run in the directory where this .bat lives
set "WORK_DIR=%~dp0"
pushd "%WORK_DIR%" >nul

rem Optional: pass an APK path to auto-extract libs
set "APK_FILE=%~1"
set "APK_EXTRACT_DIR="
if defined APK_FILE (
  if not exist "%APK_FILE%" (
    echo [ERR] APK not found: "%APK_FILE%"
    goto :fail
  )
  echo [INFO] APK mode enabled: "%APK_FILE%"
  set "APK_EXTRACT_DIR=%TEMP%\apk_extract_%RANDOM%_%RANDOM%"
  call :ExtractApk "%APK_FILE%" "!APK_EXTRACT_DIR!" || goto :fail
  echo [OK ] APK extracted to: "!APK_EXTRACT_DIR!"
  echo.
)

echo [1/4] Checking tools in PATH...
call :CheckTool dump_syms DUMP_SYMS || goto :fail
call :CheckTool minidump_stackwalk STACKWALK || goto :fail
echo [OK ] dump_syms  : %DUMP_SYMS%
echo [OK ] stackwalk  : %STACKWALK%
echo.

echo [2/4] Locating newest dump (*.dmp)...
set "DUMP_FILE="
for /f "delims=" %%f in ('dir /b /a-d /o-d "*.dmp" 2^>nul') do (
  set "DUMP_FILE=%%f"
  goto :got_dump
)
:got_dump
if not defined DUMP_FILE (
  echo [ERR] No dump file found: *.dmp
  echo [INFO] Directory: %WORK_DIR%
  goto :fail
)
for %%f in ("%DUMP_FILE%") do set "DUMP_BASE=%%~nf"
echo [OK ] Dump: %DUMP_FILE%
echo.

set "SYMBOLS_DIR=%WORK_DIR%symbols"
if not exist "%SYMBOLS_DIR%" (
  mkdir "%SYMBOLS_DIR%" 2>nul || (
    echo [ERR] Failed to create symbols dir: "%SYMBOLS_DIR%"
    goto :fail
  )
)
echo [OK ] Symbols dir: "%SYMBOLS_DIR%"
echo.

echo [3/4] Generating symbols (.sym)...
set "SO_FOUND=0"
for %%f in (*.so) do (
  set "SO_FOUND=1"
  call :GenSym "%%f" "%SYMBOLS_DIR%" "%DUMP_SYMS%"
)
if defined APK_EXTRACT_DIR (
  if exist "!APK_EXTRACT_DIR!\lib" (
    set "APK_SO_COUNT=0"
    for /f %%C in ('dir /s /b "!APK_EXTRACT_DIR!\lib\*.so" 2^>nul ^| find /c /v ""') do set "APK_SO_COUNT=%%C"
    if "!APK_SO_COUNT!"=="0" (
      echo [WARN] No .so found inside APK lib: "!APK_EXTRACT_DIR!\lib"
    ) else (
      echo [INFO] Found !APK_SO_COUNT! .so in APK
    )
    for /f "usebackq delims=" %%f in (`dir /s /b "!APK_EXTRACT_DIR!\lib\*.so" 2^>nul`) do (
      set "SO_FOUND=1"
      call :GenSym "%%f" "%SYMBOLS_DIR%" "%DUMP_SYMS%"
    )
  ) else (
    echo [WARN] No lib folder in APK. Expected: "!APK_EXTRACT_DIR!\lib"
  )
)
if "%SO_FOUND%"=="0" (
  echo [WARN] No .so files found in: %WORK_DIR%
)
echo.

echo [4/4] Generating crash report...
set "REPORT_NAME=%DUMP_BASE%.report.txt"
echo [INFO] Analyzing: %DUMP_FILE%
"%STACKWALK%" "%DUMP_FILE%" "%SYMBOLS_DIR%" > "%REPORT_NAME%" 2>nul
if errorlevel 1 (
  echo [ERR] minidump_stackwalk failed
  goto :fail
)
if not exist "%REPORT_NAME%" (
  echo [ERR] Report not created: %REPORT_NAME%
  goto :fail
)
for %%A in ("%REPORT_NAME%") do set "REPORT_SIZE=%%~zA"
echo [OK ] Report: %REPORT_NAME% (%REPORT_SIZE% bytes)
echo.
echo [TIP] Quick search:
echo       findstr /i /c:"Crash reason" /c:"Crash address" /c:"Thread" "%REPORT_NAME%"
echo.

echo %SEP%
echo   COMPLETED
echo   Symbols: "%SYMBOLS_DIR%\"
echo   Report : "%WORK_DIR%%REPORT_NAME%"
echo %SEP%
echo.
pause
if defined APK_EXTRACT_DIR if exist "%APK_EXTRACT_DIR%" rmdir /s /q "%APK_EXTRACT_DIR%" >nul 2>nul
popd >nul
exit /b 0

:fail
echo.
echo %SEP%
echo   FAILED
echo %SEP%
echo.
pause
if defined APK_EXTRACT_DIR if exist "%APK_EXTRACT_DIR%" rmdir /s /q "%APK_EXTRACT_DIR%" >nul 2>nul
popd >nul
exit /b 1

rem =========================
rem  Subroutines
rem =========================

:CheckTool
rem %1 = tool base name (e.g. dump_syms), %2 = output var
setlocal
set "BASE=%~1"
for %%T in ("%BASE%.exe" "%BASE%") do (
  where %%~T >nul 2>nul && (endlocal & set "%~2=%%~T" & exit /b 0)
)
endlocal
echo [ERR] Tool not found in PATH: %~1
exit /b 1

:FindNewest
rem %1 = pattern, %2 = output var
setlocal
set "PAT=%~1"
for /f "delims=" %%f in ('dir /b /a-d /o-d %PAT% 2^>nul') do (
  endlocal & set "%~2=%%f" & exit /b 0
)
endlocal
exit /b 1

:GenSym
rem %1 = so file, %2 = symbols dir, %3 = dump_syms command
setlocal EnableDelayedExpansion
set "SO_FILE=%~1"
set "SO_NAME=%~nx1"
set "SYMBOLS_DIR=%~2"
set "DUMP_SYMS=%~3"

echo [INFO] Processing: !SO_FILE!

rem Use file name only for temp output; full path may contain ':' and '\' which are invalid in file names
set "TMP_SYM=%TEMP%\dump_syms_!RANDOM!_!SO_NAME!.sym"
"%DUMP_SYMS%" "!SO_FILE!" > "!TMP_SYM!" 2>nul
if errorlevel 1 (
  echo [WARN] dump_syms failed: !SO_FILE!
  if exist "!TMP_SYM!" del /q "!TMP_SYM!" >nul 2>nul
  endlocal & exit /b 1
)
if not exist "!TMP_SYM!" (
  echo [WARN] Temp .sym not created: !SO_FILE!
  endlocal & exit /b 1
)

rem Parse first line: MODULE <os> <arch> <id> <module>
set "module_name="
set "symbol_id="
for /f "usebackq tokens=1,2,3,4,5" %%A in ("!TMP_SYM!") do (
  if /i "%%A"=="MODULE" (
    set "symbol_id=%%D"
    set "module_name=%%E"
    goto :parsed
  )
)
:parsed

if not defined module_name (
  echo [WARN] Cannot parse MODULE line: !SO_FILE!
  del /q "!TMP_SYM!" >nul 2>nul
  endlocal & exit /b 1
)
if not defined symbol_id (
  echo [WARN] Cannot parse SymbolID: !SO_FILE!
  del /q "!TMP_SYM!" >nul 2>nul
  endlocal & exit /b 1
)

set "OUT_DIR=!SYMBOLS_DIR!\!module_name!\!symbol_id!"
if not exist "!OUT_DIR!" mkdir "!OUT_DIR!" >nul 2>nul
if errorlevel 1 (
  echo [WARN] Cannot create dir: !OUT_DIR!
  del /q "!TMP_SYM!" >nul 2>nul
  endlocal & exit /b 1
)

set "OUT_SYM=!OUT_DIR!\!module_name!.sym"
move /y "!TMP_SYM!" "!OUT_SYM!" >nul
if errorlevel 1 (
  echo [WARN] Cannot move sym -> !OUT_SYM!
  del /q "!TMP_SYM!" >nul 2>nul
  endlocal & exit /b 1
)

echo [OK ] Wrote: !OUT_SYM!
endlocal & exit /b 0

:ExtractApk
rem %1 = apk path, %2 = destination dir
setlocal
set "APK=%~1"
set "OUT=%~2"
set "LOG=%TEMP%\apk_extract_%RANDOM%_%RANDOM%.log"
if exist "%OUT%" rmdir /s /q "%OUT%" >nul 2>nul
mkdir "%OUT%" >nul 2>nul
if errorlevel 1 (
  endlocal & echo [ERR] Failed to create extract dir: "%OUT%" & exit /b 1
)

rem APK is a ZIP. Prefer tar if available, fallback to PowerShell Expand-Archive.
where tar >nul 2>nul
if not errorlevel 1 (
  tar -xf "%APK%" -C "%OUT%" >nul 2> "%LOG%"
  if not errorlevel 1 (
    endlocal & exit /b 0
  )
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "& { param([string]$apk,[string]$out,[string]$log) try { Expand-Archive -LiteralPath $apk -DestinationPath $out -Force -ErrorAction Stop; exit 0 } catch { ($_ | Out-String) | Set-Content -LiteralPath $log -Encoding UTF8; exit 1 } }" "%APK%" "%OUT%" "%LOG%" >nul 2>nul
if errorlevel 1 (
  endlocal & echo [ERR] Failed to extract APK. See log: "%LOG%" & exit /b 1
)
endlocal & exit /b 0