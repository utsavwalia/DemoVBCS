@echo off
setlocal

REM ----------------------------------------------
REM Set the 'FOP_HOME' variable equal to the full
REM path of where you install the Apache FOP
REM distribution if you plan to do XSL-FO to PDF
REM rendering using XSQL Pages and the REM custom
REM "FOP" serializer.
REM ----------------------------------------------
set FOP_HOME=

REM Oracle JDBC Driver Archive
REM set CP=%CP%;%ORACLE_HOME%\jdbc\lib\ojdbc5.jar

REM Oracle XML SQL Utility
REM set CP=%CP%;%ORACLE_HOME%\lib\xsu12.jar

REM Oracle XML Parser V2 (with XSLT Engine) Archive
set CP=%CP%;%ORACLE_HOME%\lib\xmlparserv2.jar

REM Oracle XSQL Servlet Archive
set CP=%CP%;%ORACLE_HOME%\lib\oraclexsql.jar

REM XSQLConfig.xml connection definition file
set CP=%CP%;%ORACLE_HOME%\xdk\admin

REM ====> [OPTIONAL] XSQLFOPSerializer
set CP=%CP%;%ORACLE_HOME%\lib\xsqlserializers.jar
set CP=%CP%;%FOP_HOME%\fop_bin_0_14_0.jar
set CP=%CP%;%FOP_HOME%\lib\w3c.jar

%JAVA_HOME%\bin\java -classpath %CP% oracle.xml.xsql.XSQLCommandLine %*
endlocal

