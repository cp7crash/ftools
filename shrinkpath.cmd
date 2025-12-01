@echo off
:: shrinkpath by @cp7crash
:: tries to reduce path size my removing missing dirs and using 8.3 paths

:fix_path
    set currPath=%PATH%
    echo Analysing path var for opportunities to shrink...
    setlocal enabledelayedexpansion

    set tempPath="%currPath:;=";"%"
    set counter=0
    set var=
    set startLen=0
    set endLen=0

    call ftlib.cmd strlen startlen %tempPath%
    goto:eof
    echo startLen=%startLen%
    for %%a in (%tempPath%) do call :compare_path %%a   
    
    echo new path=%var%     
    goto:eof

:compare_path
    
    echo | set /p= :%counter% %1
    if exist "%~1" (

        if not "%~1"=="%~s1" (
            echo - [32mEXISTS[0m, but will be shortened
            set "var=!var!;%~s1"
        ) else (
            echo - [44mEXISTS[0m as is
            set "var=!var!;%~1"
        )
        
    ) else (
        echo "%~1" - [31mMISSING[0m, will skip from new path
    )
    set /a counter=!counter!+1
    goto:eof



