@echo off
setlocal EnableExtensions
set "SCRIPT_DIR=%~dp0"
set "SCRIPT_ID=WWD by .:cp7crash, spawn with working directory prompt"
echo %SCRIPT_ID%

:get_params
    set "CWD=%~dp0"
    set "TOOL_CMD=%~1"
    pushd "%CWD%"

    if not defined TOOL_CMD  goto :usage

    :: scan remaining args for flags
    set "BROWSE=0"
    set "WAIT=0"
    set "START_PATH="
    set "TOOL_NAME="
    shift

:parse_opts
    if "%~1"=="" goto :done_opts
    if /i "%~1"=="--browse" ( set "BROWSE=1" & shift & goto :parse_opts )
    if /i "%~1"=="-b"       ( set "BROWSE=1" & shift & goto :parse_opts )
    if /i "%~1"=="--wait"   ( set "BROWSE=1" & set "WAIT=1" & shift & goto :parse_opts )
    if /i "%~1"=="-w"       ( set "BROWSE=1" & set "WAIT=1" & shift & goto :parse_opts )
    if /i "%~1"=="--ps"     ( set "USEPS=1"  & shift & goto :parse_opts )
    if not defined TOOL_NAME ( set "TOOL_NAME=%~1" & shift & goto :parse_opts )
    if not defined START_PATH ( set "START_PATH=%~1" & shift & goto :parse_opts )

    echo Unknown argument: "%~1"
    goto :usage

:done_opts
    set "WD="
    if "%TOOL_NAME%"=="" set "TOOL_NAME=%TOOL_CMD%"
    if "%START_PATH%"=="" set "START_PATH=%CWD%"
    if "%BROWSE%"=="1" goto browse_wd
    if defined START_PATH set "WD=%START_PATH%"

:type_wd
    set /p "WD=Working directory (default: %START_PATH%, / to browse, x to quit): "
    if "%WD%"=="/" goto browse_wd
    if /i "%WD%"=="x" goto fini
    if not defined WD set "WD=%START_PATH%"
    goto no_wd

:browse_wd
    if "%WAIT%"=="1" (
        echo Press any key to browse for a working directory...
        pause >nul
    )
    set "BROWSE_START=%START_PATH%"
    for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command ^
        "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description='Select working directory for %TOOL_NAME%'; if($env:BROWSE_START -ne ''){$f.SelectedPath=$env:BROWSE_START}; if($f.ShowDialog() -eq 'OK'){ $f.SelectedPath }"`) do set "WD=%%I"

:no_wd
    if not defined WD (
        echo Directory not specified, retrying...
        goto type_wd
    )

:invalid_wd
    if not exist "%WD%\" (
        echo Directory "%WD%"not found, retrying...
        goto type_wd
    )

:unable_to_cd
    pushd "%WD%" || (
        echo Failed to switch to directory "%WD%", retrying...
        goto type_wd
    )

:launch
    cls
    call %TOOL_CMD%
    cls
    echo %SCRIPT_ID%
    echo Tool "%TOOL_NAME%" exited, with code %ERRORLEVEL%, restarting...
    goto type_wd

:usage
    echo.
    echo Usage:
    echo   %~nx0 "<toolCommand>" [toolName] [startPath] [options]
    echo.
    echo Where:
    echo   toolCommand    Command to launch the tool, e.g. "SkyCLI.exe"
    echo   toolName       Optional name of the tool to show in prompts (default: toolCommand)
    echo   startPath      Optional initial path for the working directory (default: script directory)
    echo.
    echo   At the prompt, type / and enter to launch the browse dialog
    echo.
    echo Options:
    echo   --browse, -b   Open folder browser dialog immediately
    echo   --wait,   -w   Wait for any key then open folder browse dialog
    echo.
    echo Examples:
    echo   %~nx0 "SkyCLI.exe"
    echo   %~nx0 "SkyCLI.exe" "SkyCLI" --browse
    echo   %~nx0 "tool.exe" "MyTool" --wait "p:\workspaces"
    echo.
    pause

:fini
    popd
    endlocal
    exit /b 1
