@echo off


@set OH=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home
@set NUMBER_OF_ARGUMENTS=%*

if "%NUMBER_OF_ARGUMENTS%" LSS "1" goto usage
if "%NUMBER_OF_ARGUMENTS%" GEQ "1" goto invoker

:invoker
if "%1%"=="EMRCONFIG" goto orahome
if NOT "%1%" EQU "EMRCONFIG" goto okay

:usage
  echo Usage: rconfig input.xml [output.xml]
  goto End

:orahome
  set OH=%2%
  goto okay

:okay
@set TNS_ADMIN=
@set ORACLE_HOME=%OH%
@set JRE_CLASSPATH=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\lib\rt.jar
@set JRE_EXT_CLASSPATH=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\lib\ext\sunjce_provider.jar
@set I18N_CLASSPATH=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\lib\i19n.jar
@set EWT_CLASSPATH=%OH%\jlib\ewt3.jar;%OH%\jlib\ewtcompat-3_3_15.jar
@set BALISHARE_CLASSPATH=%OH%\jlib\share.jar
@set SWING_CLASSPATH=%OH%\jlib\swingall-1_1_1.jar
@set ICE_BROWSER_CLASSPATH=%OH%\jlib\oracle_ice.jar
@set HELP_CLASSPATH=%OH%\jlib\help4.jar;%OH%\jlib\jewt4.jar
@set KODIAK_CLASSPATH=%OH%\jlib\kodiak.jar
@set XMLPARSER_CLASSPATH=%OH%\lib\xmlparserv2.jar
@set GDK_CLASSPATH=%OH%\jlib\orai18n.jar;%OH%\jlib\orai18n-mapping.jar;%OH%\jlib\orai18n-utility.jar;%OH%\jlib\orai18n-collation.jar
@set JDBC_CLASSPATH=%OH%\jdbc\lib\ojdbc6.jar
@set NETCFG_CLASSPATH=%OH%\jlib\ldapjclnt19.jar;%OH%\jlib\%cs_netAPIName%;%OH%\jlib\ojmisc.jar;%OH%\jlib\oraclepki.jar;%OH%\jlib\opm.jar
@set SRVM_CLASSPATH=%OH%\jlib\srvm.jar;%OH%\jlib\srvmhas.jar;%OH%\jlib\srvmasm.jar;%OH%\jlib\cvu.jar
@set ASSISTANTS_COMMON_CLASSPATH=%OH%\assistants\jlib\assistantsCommon.jar
@set DBCA_CLASSPATH=%OH%\assistants\dbca\jlib\dbca.jar
@set ASMCA_CLASSPATH=%OH%\assistants\asmca\jlib\asmca.jar
@set RCONFIG_CLASSPATH=%OH%\assistants\jlib\rconfig.jar
@set INSTALLER_CLASSPATH=%OH%\oui\jlib\OraInstaller.jar;%OH%\install\jlib\installcommons_1.0.0b.jar
@set GNS_CLASSPATH=%OH%\jlib\gns.jar

@set CLASSPATH=%JRE_CLASSPATH%;%I18N_CLASSPATH%;%RCONFIG_CLASSPATH%;%DBCA_CLASSPATH%;%ASSISTANTS_COMMON_CLASSPATH%;%EWT_CLASSPATH%;%BALISHARE_CLASSPATH%;%SWING_CLASSPATH%;%ICE_BROWSER_CLASSPATH%;%HELP_CLASSPATH%;%KODIAK_CLASSPATH%;%XMLPARSER_CLASSPATH%;%GDK_CLASSPATH%;%SRVM_CLASSPATH%;%NETCFG_CLASSPATH%;%JDBC_CLASSPATH%;%ORACLE_OEM_CLASSPATH%;%INSTALLER_CLASSPATH%;%JRE_EXT_CLASSPATH%;%ASMCA_CLASSPATH%;%GNS_CLASSPATH%

@set PATH=%OH%\bin;%PATH%

"C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\BIN\JAVA" -DDEV_MODE=false -DTRACING.ENABLED=true -DTRACING.TOFILE=true -DTRACING.LEVEL=2 -DORACLE_HOME="%OH%" -Doracle.installer.not_bootstrap=true -mx128m oracle.sysman.assistants.rconfig.RConfig  %*
:End
exit /B %ERRORLEVEL%
