REM #
REM # Copyright (c) 2001 , 2005 Oracle Corporation.  All rights reserved.
REM #
REM # PRODUCT
REM #   DIP
REM #
REM # FILENAME
REM #   odisrvreg.bat
REM #
REM # DESCRIPTION
REM #   This script is used to register the DIP Server on NT
REM #
REM # NOTE:

@echo off

set ORACLE_HOME=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home
set JAVA_HOME=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jdk

set PATH=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\bin;%PATH%

SET CLASSPATH="C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\oraclepki103.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\ldap\odi\jlib\sync.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\ldapjclnt10.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\ojmisc.jar"

\bin\java -classpath %CLASSPATH% oracle.ldap.odip.engine.OdiReg C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home %*
