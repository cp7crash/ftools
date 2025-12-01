@echo off
:: ftlib by @cp7crash
:: collection of useful functions for batch scripts

if "%~1"=="" goto :usage
shift & goto :%~1

:strlen [returnLength] stringVar
    
    set retVar=%~1
    echo retVar=%retVar%
    shift
    setlocal EnableDelayedExpansion
    set _str="%*"
    echo _str = %_str%

    if not defined _str (
        endlocal
        set _strlen=0
        goto:eof
    )
 
    for /l %%g in (0,1,8191) do (
        set "_char=!_str:~%%g,1!"
        if not defined _char (
            endlocal
            if "%~2" neq "" (set %~2=%_strlen%)
            set _strlen=%%g
            goto:eof
        )
    )
    goto:eof

:usage
    echo Usage: [function] (param 1) (param 2) (param N) & exit /b