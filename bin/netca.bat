@echo off

rem Jar file classpath changes should be made in this file as well as classes/manifestNetca

@setlocal

@set OH=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home

@set JRE_DIR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre
@set JLIB_DIR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib

@set JRE=%JRE_DIR%\bin\java
@set JRE_JAR=%JRE_DIR%\lib\rt.jar;%JRE_DIR%\lib\i18n.jar

@set EWT3_JAR=%JLIB_DIR%\ewt3.jar
@set EWT_COMP_JAR=%JLIB_DIR%\ewtcompat.jar
@set HELP4_JAR=%JLIB_DIR%\help4.jar
@set JEWT4_JAR=%JLIB_DIR%\jewt4.jar
@set JNDI_JAR=%JLIB_DIR%\jndi.jar
@set NETCFG_JAR=%JLIB_DIR%\netcfg.jar
@set ICE_BROWSER_JAR=%JLIB_DIR%\oracle_ice.jar
@set ICE5_BROWSER_JAR=%JLIB_DIR%\oracle_ice5.jar
@set SHARE_JAR=%JLIB_DIR%\share.jar
@set ASSISTANTS_COMMON_JAR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\assistants\jlib\assistantsCommon.jar
@set NETCA_JAR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\assistants\netca\jlib\netca.jar
@set INSTALLER_JAR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oui\jlib\OraInstaller.jar
@set PREREQ_JAR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oui\jlib\OraPrereq.jar
@set PREREQ_CHECKS_JAR_1=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oui\jlib\OraPrereqChecks.jar
@set PREREQ_CHECKS_JAR_2=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\inventory\prereq\oui\OraPrereqChecks.jar
@set SRVM_JAR=%JLIB_DIR%\srvm.jar
@set SRVMHAS_JAR=%JLIB_DIR%\srvmhas.jar
@set SRVMASM_JAR=%JLIB_DIR%\srvmasm.jar
@set SUPERCLUSTER_JAR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\opsm\jlib\supercluster.jar
@set SUPERCLUSTER_COMMON_JAR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\opsm\jlib\supercluster-common.jar
@set XMLPARSER2_JAR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\lib\xmlparserv2.jar
@set NET_TOOLS_DIR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\network\tools
@set NETCA_DOC_DIR=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\assistants\netca\doc
@set CVU_JAR=%JLIB_DIR%\cvu.jar
@set DB_INSTALLER_FRAMEWORK=%OH%\install\jlib\installcommons_1.0.0b.jar

@set NETCA_HELP_JAR=%NETCA_DOC_DIR%\netcahelp.jar;%NETCA_DOC_DIR%\netcahelp_es.jar;%NETCA_DOC_DIR%\netcahelp_de.jar;%NETCA_DOC_DIR%\netcahelp_fr.jar;%NETCA_DOC_DIR%\netcahelp_ja.jar;%NETCA_DOC_DIR%\netcahelp_it.jar;%NETCA_DOC_DIR%\netcahelp_pt_BR.jar;%NETCA_DOC_DIR%\netcahelp_ko.jar;%NETCA_DOC_DIR%\netcahelp_zh_CN.jar;%NETCA_DOC_DIR%\netcahelp_zh_TW.jar

@set CLASSPATH=%DB_INSTALLER_FRAMEWORK%;%NETCA_JAR%;%ORACLE_OEM_CLASSPATH%

@set PWD=%CD%
cd %OH%\bin
@set PATH=%OH%\bin;%PATH%

REM @FOR /F "TOKENS=2 DELIMS=:." %I IN ('chcp') DO SET cp=%I
REM @set cp=%cp: =%
REM @set CODE_PAGE=Cp%cp%

"%JRE%" -Dsun.java2d.noddraw=true -DORACLE_HOME="%OH%" -Doracle.installer.not_bootstrap=true -XX:-OmitStackTraceInFastThrow -XX:CompileCommand=quiet -XX:CompileCommand=exclude,javax/swing/text/GlyphView,getBreakSpot -classpath "%CLASSPATH%" oracle.net.ca.NetCA %*
@set NETCA_EXIT_STATUS=%ERRORLEVEL%
cd %PWD%
exit /B %NETCA_EXIT_STATUS%
