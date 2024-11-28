@echo off
rem 
rem $Header: opsm/utl/srvctl.sbs /st_has_19_nt/1 2019/07/02 08:37:10 jorgepe Exp $
rem
rem Copyright (c) 2008, 2019, Oracle and/or its affiliates. 
rem All rights reserved.
rem
rem    NAME
rem    srvctl - Oracle Server Control Utility
rem
rem    DESCRIPTION
rem    Oracle Server Control Utility can be used to administer all Oracle
rem    entities such as node applications, databases, ASM etc. managed
rem    under Oracle Clusterware.
rem
rem    NOTES
rem
rem    MODIFIED   (MM/DD/YY)
rem    jorgepe     06/17/19 - Fix bug 29866585 - Set LDAP version to 19
rem    nidietri    11/08/16 - Fix bug 23637855- removed parsing for args
rem    rdesale     06/26/16 - Fix bug 23522607
rem    rdesale     03/24/16 - Fix bug 22983734- add jwc-cred.jar to classpath
rem    kamramas    05/11/15 - Fix Trace issue
rem    sidshank    11/26/13 - fix bug 17832159.
rem    satg        09/13/13 - Fix bug 17416709
rem    ccharits    03/07/13 - XbranchMerge ccharits_bug-16368497 from
rem                           st_has_12.1.0.1
rem    epineda     10/10/12 - Added ldapjclnt12.jar for listener.ora reading
rem    yizhang     10/01/12 - fix bug 14381919
rem    agridnev    06/20/11 - added clsce.jar to support snapshots
rem    yizhang     12/30/10 - add antlr jar to classpath
rem    yizhang     12/30/10 - fix bug 9256393
rem    sravindh    04/06/10 - Bug 9447018
rem    yizhang     09/25/09 - fix bug 8771500
rem    rxkumar     01/26/09 - fix bug7715235
rem    rwessman    08/22/08 - Added GNS jar file.
rem    rxkumar     07/18/08 - fix EONSJAR
rem    spavan      05/16/08 - fix bug6937911
rem    hkanchar    03/31/08 - Add EONS jar files to the classpath
rem    spavan      03/27/08 - fix bug6916030
rem    rxkumar     01/10/08 - fix bug6730574
rem 
setlocal

Rem Gather command-line arguments.
@set USER_ARGS=%*

@set JREDIR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jdk
@set JRE="%JREDIR%\bin\java"
@set JREJAR=%JREDIR%\jre\lib\rt.jar
@set JLIB=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib
set EONSJAR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\ons\lib\ons.jar
@set GNSJAR=%JLIB%\gns.jar
set ANTLRJAR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\srvm\jlib\antlr-3.3-complete.jar
@set PATH=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\bin;%PATH%
set CLSCEJAR=%JLIB%\clsce.jar
set CHACONFIGJAR=%JLIB%\chaconfig.jar
set JDBCJAR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jdbc\lib\ojdbc6.jar
set LDAPJAR=%JLIB%\ldapjclnt19.jar
@set JWCCREDJAR=%JLIB%\jwc-cred.jar
set JAVA_STACK_SIZE="-Xss2048k"


if (%ORATST_SRVCTL11%)==() (
   set CLASSPATH="C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\srvm\jlib\srvctl.jar;%JLIB%\srvm.jar;%JLIB%\srvmhas.jar;%JLIB%\srvmasm.jar;%JLIB%\supercluster-common.jar;%JLIB%\supercluster.jar;%LDAPJAR%;%JLIB%\netcfg.jar;%JREJAR%;%EONSJAR%;%GNSJAR%;%ANTLRJAR%";%CLSCEJAR%;%CHACONFIGJAR%;%JDBCJAR%;%JWCCREDJAR%
) else (
   set CLASSPATH="%ORATST_SRVCTL11_JARS%;%JLIB%\srvmasm.jar;%JLIB%\supercluster-common.jar;%JLIB%\supercluster.jar;%LDAPJAR%;%JLIB%\netcfg.jar;%JREJAR%;%EONSJAR%;%GNSJAR%;%ANTLRJAR%";%CLSCEJAR%;%CHACONFIGJAR%;%JDBCJAR%;%JWCCREDJAR%

)

set JRE_OPTIONS=%JAVA_STACK_SIZE%

set ORACLE_HOME_PROP=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home

Rem - If CRSHOME, unset ORACLE_HOME 
if exist C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\bin\crsctl.exe (
  set ORACLE_HOME=
)

Rem USING ANTLR
if not (%USING_ANTLR%)==() (
   set SRVM_PROPERTY_DEFS= %SRVM_PROPERTY_DEFS% -Dusing_antlr=%USING_ANTLR%
)

Rem NETWORK CHECK LEVEL
if not (%CHECK_LEVEL%)==() (
   set SRVM_PROPERTY_DEFS= %SRVM_PROPERTY_DEFS% -DNETWORK.CHECKLEVEL=%CHECK_LEVEL%
)

Rem SRVM TRACING
if (%SRVM_TRACE%)==() (
  goto runcmd
) else (
  if /I '%SRVM_TRACE%' == 'false' (
    set SRVM_PROPERTY_DEFS= %SRVM_PROPERTY_DEFS% -DTRACING.ENABLED=false
  ) else (
    if not '%SRVM_TRACE_LEVEL%' == '' (
      set SRVM_PROPERTY_DEFS= %SRVM_PROPERTY_DEFS% -DTRACING.ENABLED=true -DTRACING.LEVEL=%SRVM_TRACE_LEVEL%
    ) else (
      set SRVM_PROPERTY_DEFS= %SRVM_PROPERTY_DEFS% -DTRACING.ENABLED=true -DTRACING.LEVEL=2
    )
  )
)

Rem SRVCTL TRACEFILE
if not (%SRVCTL_TRACEFILE%)==() (
   set SRVM_PROPERTY_DEFS= %SRVM_PROPERTY_DEFS% -Dsrvm.srvctl.tracefile=%SRVCTL_TRACEFILE% 
)

Rem SRVM NATIVE TRACING
if not (%SRVM_NATIVE_TRACE%)==() (
   set SRVM_PROPERTY_DEFS= %SRVM_PROPERTY_DEFS% -DNATIVETRACING.ENABLED=true
)

Rem SRVM JNI TRACING
if not (%SRVM_JNI_TRACE%)==() (
   set SRVM_PROPERTY_DEFS= %SRVM_PROPERTY_DEFS% -DJNITRACING.ENABLED=true
)

:runcmd
rem Configuration file containing logging properties.
set SRVM_PROPERTY_DEFS= %SRVM_PROPERTY_DEFS% -Djava.util.logging.config.file=%ORA_CRS_HOME%\srvm\admin\logging.properties

set CMD=%JRE% %JRE_OPTIONS% -DORACLE_HOME=%ORACLE_HOME_PROP% -classpath %CLASSPATH% %SRVM_PROPERTY_DEFS% oracle.ops.opsctl.OPSCTLDriver %USER_ARGS% 

%CMD%

exit /b %ERRORLEVEL%

endlocal

