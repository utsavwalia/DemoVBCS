@echo off
REM #   DIP
REM #
REM # FILENAME
REM #   schemasync.bat
REM #
REM # DESCRIPTION
REM #   This script is used to synchronize schema on NT
REM #
REM # NOTE:


set ORACLE_HOME=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home
set JAVA_HOME=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jdk

set CLASSPATH="C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home/ldap/odi/jlib/dmu.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home/jlib/ldapjclnt12.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home/ldap/odi/jlib/sync.jar"

\bin\java -classpath %CLASSPATH% oracle.ldap.dmu.SchemaMigrater C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home %*


