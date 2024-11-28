@echo off
if (%OS%) == (Windows_NT) setlocal
REM all variables defined local
REM set DBG=echo to debug this script.
set DBG=REM
set args=
set JAVA_HOME=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\

set JRECLASSPATH="C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\lib\rt.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\lib\i18n.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jdbc\lib\ojdbc8.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\javavm\lib\aurora.zip"

:LOOP
%DBG% LOOP-%CNT% (loop for args parsing)
  set/a CNT+=1
  set nextarg=%1
  set nextarg=%nextarg:"=%
  if {%1} == {} goto MARK3
  if "%nextarg%" == "-u" goto MARK1
  if "%nextarg%" == "-user" goto MARK1
  if "%nextarg:~0,2%" == "-P" goto MARK2
  if "%nextarg%" == "-password" goto MARK2
    set args=%args% %1
    %DBG% %args%
    shift
    goto LOOP
:MARK1
%DBG% MARK1 hit (-u)
  if {%2}=={} goto MARK11
  set tmp=%2
  if not x%tmp:DESC=%==x%tmp% set tmp=%tmp:"=%
  set DJUSER=%1 %tmp%
  goto MARK12
:MARK11
  set DJUSER=%1 %2
:MARK12
  shift
  shift
  goto LOOP
:MARK2
%DBG% MARK2 hit (-P or -password)
  set DJPASS=%1
  set DJPASS=%DJPASS:"=%
  set DJPASS=%DJPASS% %2
  shift
  shift
  goto LOOP
:MARK3
%DBG% MARK3 hit (end of loop)
%DBG% *** user = %DJUSER% ***
%DBG% *** password = %DJPASS% ***
%DBG% *** args = %args% ***

"C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\bin\java" -Xint -classpath %JRECLASSPATH%  oracle.aurora.server.tools.loadjava.DropJavaMain %args%

if (%OS%) == (Windows_NT) endlocal
