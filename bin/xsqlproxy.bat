@echo off
setlocal

REM Uncomment the next line after updating the proxy host 
REM set PROXY_HOST=proxyhost.your

REM Oracle JDBC Driver Archive 
set CP=%ORACLE_HOME%\jdbc\lib\ojdbc5.jar;%CP%

REM Oracle XML Parser V2 (with XSLT Engine) Archive
set CP=%ORACLE_HOME%\lib\xmlparserv2.jar;%CP%

REM Oracle XML SQL Utility for Java Archive
set CP=%ORACLE_HOME%\lib\xsu12.jar;%CP%

REM Oracle XSQL Servlet Archive
set CP=%ORACLE_HOME%\lib\oraclexsql.jar;%CP%

REM XSQLConfig.xml connection definition file
set CP=%ORACLE_HOME%\xdk\admin;%CP%

%JDK_HOME%\bin\java -classpath %CP% oracle.xml.xsql.XSQLCommandLine %*
endlocal

