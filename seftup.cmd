@echo off
:: setup by @cp7crash
:: adds ftools to the users environment path

set TARGET=%~dp0

goto :fini

:check_path
    if "%PATH%"=="" goto :no_path
    echo ;%PATH%; | find /C /I ";%CD%;" >nul 2>&1
    if %errorLevel% == 0 (
        goto :path_set
    ) else (
        goto :set_path
    )
    goto :fini

:set_path
    set PATH=%PATH%;%CD%
    echo Added %CD% to PATH for this session
    goto :set_global

:set_global
    net session >nul 2>&1
    if %errorlevel% == 0 (
        setx PATH "%PATH%;%CD%" /M
        echo Also set path permanently using setx.
    ) else (
         echo Unable to set path permanently, please re-run as administrator.
        goto :fini
    )
    goto :fini

:path_set
    echo Path is already set for this session, nothing to do.
    goto fini

:no_path
    echo No path currently set, weird = aborting.
    goto fini

:fini
    echo.

