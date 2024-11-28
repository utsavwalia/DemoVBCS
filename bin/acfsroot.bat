@echo off
rem
rem
rem acfsroot.bat
rem 
rem Copyright (c) 2007, 2021, Oracle and/or its affiliates. 
rem All rights reserved.
rem
rem    NAME
rem      acfsroot.bat - frontend for the Perl script that does the work.
rem
rem    DESCRIPTION
rem        Purpose
rem            Start/stop ADVM/ACFS drivers
rem
rem        Usage
rem            acfsroot [start] [stop]
rem
rem    NOTES
rem
rem

setlocal
rem Set CRS_HOME if needed.
rem Auto filled in by acfsroot.pl during install.
set CRS_HOME=%~dp0..

set CMD=acfsroot

if "%ORACLE_HOME%"=="" (
  set ORACLE_HOME=%CRS_HOME%
)

set TOOLS_DRIVER=%ORACLE_HOME%/lib/acfstoolsdriver.bat

rem Now run acfstoolsdriver - which will call acfsroot
%TOOLS_DRIVER% %CMD% %1 %2 %3 %4 %5 %6 %7 %8 %9

:end

endlocal

exit /B %ERRORLEVEL%
