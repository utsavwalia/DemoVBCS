@echo off

setlocal
set JAVA_RT=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\bin\java
set OH=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home

set JLIBDIR=%OH%\jlib
set LIBDIR=%OH%\lib
set JDBCDIR=%OH%\jdbc\lib
set OJLIBDIR=%OH%\olap\jlib
set RDBMSJLIB=%OH%\rdbms\jlib
set UCPLIBDIR=%OH%\ucp\lib
set RUNTIME12DIR=%OH%\sqlj\lib

set EWT=%JLIBDIR%\share.jar;%JLIBDIR%\ewt3.jar
set JEWT4=%JLIBDIR%\jewt4.jar;%OJLIBDIR%\jle3.jar;%OJLIBDIR%\dbui4.jar
set KODIAK=%OJLIBDIR%\kodiak.jar
set JDBC2=%JDBCDIR%\ojdbc8.jar
set OHJ4=%JLIBDIR%\ohj.jar
set HELPSHARE=%JLIBDIR%\help-share.jar
set ICE=%JLIBDIR%\oracle_ice.jar
set WDEP=%OJLIBDIR%\workdep.zip
set API1=%OJLIBDIR%\collections.jar


set API2=%OH%\olap\api\lib\olap_api.jar;%OH%\olap\api\lib\olap_api_spl.jar
set API3=%OH%\olap\api\lib\awxml.jar
set GDK4=%JLIBDIR%\orai18n.jar;%JLIBDIR%\orai18n-utility.jar;%JLIBDIR%\orai18n-mapping.jar;%JLIBDIR%\orai18n-translation.jar;%JLIBDIR%\orai18n-collation.jar
set WKS=%OJLIBDIR%\xsjwork.jar
set UCP=%UCPLIBDIR%\ucp.jar
set RUNTIME12=%RUNTIME12DIR%\runtime12.jar

set AWM=%OJLIBDIR%\awm.jar;%OJLIBDIR%\awmdep.zip;%OJLIBDIR%\awmhelp.jar;%LIBDIR%\xmlparserv2.jar;%LIBDIR%\xmlcomp.jar


set START=oracle.olap.awm.app.AwmApp
set CLASSPATH=%WDEP%;%EWT%;%JEWT4%;%KODIAK%;%JDBC2%;%AWM%;%OHJ4%;%HELPSHARE%;%ICE%;%API1%;%API2%;%API3%;%GDK4%;%WKS%;%UCP%;%RUNTIME12%


cd %OH%\olap\awm
%JAVA_RT% -mx1024m -Dsun.java2d.noddraw=true -DORACLE_HOME=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home -cp %CLASSPATH% %START% %1 %2 %3 %4 %5 %6 %7 %8 %9 > awmrun.log
endlocal
