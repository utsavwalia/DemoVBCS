#!/usr/local/bin/perl
# 
# $Header: rdbms/src/common/java/oc4j/aqxmlctl.pl /main/6 2018/04/01 04:00:22 rtattuku Exp $
#
# aqxmlctl.pl
# 
# Copyright (c) 2004, 2018, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      aqxmlctl.pl - Single controller script for start and
#                       stop aqxml access
#
#    DESCRIPTION
#      Single entry point script for start and shutdown isqlplus server
#      This perl script is called by shell script aqxmlctl 
#      All the system variables are set from the shell script aqxmlctl
#
#      The usage of this script is:
#         sh aqxmlctl start|stop|deploy
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    vesegu      02/06/18 - reverting the librnm 19 changes as per Jay comments
#    bhshanmu    01/16/18 - bhshanmu_librnm19_rdbms2
#    ichokshi    11/16/17 - Bug 26734442: use BANNER_VER to print banner
#    bhshanmu    05/05/17 - bhshanmu_bug-26003322_linux
#    rbhyrava    10/03/08 - XbranchMerge rbhyrava_bug-7445175 from
#                           st_rdbms_11.1.0
#    rbhyrava    10/03/08 - bug fix 7445175&7432282 
#    rbhyrava    05/13/08 - pwd from commandline
#    rbhyrava    11/04/04 - rbhyrava_aqxml_demo_oc4jdoc
#    rbhyrava    10/29/04 - Creation
# 
#
# get the action, component and argument count ...

$action = $ARGV[0];
$pwd = $ARGV[1];
$argCount = scalar(@ARGV);

$SD="\/";
$SP=":";
$OS = $ENV{'OS'};
$SD="\\" if($os =~ /Win/i);
$SP=";" if($os =~ /Win/i);

$JAVA_HOME = $ENV{'JAVA_HOME'};
$ORACLE_HOME = $ENV{'ORACLE_HOME'};

$DB_SID = $ENV{'ORACLE_SID'};
$DB_HOST = $ENV{'HOST'};
$DB_PORT = getdblistenerport();
$BANNER_VER = $ENV{'BANNER_VER'};

$AQXML_OC4J_HOME = "${ORACLE_HOME}${SD}oc4j";
$AQXML_RMI_FILE=
    "${AQXML_OC4J_HOME}${SD}j2ee${SD}OC4J_AQ${SD}config${SD}rmi.xml";
$J2EE_HOME = "${AQXML_OC4J_HOME}${SD}j2ee${SD}home";

banner();                                        # print the banner.

if ($argCount ge 1)     #isqlplusctl start/stop
{
    if ($action eq "start")
    {
      startaqxml();
    }
    elsif ($action eq "stop")
    {
      stopaqxml();
    }
    elsif ($action eq "deploy")
    {
      deployaqxml();
    }
    else 
    {
      displayHelp();
    }
}
else 
{
    displayHelp();
}


# subroutine to display banner
sub banner()
{
  print "AQXML $BANNER_VER\n";
  print "Copyright (c) 2004 Oracle.  All rights reserved.\n";
}



# subroutine to display help

sub displayHelp()
{ 
    print "Invalid arguments\n";
    print "\nUnknown command option $action\n"; 
    print "Usage:: \n";
    print "       aqxmlctl start|stop <password>\n";
}

# 
# Sub routine to stop the AQXML Instance
#
sub stopaqxml()
{
#
# Get rmi port from rmi.xml
#
    $rmiportno = getrmiport();
    $AQ_RMI_PORT = "$rmiportno";
    print $rmiportno; 
    my($timeinmills) = time();

    print "\nStopping AQXML ...\n";

    chdir("$J2EE_HOME");

    system("${JAVA_HOME}${SD}bin${SD}java -jar ${J2EE_HOME}${SD}admin.jar ".
          " ormi://localhost:$AQ_RMI_PORT/aqxmldemo admin $pwd " .
          " -shutdown force");

   # Give JAVA enough time to stop aqxml instance 
    sleep(30);
    print "AQXML instance stopped.\n";
    exit 0;
}


sub getdblistenerport()
{
  $_=`lsnrctl stat | grep "PROTOCOL=tcp"`;
  /(.*)PORT=(.*)\)\)\)/;
  $dblistenport=$2;
  return $dblistenport;
}

sub getrmiport()
{
# Open the rmi.xml file

open(AQXMLRMI,"$AQXML_RMI_FILE") || die "Cannot open ${AQXML_RMI_FILE}.\n";
# Read the file line by line
while (<AQXMLRMI>)
{
  # Check for the line containing the word "port="
  if (/^\s*<rmi-server port=/i)
  {
    if(/"[0-9]+"/)
    {
        $& =~ /[0-9]+/;
        $rmiport = "$&";
        last; # break out of the loop
    }
  }
}
# Now the port variable just contains the port number
close(AQXMLRMI);
return $rmiport;
}

# startaqxml
# 1) argument list
#
sub setupaqxml()
{
   $debug = false;
    system("rm -fr ${AQXML_OC4J_HOME}${SD}aq");
    system("mkdir ${AQXML_OC4J_HOME}${SD}aq");

   if ( ! -f '${AQXML_OC4J_HOME}${SD}aq${SD}xmlparserv2.jar' ) {
    system("cp $ORACLE_HOME${SD}lib${SD}xmlparserv2.jar ${AQXML_OC4J_HOME}${SD}aq");
    if ($debug) { print "\n1.xmlparserv2.jar copied."; }
   }

   if (! -f '${AQXML_OC4J_HOME}${SD}aq${SD}xsu12.jar') {
    system("cp $ORACLE_HOME${SD}lib${SD}xsu12.jar ${AQXML_OC4J_HOME}${SD}aq");
    if ($debug) { print "\n2.xsu12.jar copied."; }
   }
   if (! -f '${AQXML_OC4J_HOME}${SD}aq${SD}xschema.jar') {
    system("cp $ORACLE_HOME${SD}lib${SD}xschema.jar ${AQXML_OC4J_HOME}${SD}aq");
    if ($debug) { print "\n3.xschema.jar copied."; }
   }
   if (! -f '${AQXML_OC4J_HOME}${SD}aq${SD}ojdbc5dms.jar') {
    system("cp $ORACLE_HOME${SD}jdbc${SD}lib${SD}ojdbc5dms.jar ${AQXML_OC4J_HOME}${SD}aq");
    if ($debug) { print "\n4.ojdbc5dms.jar copied."; }
   }
   if (! -f '${AQXML_OC4J_HOME}${SD}aq${SD}dms.jar') {
    system("cp $ORACLE_HOME${SD}oc4j${SD}lib${SD}dms.jar ${AQXML_OC4J_HOME}${SD}aq${SD}dms.jar");
    if ($debug) { print "\n5.dms.jar copied."; }
   }
   if (! -f '${AQXML_OC4J_HOME}${SD}aq${SD}ojdl.jar' ){
    system("cp $ORACLE_HOME${SD}oc4j${SD}diagnostics${SD}lib${SD}ojdl.jar ${AQXML_OC4J_HOME}${SD}aq${SD}ojdl.jar");
    if ($debug) { print "\n6.ojdl.jar copied."; }
   }
   if (! -f '${AQXML_OC4J_HOME}${SD}aq${SD}servlet.jar') {
    system("cp $ORACLE_HOME${SD}oc4j${SD}j2ee${SD}home${SD}lib${SD}servlet.jar ${AQXML_OC4J_HOME}${SD}aq${SD}servlet.jar");
    if ($debug) { print "\n7.servlet.jar copied."; }
   }
   if (! -f '${AQXML_OC4J_HOME}${SD}aq${SD}xdb.jar') {
    system("cp $ORACLE_HOME${SD}rdbms${SD}jlib/xdb.jar ${AQXML_OC4J_HOME}${SD}aq");
    if ($debug) { print "\n8.xdb.jar copied."; }
   }
   if (! -f '${AQXML_OC4J_HOME}${SD}aq${SD}aqxml.jar') {
    system("cp $ORACLE_HOME${SD}rdbms${SD}jlib/aqxml.jar ${AQXML_OC4J_HOME}${SD}aq");
    if ($debug) { print "\n9.aqxml.jar copied."; }
   }
    system("cp $ORACLE_HOME${SD}jlib${SD}orai18*.jar ${AQXML_OC4J_HOME}${SD}aq");
    if ($debug) { print "\n10.orai18.jar copied."; }
}
    
setupaqxml;

    

sub startaqxml()
{
    print "Starting AQXML instance....\n";
    chdir("$J2EE_HOME");
    #print "$DB_HOST $DB_PORT $DB_SID\n" ;
           #"  ${J2EE_HOME}${SD}lib${SP}".
           #"${ORACLE_HOME}${SD}oc4j${SD}lib${SP}".
           #"${ORACLE_HOME}${SD}oc4j${SD}webservices${SD}lib${SP}".
           #"${ORACLE_HOME}${SD}oc4j${SD}diagnostics${SD}lib${SP}".
           #"${J2EE_HOME}${SP}".
           #"${J2EE_HOME}${SD}oc4j${SD}jdbc${SD}lib${SP}".
           #"${J2EE_HOME}${SD}oc4j${SD}j2ee${SD}home${SP}".
           #"${ORACLE_HOME}${SD}jlib${SD}srvm.jar${SP}".
           #"${J2EE_HOME}${SD}oc4j${SD}lib\"".

    system("$JAVA_HOME${SD}bin${SD}java " . 
           " -DMYDB_HOST=\"$DB_HOST\"" .
           " -DMYDB_PORT=\"$DB_PORT\"" .
           " -DMYDB_SID=\"$DB_SID\"" .
           "  -Doc4j.autoUnpackLockCount=-1".
           " -Djava.ext.dirs=\"${AQXML_OC4J_HOME}${SD}aq\"" .
           " -jar ${J2EE_HOME}${SD}oc4j.jar ".
 " -config ${AQXML_OC4J_HOME}${SD}j2ee${SD}OC4J_AQ${SD}config${SD}server.xml&"
        );

    sleep(10);
    print "AQXML started.\n";
    exit 0;
}


sub deployaqxml 
{
    create_deployini();
    setupaqxml();

    print "Deploying  AQXML instance....\n";
    #system("cp ${ORACLE_HOME}${SD}..${SD}javavm${SD}j2ee${SD}deploytool/db_oc4j_deploy.jar $J2EE_HOME") ;
    chdir("$J2EE_HOME");
    system("$JAVA_HOME${SD}bin${SD}java ". 
           "  -Doc4j.autoUnpackLockCount=-1".
            " -classpath ".
            "${J2EE_HOME}${SD}db_oc4j_deploy.jar${SP}".
            "${ORACLE_HOME}${SD}jlib${SD}srvm.jar${SP}".
            "${J2EE_HOME}${SD}jazn.jar${SP}".
            "${J2EE_HOME}${SD}oc4j.jar".
            " oracle.j2ee.tools.deploy.DbOc4jDeploy".
            " -oraclehome $ORACLE_HOME -password $pwd ".
            " -inifile ${ORACLE_HOME}${SD}rdbms${SD}demo${SD}aqxml.ini"
           ) ;
    print "Deploying  AQXML Completed....\n";
    make_secure();
    print "Deploy Done ....\n";
    sleep(2);
    exit 0;

}
sub create_deployini {
  print "Creating rdbms${SD}demo${SD}aqxml.ini....\n";
  
  $fl = "$ORACLE_HOME${SD}rdbms${SD}demo${SD}aqxml.ini";
   system("rm $fl" ) ;
   system("echo '[component]' >$fl" ) ;
   system("echo 'CMP_NAME=OC4J_AQ' >>$fl" ) ;
   system("echo 'HTTP_PORT=5760'>>$fl" ) ;
   system("echo 'JMS_PORT=5740'>>$fl" ) ;
   system("echo 'RMI_PORT=5720'>>$fl" ) ;
   system("echo 'RMIS_PORT=5710'>>$fl" ) ;
   system("echo 'DISTRIBUTED=false\n\n'>>$fl" ) ;
   system("echo '[application]'>>$fl" ) ;
   system("echo 'CMP_NAME=OC4J_AQ'>>$fl" ) ;
   system("echo 'APP_DEPLOYMENT_NAME=aqxmldemo'>>$fl" ) ;
   system("echo 'APP_LOCATION=$ORACLE_HOME/rdbms/demo/aqxmldemo.ear'>>$fl" ) ;
   system("echo 'WEB_APP_NAME=aqxmldemo_web'>>$fl" ) ;
   system("echo 'CONTEXT_ROOT=/aqserv/servlet\n\n'>>$fl" ) ;
}

sub make_secure {
 print "Secure website ....\n";
$file =
    "${AQXML_OC4J_HOME}${SD}j2ee${SD}OC4J_AQ${SD}config${SD}http-web-site.xml";
$keystorefile= "${ORACLE_HOME}${SD}rdbms${SD}demo${SD}keystore";
  system ("cp $file $file.prot") ;
  open(IN, "< $file.prot");
  open(OUT, ">$file");
  while (<IN>) {
    s!port=!secure="true" port=!;
    s!load-on-startup!max-inactivity-time="200" shared="true" load-on-startup!;
    s!</web-site>!<ssl-config keystore="$keystorefile" keystore-password="$pwd" />\n</web-site>!;
  print OUT;
  }
  close IN ; close OUT;
}
