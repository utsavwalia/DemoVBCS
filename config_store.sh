#!/bin/bash

PRODUCT_HOME=`cd -P $(dirname $0)/../../..;pwd`
ORACLE_HOME=`cd -P $PRODUCT_HOME/..;pwd`

# Get standard JDK
MW_HOME=$ORACLE_HOME
. $ORACLE_HOME/oracle_common/common/bin/commEnv.sh

LCM_CLI_JAR="$ORACLE_HOME/bi/lib/bi-servicelcm-cli.jar"

java -Doracle.bi.servicelcm.oraclehome="$ORACLE_HOME" -Doracle.bi.servicelcm.domainhome="$DOMAIN_HOME" -Doracle.bi.servicelcm.producthome="$PRODUCT_HOME" -Doracle.security.jps.config="$DOMAIN_HOME/config/fmwconfig/jps-config-jse.xml" -cp "$LCM_CLI_JAR" oracle.bi.servicelcm.cli_v2.LcmCli config_store "$@"

