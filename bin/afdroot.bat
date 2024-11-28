@echo off
rem
rem 
rem Copyright (c) 2007, 2021, Oracle and/or its affiliates. 
rem All rights reserved.
rem
rem    NAME
rem      afdroot.bat - front end for the Perl scripts that do the work.
rem
rem    DESCRIPTION
rem        Purpose
rem            Start/stop AF Drivers
rem        Usage
rem            afdroot [start] [stop]
rem
rem    NOTES
rem
rem

setlocal

set CMD=afdroot

set TOOLS_DRIVER=%ORACLE_HOME%/lib/afdtoolsdriver.bat

rem Now run afdtoolsdriver - which will call afdroot
%TOOLS_DRIVER% %CMD% %1 %2 %3 %4 %5 %6 %7 %8 %9

:end

endlocal

exit /B %ERRORLEVEL%
