::@echo off
:: bren by @cp7crash
:: batch rename files in a directory

setlocal

:unsvn.cmd
  if "%1"=="" goto help
  if "%2"=="" goto help
  
  set mask=%1
  set mask=%mask:"=%
  set fix=%2
  set fix=%fix:"=%
  set wdir=%~dp1

  echo.
  echo Renaming files matching %mask%...
  echo Working directory is %wdir%
  
  set brencount=0
  set preflight=1
  if /I "%3"=="/s" (set fixtype=suffix) else (set fixtype=prefix)
  call :findfiles
  goto summary

:findfiles
  for /f "eol=: delims=" %%F in (
    'dir /b "%mask%" ^| findstr /vibc:"%fix%"'
  ) do call :processfile "%%F"
  goto fini

:processfile
  set filename=%1
  set filename=%filename:"=%
  set file=%~n1
  set filext=%~x1

  if %fixtype%==prefix (
    set target=%fix%%filename%
  ) else (
    if "%filext%"=="" 
      (set target=%filename%%fix%)
    else 
      (set target=%file%%fix%.%filext%)
  )
  
  if %preflight%==1 (set action=INTENT) else (set action=Renaming)

  echo %action% [31m%filename%[0m --^> [32m%target%[0m
  
  if %fixtype%==prefix (
    if %preflight%==0 echo : ren "%wdir%%filename%" "%wdir%%fix%%1" 
  ) else (
    if %preflight%==0 echo : ren "%wdir%%filename%" "%wdir%%1%fix%"
  )
  set /a brencount=%brencount%+1
  goto fini

:summary
  if %brencount%==0 (
    echo Didn't match any files!
  ) else (
    if %preflight%==1 (
      echo.
      echo Preflight found %brencount% matching files, proceed with intent?
      set /p proceed=[y/n]?
      if /I "%proceed%"=="y" (
        set preflight=0
        call :findfiles
      )
    ) else (
      echo Renamed %breancount% files, you're welcome!
    )
  )
  goto fini
  
:help
  echo Requires two parameters, the mask and the fix
  echo Defaults to adding a prefix, specify /s for a sufix
  echo.
  echo USAGE: bren c:\users\me\downloads\icons\*.svg "new_"
  echo        bren *.pdf "-old" /s
  echo.
  
:fini
