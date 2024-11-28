#!/usr/local/bin/perl
# 
# $Header: install/utl/scripts/db/clientSetup.pl /main/6 2018/07/11 07:09:17 davjimen Exp $
#
# clientSetup.pl
# 
# Copyright (c) 2018, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      clientSetup.pl
#
#    DESCRIPTION
#      Perl script to launch client setup wizard for configuring Client home image.
#
#    MODIFIED   (MM/DD/YY)
#    davjimen    07/10/18 - add method to get the java command
#    davjimen    06/21/18 - set custom heap for win32
#    davjimen    06/01/18 - set custom heap for linux 32
#    davjimen    05/28/18 - add custom max heap size method
#    davjimen    03/07/18 - Creation
# 
use strict;
use warnings;
package Client;

use parent qw(CommonSetup);

sub new {
  my ($class) = @_;

  my $self = $class->SUPER::new(
    "TYPE" => "Client",
    "PRODUCT_DESCRIPTION" => "Oracle Client",
    "PRODUCT_JAR_NAME" => "instclient.jar",
    "SETUP_SCRIPTS" => "runInstaller,setup.bat",
    "LOG_DIR_PREFIX" => "InstallActions",
    "MAIN_CLASS" => "oracle.install.ivw.client.driver.ClientConfigWizard",
  );
  bless $self, $class;
  return $self;
}

my $client = new Client();

$client->main();

sub rootPreCheck() {
	# Nothing to do here
}

sub checkMaxHeapSize {
	my ($javaCmd, $heapSize) = @_;

	my $versionCmd = $javaCmd." ".$heapSize." -version 2>&1";
	my $versionOut = qx{$versionCmd};
	my $versionCode = $?;
	return ($versionOut,$versionCode);
}

sub getMaxHeapSizeArg() {
	my $self = shift;
	my $platformDirName = shift;
	my $javaCmd = shift;
	my $defaultMaxHeapSize = shift;
	my $reducedMaxHeapSize = "-Xmx1024m";
	
	# Custom max heap size might be required by win32, linuxS390 and linux 32bit
	if($platformDirName eq "linuxS390" || $platformDirName eq "linux" || $platformDirName eq "win") {
		# Check default
		my ($defaultCheckOut,$defaultCheckCode) = checkMaxHeapSize($javaCmd, $defaultMaxHeapSize);
		if($defaultCheckCode ne "0") {		
			# bug 28033755 - LINUX.ZSERIES31 max heap size is limited
			my ($reducedCheckOut,$reducedCheckCode) = checkMaxHeapSize($javaCmd, $reducedMaxHeapSize);
			if($reducedCheckCode eq "0") {
				return $reducedMaxHeapSize;
			} else {
				print "\nERROR: Failed to determine max heap size.\n";
				print "$reducedCheckOut\n";
				return "";
			}
		}
	}	
	return $defaultMaxHeapSize;
}

sub getJavaCmd() {
	my $self = shift;
	my $platform = shift;
	my $jreLoc = shift;
	my $dirSep = shift;
	my $platDirName = shift;
	my $javacmd = $jreLoc.$dirSep.'bin'.$dirSep.'java';

        # bug 28311062 - flag -d64 not required in hpia.c32
	if( $platform =~ /.*hpux.*/ ){
		my $fileBin = "/bin/file";
		my $orainstaller = $ENV{ORACLE_HOME}.$dirSep."oui".$dirSep."lib".$dirSep.$platDirName.$dirSep."liboraInstaller.so";
		my $fileCmd = $fileBin." ".$orainstaller." 2>&1";
		my $fileOut = qx{$fileCmd};
		my $fileCode = $?;
		if( $fileCode eq "0" ) {
			if($fileOut =~ /.*ELF-64.*/) {
				# Append -d64 to the java command
				$javacmd .= ' -d64';
			}
		}
	} else {
		$javacmd = $self->SUPER::getJavaCmd($platform, $jreLoc, $dirSep, $platDirName);
	}
	return $javacmd;
}

