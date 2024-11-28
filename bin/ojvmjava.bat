@echo off
if "%OS%"=="Windows_NT" setlocal
REM all variables defined local
REM set DBG=echo to debug this script.
set DBG=REM

set jreclasspath="C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\lib\rt.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\lib\i18n.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jdbc\lib\ojdbc8.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\javavm\lib\aurora.zip"

set args=
:loop
%DBG% LOOP-%CNT% (loop for args parsing)
  set/a CNT+=1
  set nextarg=%1
  set nextarg=%nextarg:"=%  
  if (%1)==() goto :done
  set args=%args% %1
  shift
  goto :loop
  if "%nextarg%" == "-u" goto MARK1
  if "%nextarg%" == "-user" goto MARK1
  if "%nextarg:~0,2%" == "-P" goto MARK2
  if "%nextarg:~0,2%" == "-p" goto MARK2
    set args=%args% %1
    %DBG% %args%
    shift
    goto loop
:MARK1
%DBG% MARK1 hit (-u)
  set OJUSER="%1 %2"
  set OJUSER=%OJUSER:"=%
  shift
  shift
  goto loop
:MARK2
%DBG% MARK2 hit (-P or -p)
  set OJPASS=%1
  set OJPASS=%OJPASS:"=%
  set OJPASS=%OJPASS% %2
  shift
  shift
  goto loop
:done
%DBG% *** OJUSER = %OJUSER% ***
%DBG% *** OJPASS = %OJPASS% ***
%DBG% ***   args = %args%   ***

"C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\bin\java" -Xint -classpath %jreclasspath% oracle.aurora.server.tools.shell.ShellClient  %args%

if "%OS%" == "Windows_NT" endlocal
