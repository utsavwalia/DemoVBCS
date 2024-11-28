Rem    skayoor     02/17/20 - Bug 30786655:Add check for Trust Anchor
Rem                           Certificates
Rem    risgupta    03/26/18 - Bug 27637921 - Update classpath to support SEPS
Rem    risgupta    09/28/17 - Bug 26734447 - Remove hardcoded reference

@echo off
SET OJDBC=ojdbc8.jar

"C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\bin\java" -DORACLE_HOME="C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home" -classpath "C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\lib\rt.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\lib\i18n.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\lib\jsse.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jdbc\lib\%OJDBC%;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\verifier8.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\jssl-1_1.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\ldapjclnt19.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\oraclepki.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\osdt_core.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\rdbms\jlib\usermigrate-1_0.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\osdt_cert.jar" -Djdk.security.allowNonCaAnchor=true oracle.security.rdbms.server.UserMigrate.umu.UserMigrate %*


