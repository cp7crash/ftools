@echo off
:: pingalot by @cp7crash
:: checks various size icmp packets can be sent to a host when given two lengths

if "%1"=="" goto useage
if "%2"=="" goto useage
:vars
set pl_wait=1000
set pl_ttl=54
set pingalotH=%1
set pingalotA=%2
if "%3"=="" (
  set pingalotB=%pingalotA%
) else (
  set pingalotB=%3
)
set pingalotX=%2
set pingalotY=0
set pingalotN=0
set /a pingalotI=pingalotB-pingalotA+1
echo PINGALOT; attempting to send %pingalotI% packets between %pingalotA% and %pingalotB%;
echo  ping %pingalotH% -f -l [%pingalotA% - %pingalotB%] -n 1 -w %pl_wait% -i %pl_ttl%

:loop
  call :pingit %pingalotH% %pingalotX%
  if "%pingalotX%"=="%pingalotB%" goto done
  set /a pingalotX=pingalotX+1
  goto loop

:pingit
  for /f "skip=2 tokens=*" %%a in ('ping %1 -f -l %2 -n 1 -w %pl_wait%') do (call :pinged %%a %%b %%c %%d %%e %%f %%g %%h)
  goto fini
  
:pinged
  set /a pingalotP=%5
  set /a pingalotP=pingalotP+28
  if "%1"=="Reply" goto ping_reply
  if "%1"=="Request" goto ping_noreply
  if "%1"=="Packet" goto ping_maxpacket
  goto fini
  :ping_reply
	echo  Reply in %7 sending %5 bytes (%pingalotP% with headers)
	set /a pingalotY=pingalotY+1
    goto fini
  :ping_noreply
    echo  NO REPLY sending %pingalotX% bytes!
	set /a pingalotN=pingalotN+1
	goto fini
  :ping_maxpacket
    echo  PACKET TOO BIG sending %pingalotX% bytes (needs to be fragmented), attempted packet
	set /a pingalotR=pingalotX+28
	set /a pingalotN=pingalotN+1
	echo  was probably %pingalotR% bytes (+20 byte IP +8 byte ICMP headers)
	set /a pingalotR=pingalotR-1
	if /i %pingalotY% gtr 0 echo  It looks like your Max MTU is %pingalotR%
	set pingalotX=%pingalotB%
	goto fini

:useage
  echo pingalot: ping a host with a range of buffer sizes
  echo.
  echo usage;
  echo   pingalot hostname start_size [ end_size ]
  echo.
  echo examples;
  echo   pingalot ns01.inthehive.net 1475
  echo   pingalot ns01.inthehive.net 200 300
  echo.
  goto fini
  
:done
  set /a pingalotT=pingalotY+pingalotN
  set /a pingalotI=pingalotI-pingalotT
  echo  ------
  echo  Sent %pingalotT% packets; %pingalotY% succeeded, %pingalotN% failed, %pingalotI% not attempted.
  echo  Fini!

:fini
