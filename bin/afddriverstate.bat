@echo off
rem
rem
rem afddriverstate.bat
rem 
rem Copyright (c) 2013, 2021, Oracle and/or its affiliates. 
rem All rights reserved.
rem
rem    NAME
rem      afddriverstate.bat - frontend for the Perl script that does the work.
rem
rem    DESCRIPTION
rem        Purpose
rem            Start/stop AFD driver
rem
rem        Usage
rem            afddriverstate [installed] [loaded] [version]
rem
rem    NOTES
rem
rem

rem The following perl.exe search was copied from asmcmd.bat in order
rem to get the latest version of perl.
rem NOTE THAT WE MUST HAVE PERL V5.6 OR LATER - WHICH SUPPORTS "OUR".

setlocal

rem Set CRS_HOME if needed.
rem Filled in by afdroot.pl during install.
set CRS_HOME=%~dp0..

set CMD=afddriverstate

if "%1" == "" goto next

rem This command could, conceivably, be run from some one logged
rem in to a non-oracle account, without ORACLE_HOME set.
rem We need to be able to find the right Perl libraries, Win32, for instance.
rem Since this command lives in ORACLE_HOME/bin, we'll use that as our base. 
if "%1" == "-orahome" (
  set ORACLE_HOME=%~2
  rem pop -orahome
  shift
  rem pop <location>
  shift
) else (
  rem srvctl passes in the args with "" around them
  if %1 == "-orahome" ( 
    set ORACLE_HOME=%~2
    rem pop -orahome
    shift
    rem pop <location>
    shift
  )
)

:next
  if "%ORACLE_HOME%" == "" (
    set ORACLE_HOME=%CRS_HOME%
  )

if not exist "%ADE_VIEW_ROOT%" (
  set TOOLS_DRIVER=%CRS_HOME%/lib/afdtoolsdriver.bat
) else (
  set TOOLS_DRIVER=%ADE_VIEW_ROOT%/usm/bin/afdtoolsdriver.bat
  rem afdtoolsdriver sets ORACLE_HOME to CRS_HOME
  rem in an ADE view we do not want to change ORACLE_HOME
  rem so here we set CRS_HOME to ORACLE_HOME to prevent this change
  set CRS_HOME=%ORACLE_HOME%
)

rem Now run usm_tools_driver - which will call afddriverstate
%TOOLS_DRIVER% %CMD% %~1 %~2 %~3 %~4 %~5 %~6 %~7 %~8 %~9

endlocal

exit /B %ERRORLEVEL%
