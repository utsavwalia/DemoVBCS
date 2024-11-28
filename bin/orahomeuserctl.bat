
@echo off

@setlocal

@set OH=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home
@set JRE_LOCATION=jdk\jre
@set JLIB_LOCATION=jlib

@set JRE_DIR=%OH%\%JRE_LOCATION%
@set JLIB_DIR=%OH%\%JLIB_LOCATION%

@set JRE=%JRE_DIR%\bin\java

@set JNDI_JAR=%JLIB_DIR%\jndi.jar
@set SRVM_JAR=%JLIB_DIR%\srvm.jar
@set SRVMHAS_JAR=%JLIB_DIR%\srvmhas.jar
@set HOMEUSERCTL_JAR=%JLIB_DIR%\homeuserctl.jar

@set CLASSPATH=%HOMEUSERCTL_JAR%;%JNDI_JAR%;%SRVM_JAR%;%SRVMHAS_JAR%

@set PWD=%CD%
cd %OH%\bin
@set PATH=%OH%\bin;%PATH%

if (%OHUC_TRACE%)==() (
   @set OHUC_TRACE=8
)
@set OHUC_PROPERTY_DEFS=-DOHUC_TRACE=%OHUC_TRACE%

%JRE% -DORACLE_HOME=%OH% -classpath "%CLASSPATH%" %OHUC_PROPERTY_DEFS% oracle.homeuserctl.orahomeuserctl %*
@set ORAHOMEUSERCTL_EXIT_STATUS=%ERRORLEVEL%
cd %PWD%
exit /B %ORAHOMEUSERCTL_EXIT_STATUS%
