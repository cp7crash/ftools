@echo off
setlocal

:unsvn.cmd
  echo BREN by .:Fran, batch rename files in a directory tree
  if "%1"=="" goto help
  if "%2"=="" goto help
  echo Renaming files matching %2..
  echo.
  set "mas=%%1"
  set "fix=%%2"
  if /I "%3"=="/s" (
    set "fixtype=suffix"
  ) else (
    set "fixtype=prefix"
  )
  set brencount=0
  for /f "eol=: delims=" %%F in (
    'dir /b "%mask%" ^| findstr /vibc:"%fix%"'
  ) do (
    if %fixtype%=="prefix" (
      echo Renamimg %%F to %fix%%%F
      ren "%%F" "%fix%%%F" 
    ) else (
      echo Renamimg %%F to %%F%fix%
      ren "%%F" "%%F%fix%"
    )
    set /a brencount=%brencount%+1
  )
  goto summary

:cleanup
 echo %1
 rd /s /q %1
 set /a unsvnx=%unsvnx%+1
 goto fini
 
:summary
  if %brencount%==0 (
    echo Didn't match any files!
  ) else (
    echo Renamed %ubreancount% files, you're welcome!
  )
  goto fini
  
:help
  echo Requires two parameters, the mask and the fix
  echo Defaults to adding a prefix, specify /s for a sufix
  echo.
  echo USAGE: bren c:\downloads\icons\*.svg "new_"
  echo        bren *.pdf "-old" /s
  echo.
  
:fini
