#!/usr/local/bin/perl
# 
# $Header: assistants/src/oracle/sysman/assistants/emca/scripts/modifyEMService.pl /main/1 2013/04/11 22:46:05 ssanklec Exp $
#
# modifyEMService.pl
# 
# Copyright (c) 2013, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      modifyEMService.pl - <one-line expansion of the name>
#
#    DESCRIPTION
#      This script changes OracleDBConsole and OracleAgent service startup type to Manual
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    ssanklec    04/04/13 - Creation

use Win32::Service;

print "Checking for Enterprise Manager Services.. \n";
$status = Win32::Service::GetServices('', \%services);
my $failedService ="";

if ($status) 
{
   changeService( \%services );
   if ($failedService ne "" )
   {
     print "Failed to modify following services $failedService to Manual. Please modify the Startup Type to Manual manually.\n";
     exit 1;
   }  

} else {
    print Win32::FormatMessage( Win32::GetLastError() );
    print("Unable to retrieve services. \n");
    exit 2;
}
 
 
sub changeService {
   my($hash_ref) = $_[0];
   @keys = keys( %$hash_ref );
   @sorted = sort( @keys );
   foreach $key (@sorted) {
   if($key =~ "OracleDBConsole" || $key =~ "OracleAgent" )
   {
     print "Changing service $key to demand (Manual) \n";
     my $cmd = "sc config " . $key. " start= demand";
     $status = system($cmd);
     if ($status == 0)
     {
       print "Successfully changed service $key to Manual.\n";
     }
     else
     {
       $failedService = $failedService .$key . " ";
     }
   }
   }
}
 
