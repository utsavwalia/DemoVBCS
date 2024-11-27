#!/bin/bash
# 
# BI Publisher Catalog Utility
# Product Version: 11.1.1.7.0 
# Last Update: 2/17/2010
# File Version: 1.15
#


BIP_UTIL_JARS="biputil.jar orai18n-mapping.jar i18nAPI_v3.jar orai18n.jar xdo-core.jar xdo-server.jar xmlparserv2.jar orai18n-collation.jar xdoparser11g.jar orawsdl-api.jar"

BIP_CLIENT_DIR=`dirname $0`
if [ -z $ORACLE_HOME ]; then
  if [ -d $BIP_CLIENT_DIR/../../modules ]; then
     ORACLE_HOME="$BIP_CLIENT_DIR/../.."
  fi
fi

if [ -n $ORACLE_HOME ]; then
 if [ -d $ORACLE_HOME/modules ]; then
    BIP_CLASSPATH=$ORACLE_HOME/../oracle_common/modules/oracle.webservices_11.1.1/orawsdl.jar:$ORACLE_HOME/modules/oracle.bithirdparty_11.1.1/javax/jaxws/activation.jar:$ORACLE_HOME/lib/xmlparserv2.jar:$ORACLE_HOME/jlib/orai18n-collation.jar:$ORACLE_HOME/jlib/orai18n-mapping.jar
  fi
fi

if [ -z $BIP_LIB_DIR ]; then
  if [ -d "./lib" ]; then
    BIP_LIB_DIR="./lib"
  elif [ -d $BIP_CLIENT_DIR/lib ]; then
    BIP_LIB_DIR=$BIP_CLIENT_DIR/lib
  elif [ -d $BIP_CLIENT_DIR/../lib ]; then
    BIP_LIB_DIR=$BIP_CLIENT_DIR/../lib
  else
    BIP_LIB_DIR=$BIP_CLIENT_DIR
  fi
fi

for i in $BIP_UTIL_JARS;
do
  BIP_UTIL_JAR=$BIP_LIB_DIR/$i
  if [ -f $BIP_UTIL_JAR ]; then
    BIP_CLASSPATH=$BIP_UTIL_JAR:$BIP_CLASSPATH
  fi
done

export CLASSPATH=$BIP_CLASSPATH:$CLASSPATH;

JVMOPTIONS="-Djavax.xml.parsers.DocumentBuilderFactory=com.sun.org.apache.xerces.internal.jaxp.DocumentBuilderFactoryImpl"

#if [ -z $BIP_CLIENT_CONFIG ]; then
#  BIP_CLIENT_CONFIG="./config"
#fi

JVMOPTIONS="$JVMOPTIONS -Dbip.client.config.dir=$BIP_CLIENT_CONFIG"

if [ $# -lt 1 ]; then
  echo 
  echo "Usage: "
  echo
  echo "Unzip BIP binary object:"
  echo "BIPCatalogUtil.sh -unzipObject source={source_xdoz/xdmz_path} target={target_directory_path} catalogPath={catalog_path} [overwrite={true|false}] [mode=fusionapps]"
  echo
  echo "Zip BIP object files:"
  echo "BIPCatalogUtil.sh -zipObject source={source_directory_path} target={target_xdoz/xdmz_path} [mode=fusionapps]"
  echo
  echo "Export BIP object from BIP Server:"
  echo "BIPCatalogUtil.sh -export [bipurl={http://hostname:port/xmlpserver} username={username} password={password}] catalogPath={catalog_path_to_object} target={target_filename_or_directory_path} [baseDir={base_output_directory_path}] extract={true|false} [overwrite={true|false}] [mode=fusionapps]"
  echo
  echo "Export catalog folder contents:" 
  echo "BIPCatalogUtil.sh -exportFolder [bipurl={http://hostname:port/xmlpserver} username={username} password={password}] catalogPath={catalog_path_to_folder} baseDir={base_output_directory_path} subFolders={true|false} extract={true|false} [overwrite={true|false}] [mode=fusionapps]"
  echo
  echo "List catalog folder contents:" 
  echo "BIPCatalogUtil.sh -listFolder [bipurl={http://hostname:port/xmlpserver} username={username} password={password}] catalogPath={catalog_path_to_folder} subFolders={true|false}"
  echo
  echo "Import BIP object to BIP Server:"
  echo "BIPCatalogUtil.sh -import [bipurl={http://hostname:port/xmlpserver} username={username} password={password}]  baseDir={base_directory_path} [overwrite=true|false] [mode=fusionapps]"
  echo
  echo "Import all BIP objects from a local folder"
  echo "BIPCatalogUtil.sh -import [bipurl={http://hostname:port/xmlpserver} username={username} password={password}] source={source_xdoz/xdmz_path or directory_path_of_object_files} [catalogPath={catalog_path}] [overwrite=true|false] [mode=fusionapps]"
  echo
  echo "Generate XLIFF from BIP file:"
  echo "BIPCatalogUtil.sh -xliff source={source_file_path} [target={target_directory_path}] [baseDir={base_output_directory_path}] [overwrite={true|false}]"
  echo
  echo "Check translatability of XLIFF:"
  echo "BIPCatalogUtil.sh -checkXliff source={xliff_file_path or foler_path} [level=ERROR|WARNING] [mode=fusionapps]"
  echo
  echo "Check accessibility of Template:"
  echo "BIPCatalogUtil.sh -checkAccessibility source={template_file_path or foler_path} [mode=fusionapps]"
  echo
  echo "Execute Job file:"
  echo "BIPCatalogUtil.sh {job_file}.xml [tasks={task_name1},{task_name2},...,[task_nameX}]"
  echo
  echo "Execute TestSuite file:"
  echo "BIPCatalogUtil.sh {TestSuite_file}.xml [tests={testcase_name1},{testcase_name2},...,[testcase_nameX}]"
  echo
  echo ""
  echo "Required Environment Variables: JAVA_HOME, BIP_LIB_DIR, (Optional) BIP_CLIENT_CONFIG"
  echo
  exit 1;
fi

#echo $CLASSPATH
if [ -n "$JAVA_HOME" ]; then
   $JAVA_HOME/bin/java $JVMOPTIONS oracle.xdo.tools.catalog.command.CommandRunner $@
else
  java $JVMOPTIONS oracle.xdo.tools.catalog.command.CommandRunner $@
fi
