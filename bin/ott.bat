@echo off
if "%OS%"=="Windows_NT" setlocal

set jreclasspath=";%ORACLE_HOME%\jdbc\lib\ojdbc8.jar;%ORACLE_HOME%\jlib\orai18n.jar;%ORACLE_HOME%\precomp\lib\ottclasses.zip"

"%ORACLE_HOME%\jdk\bin\java" -classpath %jreclasspath% oracle.ott.c.CMain nlslang=%NLS_LANG% orahome=%ORACLE_HOME%  %*

if "%OS%" == "Windows_NT" endlocal

