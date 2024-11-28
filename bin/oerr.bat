@echo off
rem  
rem $Header: buildtools/scripts/oerr.sbs /main/2 2016/01/14 15:01:43 pkharter Exp $
rem
rem oerr.sbs
rem 
rem Copyright (c) 2011, 2015, Oracle and/or its affiliates. 
rem All rights reserved.
rem
rem    NAME
rem      oerr.sbs - proto driver script for oerr.pl
rem
rem    DESCRIPTION
rem      Proto Windows driver for oerr, which is installed as oerr.bat
rem      and has %ORACLE_HOME% expanded by OUI.  oerr.bat invokes the
rem      new oerr.pl script, passing its command line arguments along.
rem
rem    NOTES
rem      <other useful comments, qualifications, etc.>
rem
rem    MODIFIED   (MM/DD/YY)
rem    pkharter    12/17/15 - 16475009 - update to fix instantiation problem
rem                           for ORACLE_HOME
rem    pkharter    09/27/11 - code reviewer comments
rem    pkharter    09/27/11 - Creation
rem 
setlocal

set OH=%ORACLE_HOME%

if (%OH%)==() (
    echo ORACLE_HOME not set.  Contact Oracle Support Services.
    goto out
)

%OH%\perl\bin\perl %OH%\bin\oerr.pl %1 %2 %3 %4 %5

:out
endlocal
