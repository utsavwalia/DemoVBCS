@echo off
rem
rem 
rem Copyright (c) 2007, 2021, Oracle and/or its affiliates. 
rem All rights reserved.
rem
rem    NAME
rem      usm_tools_driver.bat - front end for the Perl scripts that do the work.
rem
rem    DESCRIPTION
rem      common driver for:
rem        usm_load, usm_root, usm_mount,
rem        usm_singlefs_mount, usm_driver_state, usm_dbhome.
rem
rem    NOTES
rem
rem

setlocal

rem ORACLE_HOME is set at install time by acfsroot.
if "%ORACLE_HOME%"=="" (
  set ORACLE_HOME="/"
)


set CMD=%1

rem acfsdriverstate may have a different location for ORACLE_HOME and CRS_HOME
rem so set ORACLE_HOME back to the original CRS_HOME.
rem Note that ORA_CRS_HOME is used by acfslib
if "%CMD%"=="acfsdriverstate" (
  set ORA_CRS_HOME=%CRS_HOME%
  set ORACLE_HOME=%CRS_HOME%
) else (
  if "%ORA_CRS_HOME%"=="" (
    set ORA_CRS_HOME=%ORACLE_HOME%
  )
)

if exist "%ADE_VIEW_ROOT%" (
  set ORACLE_HOME=%ADE_VIEW_ROOT%/oracle
  set ORA_CRS_HOME=%ADE_VIEW_ROOT%/oracle
) 

rem Construct path to clsecho and Perl.  version 5.10 is released with Oracle 11.2.
set PERLBIN=%ORACLE_HOME%/perl/bin/perl.exe
set CLSECHOBIN=%ORACLE_HOME%/bin/clsecho.exe

if not exist %CLSECHOBIN% (
  echo "clsecho not found"
)

set CLSECHO=%CLSECHOBIN% -p usm -f acfs -c err 
set CLSECHOTL=%CLSECHOBIN% -p usm -f acfs -l -c err -t -n

if not exist %PERLBIN% (
  rem 3001: "Failed to open %s. Verify that %s exists."
  %CLSECHO% -m 3001 perl.exe %PERLBIN%
  %CLSECHOTL% -m 3001 perl.exe %PERLBIN%
  if "%CMD%"=="acfsdriverstate" (
    rem 9211: usage: %s [-h] [-orahome <home_path>] {installed | loaded | version | supported} [-s]
    %CLSECHO% -m 9211 %CMD%
    %CLSECHOTL% -m 9211 %CMD%
  )
  set ERRORLEVEL=1
  goto end
)

rem Only acfsreplcrs does not have an osds_* component
if not "%CMD%"=="acfsreplcrs" (
  if not exist "%ORACLE_HOME%/lib/osds_%CMD%.pm" (
    echo "%CMD%: ADVM/ACFS is not supported on this Operating System"
    set ERRORLEVEL=1
    goto end
  )
)

set LIBS=-I %ORACLE_HOME%/lib
set COMMAND=%ORACLE_HOME%/lib/%CMD%.pl

rem PERL5LIB is not needed for v5.10 and can be harmful if set.
if defined PERL5LIB (
  set PERL5LIB=
)
rem Now run the target command with all arguments!
%PERLBIN% %LIBS% %COMMAND% %1 %2 %3 %4 %5 %6 %7 %8 %9

:end

endlocal

exit /B %ERRORLEVEL%
