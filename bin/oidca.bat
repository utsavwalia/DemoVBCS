@echo off

set ORACLE_HOME=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home
set JLIB_HOME=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib
set PATH=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\ldap\bin;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\bin;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\opmn\bin;%PATH%

set HELPJAR=help4.jar
set ICEJAR=oracle_ice.jar
set SHAREJAR=share.jar
set EWTJAR=ewt3.jar
set EWTCOMPAT=ewtcompat-3_3_15.jar
set NETCFGJAR=netcfg.jar
set DBUIJAR=dbui2.jar



set CLASSPATH="C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\ldap\lib\oidca.jar;%JLIB_HOME%\ldapjclnt11.jar;%JLIB_HOME%\%NETCFGJAR%;%JLIB_HOME%\%HELPJAR%;%JLIB_HOME%\%ICEJAR%%JLIB_HOME%\%SHAREJAR%;%JLIB_HOME%\%EWTJAR%;%JLIB_HOME%\%EWTCOMPAT%;%JLIB_HOME%\swingall-1_1_1.jar;%JLIB_HOME%\%DBUIJAR%;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\ldap\odi\jlib\sync.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\ldap\oidadmin\dasnls.jar;%JLIB_HOME%\ojmisc.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jdbc\lib\classes12.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\assistants\jlib\assistantsCommon.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\srvm.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\opmn\lib\optic.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\oraclepki.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\osdt_core.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\osdt_cert.jar"

C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jdk\bin\java -Xms48m -Xmx128m -Djava.security.policy=%s_java2policyFile% -DORACLE_HOME=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home -DLDAP_ADMIN=%LDAP_ADMIN% -classpath %CLASSPATH% oracle.ldap.oidinstall.OIDClientCA orahome=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home %*

