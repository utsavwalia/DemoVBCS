@echo off
set xdkparm=
:loop
if "%1"=="" goto end
set xdkparm=%xdkparm% %1
shift
goto loop
:end
java oracle.xml.classgen.oracg %xdkparam%
