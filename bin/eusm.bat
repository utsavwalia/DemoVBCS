@ echo off
Rem Copyright (c) 2006, 2020, Oracle and/or its affiliates. 
Rem All rights reserved.
Rem
Rem    NAME
Rem      eusm - Batch script to run Enterprise User Security admin tool
Rem
Rem    DESCRIPTION
Rem      Runs the enterprise user security admin tool
Rem
Rem    REVISION HISTORY
Rem    MODIFIED   (MM/DD/YY)
Rem    apfwkr      06/16/20 - Backport apfwkr_blr_backport_30786655_19.0.0.0.0
Rem                           from st_rdbms_19.2
Rem    apfwkr      04/21/20 - Backport skayoor_bug-30786655 from main
Rem    skayoor     02/17/20 - Bug 30786655:Add check for Trust Anchor
Rem                           Certificates to allow Non CA Certificate
Rem    srvakkal    10/27/17 - Correction of classpath
Rem    risgupta    09/28/17 - Bug 26734445 - Remove hardcoded reference
Rem    risgupta    08/07/17 - Bug 26539671 - Add classpath to support PKCS12 wallet

Rem External Directory Variables set by the Installer
SET OJDBC=ojdbc8.jar
SET RDBMSVER=19

"C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\bin\java" -classpath C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\oraclepki.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\osdt_cert.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\osdt_core.jar;"C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\\lib\rt.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jdbc\lib\%OJDBC%;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\rdbms\jlib\eusm.jar;C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\jlib\ldapjclnt%RDBMSVER%.jar" -Djdk.security.allowNonCaAnchor=true oracle.security.eus.util.ESMdriver %*


