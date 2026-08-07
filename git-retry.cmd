@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM git-retry.cmd - retry git push / clone / pull on unstable network
REM Same logic as git-retry.sh; run directly in cmd.exe
REM Usage: git-retry.cmd --help

set "INTERVAL=1"
set "TIMEOUT=120"
set "MAX_RETRIES=0"
set "REMOTE=origin"
set "BRANCH="
set "DEPTH=0"
set "TARGET_DIR="
set "CMD="
set "POS1="
set "POS2="
set "POS_COUNT=0"

if "%~1"=="" (
  call :usage
  exit /b 1
)

:parse_args
if "%~1"=="" goto after_parse

if /i "%~1"=="-h" goto show_usage_ok
if /i "%~1"=="--help" goto show_usage_ok

if /i "%~1"=="-i" goto opt_interval
if /i "%~1"=="--interval" goto opt_interval
if /i "%~1"=="-t" goto opt_timeout
if /i "%~1"=="--timeout" goto opt_timeout
if /i "%~1"=="-n" goto opt_max_retries
if /i "%~1"=="--max-retries" goto opt_max_retries
if /i "%~1"=="-d" goto opt_depth
if /i "%~1"=="--depth" goto opt_depth

if /i "%~1"=="push" goto set_cmd
if /i "%~1"=="clone" goto set_cmd
if /i "%~1"=="pull" goto set_cmd

if "%~1"=="--" (
  shift
  goto collect_rest
)

set "ARG=%~1"
if "!ARG:~0,1!"=="-" (
  call :log ERROR: unknown option: %~1
  exit /b 1
)

call :add_positional "%~1"
if errorlevel 1 exit /b 1
shift
goto parse_args

:opt_interval
if "%~2"=="" (
  call :log ERROR: option %~1 needs a value
  exit /b 1
)
set "INTERVAL=%~2"
shift
shift
goto parse_args

:opt_timeout
if "%~2"=="" (
  call :log ERROR: option %~1 needs a value
  exit /b 1
)
set "TIMEOUT=%~2"
shift
shift
goto parse_args

:opt_max_retries
if "%~2"=="" (
  call :log ERROR: option %~1 needs a value
  exit /b 1
)
set "MAX_RETRIES=%~2"
shift
shift
goto parse_args

:opt_depth
if "%~2"=="" (
  call :log ERROR: option %~1 needs a value
  exit /b 1
)
set "DEPTH=%~2"
shift
shift
goto parse_args

:set_cmd
set "CMD=%~1"
shift
goto parse_args

:collect_rest
if "%~1"=="" goto after_parse
call :add_positional "%~1"
if errorlevel 1 exit /b 1
shift
goto collect_rest

:add_positional
set /a POS_COUNT+=1
if !POS_COUNT! EQU 1 set "POS1=%~1"
if !POS_COUNT! EQU 2 set "POS2=%~1"
if !POS_COUNT! GTR 2 (
  call :log ERROR: extra positional arg: %~1
  exit /b 1
)
exit /b 0

:show_usage_ok
call :usage
exit /b 0

:after_parse
if "!CMD!"=="" (
  call :usage
  exit /b 1
)

where git >nul 2>&1
if errorlevel 1 (
  call :log ERROR: git not found in PATH
  exit /b 1
)

if /i "!CMD!"=="push" goto do_push
if /i "!CMD!"=="clone" goto do_clone
if /i "!CMD!"=="pull" goto do_pull
call :log ERROR: unknown command: !CMD!
exit /b 1

:usage
echo Usage:
echo   git-retry.cmd push  [options] [remote] [branch]
echo   git-retry.cmd clone [options] ^<repo-url^> [target-dir]
echo   git-retry.cmd pull  [options] [remote] [branch]
echo.
echo Commands:
echo   push   Retry git push forever in current repo
echo   clone  Retry git clone from URL; keep retrying on fail/timeout
echo   pull   Retry git pull forever in current repo
echo.
echo Options:
echo   -i, --interval ^<sec^>   Wait after failure, default 1
echo   -t, --timeout ^<sec^>    Per-attempt timeout, default 120; 0 = no limit
echo   -n, --max-retries ^<N^>  Max attempts, default 0 = infinite
echo   -d, --depth ^<N^>        Shallow clone depth (clone only)
echo   -h, --help              Show help
echo.
echo Examples:
echo   git-retry.cmd push
echo   git-retry.cmd push origin main
echo   git-retry.cmd push -i 10 -t 60
echo   git-retry.cmd clone https://github.com/org/repo.git
echo   git-retry.cmd clone -t 180 git@github.com:org/repo.git my-repo
echo   git-retry.cmd pull -i 8
exit /b 0

:log
set "MSG=%*"
set "TS="
for /f "usebackq delims=" %%T in (`powershell -NoProfile -Command "Get-Date -Format 'yyyy-MM-dd HH:mm:ss'" 2^>nul`) do set "TS=%%T"
if not defined TS set "TS=%date% %time%"
echo [!TS!] !MSG!
exit /b 0

REM Run command in RUN_ARGS; TIMEOUT=0 means no limit
:run_with_timeout
set "RUN_RC=1"
if !TIMEOUT! LEQ 0 goto run_no_timeout

set "PSFILE=%TEMP%\git-retry-to-!RANDOM!!RANDOM!.ps1"
> "!PSFILE!" echo $ErrorActionPreference = 'Continue'
>> "!PSFILE!" echo $cmd = $env:RUN_ARGS
>> "!PSFILE!" echo $to = [int]$env:TIMEOUT
>> "!PSFILE!" echo $p = Start-Process -FilePath 'cmd.exe' -ArgumentList @('/d','/c', $cmd) -NoNewWindow -PassThru
>> "!PSFILE!" echo if ($p.WaitForExit($to * 1000)) {
>> "!PSFILE!" echo   if ($null -ne $p.ExitCode) { exit $p.ExitCode } else { exit 1 }
>> "!PSFILE!" echo }
>> "!PSFILE!" echo $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
>> "!PSFILE!" echo Write-Host "[$ts] timeout (${to}s), kill pid $($p.Id)"
>> "!PSFILE!" echo try { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue } catch {}
>> "!PSFILE!" echo Get-CimInstance Win32_Process -ErrorAction SilentlyContinue ^| Where-Object { $_.ParentProcessId -eq $p.Id } ^| ForEach-Object { try { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue } catch {} }
>> "!PSFILE!" echo exit 124

powershell -NoProfile -ExecutionPolicy Bypass -File "!PSFILE!"
set "RUN_RC=!ERRORLEVEL!"
del /f /q "!PSFILE!" >nul 2>&1
exit /b !RUN_RC!

:run_no_timeout
cmd /d /c "!RUN_ARGS!"
set "RUN_RC=!ERRORLEVEL!"
exit /b !RUN_RC!

:retry_loop
set "DESC=%~1"
set "ATTEMPT=0"

:retry_again
set /a ATTEMPT+=1
call :log attempt !ATTEMPT!: !DESC!

call :run_with_timeout
set "RC=!ERRORLEVEL!"
if !RC! EQU 0 (
  call :log success: !DESC!
  exit /b 0
)

if !MAX_RETRIES! GTR 0 if !ATTEMPT! GEQ !MAX_RETRIES! (
  call :log ERROR: reached max retries !MAX_RETRIES!, last exit=!RC!
  exit /b 1
)

call :log failed exit=!RC!, retry in !INTERVAL!s ...
set /a SLEEP_N=!INTERVAL!+1
ping -n !SLEEP_N! 127.0.0.1 >nul 2>&1
goto retry_again

:do_push
set "R=!REMOTE!"
set "B=!BRANCH!"
if defined POS1 set "R=!POS1!"
if defined POS2 set "B=!POS2!"

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
  call :log ERROR: not a git repository
  exit /b 1
)

if defined B (
  set "DESC=git push !R! !B!"
  set RUN_ARGS=git push "!R!" "!B!"
) else (
  set "DESC=git push !R!"
  set RUN_ARGS=git push "!R!"
)

call :retry_loop "!DESC!"
exit /b !ERRORLEVEL!

:do_pull
set "R=!REMOTE!"
set "B=!BRANCH!"
if defined POS1 set "R=!POS1!"
if defined POS2 set "B=!POS2!"

git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
  call :log ERROR: not a git repository
  exit /b 1
)

if defined B (
  set "DESC=git pull !R! !B!"
  set RUN_ARGS=git pull "!R!" "!B!"
) else (
  set "DESC=git pull !R!"
  set RUN_ARGS=git pull "!R!"
)

call :retry_loop "!DESC!"
exit /b !ERRORLEVEL!

:do_clone
if not defined POS1 (
  call :log ERROR: clone needs repo URL, e.g. git-retry.cmd clone URL [dir]
  exit /b 1
)
set "URL=!POS1!"
set "DIR=!TARGET_DIR!"
if defined POS2 set "DIR=!POS2!"

if !DEPTH! GTR 0 (
  if defined DIR (
    set RUN_ARGS=git clone --depth !DEPTH! "!URL!" "!DIR!"
  ) else (
    set RUN_ARGS=git clone --depth !DEPTH! "!URL!"
  )
) else (
  if defined DIR (
    set RUN_ARGS=git clone "!URL!" "!DIR!"
  ) else (
    set RUN_ARGS=git clone "!URL!"
  )
)

set "DEST=!DIR!"
if not defined DEST (
  call :basename_git "!URL!"
  set "DEST=!BASENAME!"
)

if exist "!DEST!\.git\" (
  call :log dir exists as git repo: !DEST!, switch to pull
  pushd "!DEST!" >nul 2>&1
  if errorlevel 1 (
    call :log ERROR: cannot enter dir: !DEST!
    exit /b 1
  )
  set RUN_ARGS=git pull
  call :retry_loop "git pull in !DEST!"
  set "RC=!ERRORLEVEL!"
  popd >nul 2>&1
  exit /b !RC!
)

if exist "!DEST!" (
  call :log ERROR: target exists and is not empty repo: !DEST!
  exit /b 1
)

if defined DIR (
  set "DESC=git clone !URL! to !DIR!"
) else (
  set "DESC=git clone !URL!"
)
call :retry_loop "!DESC!"
exit /b !ERRORLEVEL!

:basename_git
set "BASENAME=%~1"
set "BASENAME=!BASENAME:\=/!"
:basename_strip_slash
if "!BASENAME:~-1!"=="/" (
  set "BASENAME=!BASENAME:~0,-1!"
  goto basename_strip_slash
)
for %%F in ("!BASENAME!") do set "BASENAME=%%~nxF"
if /i "!BASENAME:~-4!"==".git" set "BASENAME=!BASENAME:~0,-4!"
exit /b 0