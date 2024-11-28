# Copyright (c) 2003, 2004, Oracle. All rights reserved.  
#
#   NAME
#     aqxmlctl - Start and Stop the oc4j server.
#
#   DESCRIPTION
#
#     This is the script to start and stop aqxml oc4j instance
#     on Windows 
#
# MODIFIED
#    rbhyrava   11/04/04 - rbhyrava_aqxml_demo_oc4jdoc
#    rbhyrava-  10/29/04 - Creation
#

#
# Make sure certain environment variables are set 
#
ORACLE_HOME=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home
JAVA_HOME=
JRE_HOME=C:\Users\uwalia\Desktop\TRASH\VBCS\V1046557-01\Oracle_Home\oracle.jdk\jre\

export ORACLE_HOME
export JAVA_HOME
export JRE_HOME

PERL_BIN=$ORACLE_HOME/perl/bin
export PERL_BIN
#
# Set path so that our native executables can be found when run from java
#
PATH=$ORACLE_HOME/bin:$JAVA_HOME/bin:$PATH
export PATH

TNS_ADMIN=$ORACLE_HOME
export TNS_ADMIN

# Execute the aqxmlctl.pl
$PERL_BIN/perl $ORACLE_HOME/bin/aqxmlctl.pl $*

