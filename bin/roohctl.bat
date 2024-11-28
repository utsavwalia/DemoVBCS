@echo off

setlocal

@set OH=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home
@set XMLPARSER_CLASSPATH=%OH%\lib\xmlparserv2.jar
@set GDK_CLASSPATH=%OH%\jlib\orai18n.jar
@set JDBC_CLASSPATH=%OH%\jdbc\lib\ojdbc6.jar
@set BALISHARE_CLASSPATH=%OH%\jlib\share.jar
@set NETCFG_CLASSPATH=%OH%\jlib\ldapjclnt19.jar;%OH%\jlib\ojmisc.jar;%OH%\jlib\oraclepki.jar;%OH%\jlib\opm.jar
@set SRVM_CLASSPATH=%OH%\jlib\srvm.jar;%OH%\jlib\srvmhas.jar;%OH%\jlib\srvmasm.jar;%OH%\jlib\cvu.jar
@set ASSISTANTS_COMMON_CLASSPATH=%OH%\assistants\jlib\assistantsCommon.jar
@set ROOHCTL_CLASSPATH=%OH%\assistants\jlib\roohctl.jar
@set INSTALLER_CLASSPATH=%OH%\oui\jlib\OraInstaller.jar;%OH%\oui\jlib\OraCheckPoint.jar;%OH%\install\jlib\installcommons_1.0.0b.jar

@set CLASSPATH=%ROOHCTL_CLASSPATH%;%ASSISTANTS_COMMON_CLASSPATH%;%BALISHARE_CLASSPATH%;%XMLPARSER_CLASSPATH%;%GDK_CLASSPATH%;%NETCFG_CLASSPATH%;%SRVM_CLASSPATH%;%INSTALLER_CLASSPATH%

@set PATH=%OH%\bin;%PATH%
@set ORACLE_HOME=%OH%
"%OH%\jdk\jre\BIN\JAVA" -DIGNORE_PREREQS=%IGNORE_PREREQS% -DORACLE_HOME="%OH%" -Doracle.installer.not_bootstrap=true -DJDBC_PROTOCOL=thin -mx128m oracle.assistants.roohctl.RoohCtl  %*

exit /B %ERRORLEVEL%
