@echo off
if "%OS%"=="Windows_NT" setlocal
REM all variables defined local
REM set DBG=echo to debug this script.
set DBG=REM
set nextarg=
set rslvarg=
set javaprops="-Xint"
set args=
set jreclasspath="C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\lib\rt.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\lib\i18n.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jdbc\lib\ojdbc8.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\javavm\lib\aurora.zip"
:LOOP
%DBG% LOOP-%CNT% (loop for args parsing)
  set/a CNT+=1
  set nextarg=%1
  set nextarg=%nextarg:"=%
  if {%1} == {} goto MARK6
  if {%1} == {-classpath} goto MARK1
  if {%1} == {-addclasspath} goto MARK2
  if {%1} == {-resolver} goto MARK4
  if "%nextarg%" == "-server" goto MARK10
  if "%nextarg:~0,2%" == "-D" goto MARK5
    set args=%args% %1
    %DBG% %args%
    shift
    goto LOOP
:MARK1
%DBG% MARK1 hit (-classpath)
  set CLASSPATH=%2
  set CLASSPATH=%CLASSPATH:"=%
  shift
  shift
  goto LOOP
:MARK2
%DBG% MARK2 hit (first -addclasspath)
  if not "%addclasspath%"=="" goto MARK3
    set addclasspath=%2
    set addclasspath=%addclasspath:"=%
    shift
    shift
    goto LOOP
:MARK3
%DBG% MARK3 hit (additional -addclasspath)
  set nextarg=%2
  set addclasspath=%addclasspath%;%nextarg:"=%
  shift
  shift
  goto LOOP
:MARK4
%DBG% MARK4 hit (-resolver)
  set rslvarg=%2
  set rslvarg=%rslvarg:"=%
  shift
  shift
  goto LOOP
:MARK5
%DBG% MARK5 hit (-Djavaprop=prop)
  set javaprops=%javaprops% %1=%2
  set javaprops=%javaprops:"=%
  shift
  shift
  goto LOOP
:MARK10
%DBG% MARK10 hit (-server)
  set TCSERV=%1
  set TCSERV=%TCSERV% %2
  set TCSERV=%TCSERV:"=%
  shift
  shift
  goto LOOP
:MARK6
%DBG% MARK6 hit (append classpath)
  if "%CLASSPATH%"=="" goto MARK7
    set jreclasspath="%jreclasspath%;%CLASSPATH%"
    set jreclasspath="%jreclasspath:"=%"
:MARK7
%DBG% MARK7 hit (append addclasspath)
  if "%addclasspath%"=="" goto MARK8
    set jreclasspath="%jreclasspath%;%addclasspath%"
    set jreclasspath="%jreclasspath:"=%"
:MARK8
%DBG% MARK8 hit (append resolver)
  if "%rslvarg%"=="" goto MARK9
    set args=%args% -resolver "%rslvarg%"
:MARK9
%DBG% MARK9 hit (invoke loadjava)
%DBG% *** CLASSPATH = %CLASSPATH% ***
%DBG% *** addclasspath = %addclasspath% ***
%DBG% *** jreclasspath = %jreclasspath% ***
%DBG% *** javaprops = %javaprops% ***
%DBG% *** rslvarg = %rslvarg% ***
%DBG% *** args = %args% ***
%DBG% *** TCSERV = %TCSERV% ***

"C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\bin\java" %javaprops% -classpath %jreclasspath% oracle.aurora.server.tools.ojvmtc.OjvmTcMain  %args%
if "%OS%" == "Windows_NT" endlocal
