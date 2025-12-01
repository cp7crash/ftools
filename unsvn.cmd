@echo off
:: unsvn by @cp7crash
:: removes traces of .svn from a directory tree

:unsvn.cmd
  echo UN-SVN by .:Fran, cleans SVN dirs/files from a directory tree
  if "%1"=="" goto help
  echo Looking in %1 for .svn dirs..
  set unsvnx=0
  for /r "%1" %%f in (.svn) do if exist "%%f" call :cleanup "%%f"
  goto summary
  
:cleanup
 echo %1
 rd /s /q %1
 set /a unsvnx=%unsvnx%+1
 goto fini
 
:summary
  if %unsvnx%==0 (
    echo Dir tree is already clean!
  ) else (
    echo Removed %unsvnx% directories, how good am I!
  )
  goto fini
  
:help
  echo Cleans SVN dirs/files from a directory tree
  echo.
  echo USAGE: unsvn x:\folder
  echo.
  
:fini