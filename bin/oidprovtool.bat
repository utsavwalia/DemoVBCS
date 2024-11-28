@echo off

REM #
REM # Copyright (c) 2001 Oracle Corporation.  All rights reserved.
REM #
REM # PRODUCT
REM #   OID Provisioning Tool
REM #
REM # FILENAME
REM #   oidprovtool.bat
REM #
REM # DESCRIPTION
REM #   This script is used to launch the provisioning tool
REM #
REM # NOTE:
REM #   This script is typically invoked as follows:
REM #
REM #

SETLOCAL

REM  Make sure that our JRE is used for this invocation.
IF Windows_NT == %OS% SET PATH=%s_JRE_LOCATION%\bin;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\bin;%PATH%
IF not Windows_NT == %OS% SET PATH="%s_JRE_LOCATION%\bin;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\bin;%PATH%"

REM Set class path
SET CLASSROOT=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\classes
SET LDAPJCLNT19=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\ldapjclnt19.jar
SET NETCFG=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\netcfg.jar
SET JNDIJARS=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\ldap.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\jndi.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\providerutil.jar

REM make sure ldapjclnt19.jar is present
IF NOT EXIST %LDAPJCLNT19% GOTO NO_LDAPJCLNT19JAR_FILE

SET CLASSPATHADD=%LDAPJCLNT19%;%JNDIJARS%;%CLASSROOT%;%NETCFG%;

SET JRE=jre -nojit
SET CLASSPATH_QUAL=cp

IF "%ORACLE_OEM_JAVARUNTIME%x" == "x" GOTO JRE_START
SET JRE=%ORACLE_OEM_JAVARUNTIME%\bin\java -nojit
SET CLASSPATH_QUAL=classpath
SET CLASSPATHADD=%CLASSPATHADD%;%ORACLE_OEM_JAVARUNTIME%\lib\classes.zip
SET CLASSPATHADD=%CLASSPATHADD%;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\javax-ssl-1_2.jar
SET CLASSPATHADD=%CLASSPATHADD%;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\jssl-1_2.jar
SET CLASSPATHADD=%CLASSPATHADD%;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\j2ee\home\jps-api.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\j2ee\home\jps-internal.jar

:JRE_START

C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jdk\bin\java -Xms48m -Xmx256m -%CLASSPATH_QUAL% %CLASSPATHADD% -DORACLE_HOME=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home  oracle.ldap.util.provisioning.ProvisioningProfile %*

GOTO THE_END

:NO_LDAPJCLNT19JAR_FILE
   ECHO Missing jar file
   ECHO %LDAPJCLNT19% not found
   GOTO THE_END

:THE_END
   ENDLOCAL
