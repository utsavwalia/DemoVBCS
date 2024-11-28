@echo off
setlocal EnableDelayedExpansion

rem
rem where am I?
rem
set TOOLHOME=%~dp0\..
set TOOLROOT=%~dp0\..\..

rem Locate Java
if not "%ORACLE_HOME%" == "" (
    if exist "%ORACLE_HOME%\jdk\bin\java.exe" (
        set JAVA_HOME=%ORACLE_HOME%\jdk
        goto :locate_jars
    )
)

if "%JAVA_HOME%" == "" (
    if exist "%TOOLHOME%\jdk\jre\bin\java.exe" (
        set JAVA_HOME=%TOOLHOME%\jdk\jre
    ) else (
        if not exist "%TOOLHOME%\jdk\bin\java.exe" (
            echo ERROR: No Java
            echo %TOOLHOME%\jdk or JAVA_HOME should point to valid Java runtime
            exit/b 1
        )
        set JAVA_HOME=%TOOLHOME%\jdk
    )
) else (
    if not exist "%JAVA_HOME%\bin\java.exe" (
        echo ERROR: No Java
        echo JAVA_HOME should point to valid Java runtime
        exit/b 1
    )
)

rem
rem determine the location of jar files
rem

:locate_jars
if not exist "%TOOLROOT%\oracle_common" (
    if "%SRCHOME%" == "" (
        if not "%ORACLE_HOME%" == "" (
            if exist "%ORACLE_HOME%" (
                set OJLIB=%ORACLE_HOME%\jlib
            ) else (
                set OJLIB=%TOOLHOME%\jlib
            )
        ) else (
            set OJLIB=%TOOLHOME%\jlib
        )
        set PKILOC=!OJLIB!
        set RSALOC=!OJLIB!
        set OSDTLOC=!OJLIB!
    ) else (
        rem SRCHOME is defined
        set PROD_DIST=%SRCHOME%\entsec\dist
        set PKILOC=!PROD_DIST!\oracle.pki\modules\oracle.pki
        set RSALOC=!PROD_DIST!\oracle.rsa.crypto\modules\oracle.rsa
        set OSDTLOC=!PROD_DIST!\oracle.osdt.core\modules\oracle.osdt
    )
) else (
    rem oracle_common exists
    set MW_MOD=%TOOLROOT%\oracle_common\modules
    set PKILOC=!MW_MOD!\oracle.pki
    set RSALOC=!MW_MOD!\oracle.rsa
    set OSDTLOC=!MW_MOD!\oracle.osdt
)

set PKI=%PKILOC%\oraclepki.jar
set RSA=%RSALOC%\cryptoj.jar
set OSDT_CORE=%OSDTLOC%\osdt_core.jar
set OSDT_CERT=%OSDTLOC%\osdt_cert.jar

rem If any of the args is equal to "-fips140_mode" then assume FIPS 140 mode.
set FIPS140_MODE_FLAG=FALSE
for %%a in (%*) do (
    if "%%a" == "-fips140_mode" set FIPS140_MODE_FLAG=TRUE
)

if %FIPS140_MODE_FLAG% == FALSE (
    rem Check if FIPS 140 mode is enabled via the Java Security property.
    for /f %%o in ('""%JAVA_HOME%\bin\java" -cp "%OSDT_CORE%" oracle.security.crypto.provider.TransitionMode"') do (
        if "%%o" == "fips140" set FIPS140_MODE_FLAG=TRUE
    )
)

if %FIPS140_MODE_FLAG% == TRUE (
    rem Use the set of RSA BSAFE Crypto-J JARs that are required for FIPS 140.
    set RSA=%RSALOC%\cryptojce.jar;%RSALOC%\cryptojcommon.jar;%RSALOC%\jcmFIPS.jar
)

"%JAVA_HOME%\bin\java" -cp "%PKI%;%RSA%;%OSDT_CORE%;%OSDT_CERT%" oracle.security.pki.textui.OraclePKITextUI %*
set RESULT=%ERRORLEVEL%
exit /b %RESULT%
