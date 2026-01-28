@echo off
:: wwd by @cp7crash
:: spawn something with a working directory prompt first

setlocal EnableExtensions
echo WWD by .:cp7crash, spawn with working directory prompt
:get_params
    set "TOOL_CMD=%~1"
    set "TOOL_NAME=%~2"
    set "OPT=%~3"
    set "OPT_PARAM=%~4"

    set "BROWSE=0"
    if /i "%OPT%"=="--browse" set "BROWSE=1"
    if /i "%OPT%"=="-b"       set "BROWSE=1"

    if not defined TOOL_CMD  goto :usage
    if not defined TOOL_NAME goto :usage

    :: reject unknown 3rd param
    if defined OPT if "%BROWSE%"=="0" goto :usage

:type_wd
    set "WD="
    if "%BROWSE%"=="1" goto browse_wd
    if defined OPT_PARAM set "WD=%OPT_PARAM%"
    set /p "WD=Working directory (default: %WD%): "
    if not defined WD set "WD=%OPT_PARAM%"

:browse_wd
        set "BROWSE_START=%OPT_PARAM%"
        for /f "usebackq delims=" %%I in (`powershell -NoProfile -Command ^
            "Add-Type -AssemblyName System.Windows.Forms; $f=New-Object System.Windows.Forms.FolderBrowserDialog; $f.Description='Select working directory for %TOOL_NAME%'; if($env:BROWSE_START -ne ''){$f.SelectedPath=$env:BROWSE_START}; if($f.ShowDialog() -eq 'OK'){ $f.SelectedPath }"`) do set "WD=%%I"

:no_wd
    if not defined WD (
        echo No working directory selected. Exiting.
        pause
        goto fini
    )

:invalid_wd
    if not exist "%WD%\" (
        echo Directory not found: "%WD%"
        pause
        goto fini
    )

:unable_to_cd
    pushd "%WD%" || (
    echo Failed to switch directory: "%WD%"
        pause
        goto fini
    )

:launch
    echo Launching %TOOL_NAME% in "%CD%"...
    cls
    call %TOOL_CMD%
    popd
    goto fini

:usage
    echo.
    echo Usage:
    echo   %~nx0 "<toolCommand>" "<toolDisplayName>" [--browse^|-b]
    echo.
    echo Examples:
    echo   %~nx0 "SkyCLI.exe" "SkyCLI"
    echo   %~nx0 "C:\Tools\SkyCLI\SkyCLI.exe --smash-it" "SkyCLI" --browse
    echo.
    pause

:fini
    endlocal
    exit /b 1
