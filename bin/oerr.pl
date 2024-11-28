#!/usr/local/bin/perl
# 
# $Header: buildtools/scripts/oerr.pl /main/3 2015/10/06 11:09:31 pkharter Exp $
#
# oerr.pl
# 
# Copyright (c) 2011, 2015, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      oerr.pl - oracle error 
#
#    DESCRIPTION
#      This perl script is the working portion of a replacement for the
#      original oerr, which was written as a Bourne shell script, and 
#      hence not available on Windows.  It is invoked from a platform-specific
#      driver script.
#
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    pkharter    09/25/15 - bug 21548316 - fix msg id 0 problem
#    pkharter    11/07/11 - make facility search case-insensitive (13354567)
#    pkharter    09/27/11 - code review comments
#    pkharter    09/23/11 - print os error on failed file open
#    pkharter    09/16/11 - rewrite oerr in perl - perl script
#    pkharter    09/16/11 - Creation
# 
######################

###
#       Usage: oerr facility error
#
# This perl script is used to get the description and the cause and action
# of an error from a message text file when a facility code and error number
# are passed to it. 
#

######
# Module initializations
#
# standard modules:
#
use English;         # Lets us say "$CHILD_ERROR" instead of "$?"
                     # and $PROCESS_ID instead of "$$"
use strict;          # Enforce strict variables, refs, subs, etc.

use File::Basename;  # for dirname
use File::Spec::Functions;  # catfile for directory name


#
# Print some possibly useful debug output if requested
my $WantTrace = 0;
if ($ENV{ORACLE_TRACE} eq "T") {
    $WantTrace = 1;
}

#
# If ORACLE_HOME is not set, we will not be able to locate
# the facilities file or message text file.
if (! $ENV{ORACLE_HOME}) {
    die "ORACLE_HOME not set.  Please set ORACLE_HOME and try again.\n"
}

#
# Definition script "constants"
my $Facilities_File = catfile($ENV{ORACLE_HOME}, "lib", "facility.lis");

print "Facilities file:  $Facilities_File\n" if $WantTrace;

#
# Check script usage
if (@ARGV != 2) {
    die usage_string();
}


#
# Pickup the command line arguments
my $Facility = @ARGV[0];
my $Code = @ARGV[1];

print "Facility: $Facility, Code: $Code\n" if $WantTrace;


if ($Code =~ s/[^0-9]//g) {
    die "Non-numeric characters in error message code\n";
}

$Code =~ s/^0*([0-9])/$1/;    # strip off leading 0's, leave at least 1 digit


print "Code (trimmed): $Code\n" if $WantTrace;

#
# Get the facility information from the oerr data file
if (! open FACLIST, "<$Facilities_File") {
    die "Could not open facilities list file: $Facilities_File\n",
        "$OS_ERROR\n";
}

# The entries in this file are colon separated defining, for each
# facility (field 1), the component name (field 2), the "real" facility
# name for facilities with aliases (field 3) with a value of "*" for
# facilities without renamings and an optional facility description
# (field 4) 
#
#	facility:component:rename:description
#


my $Component;
my $Rename;

while (<FACLIST>) { 

    # the search for facility name is insensitive to argument case ...
    ($Component, $Rename) = /^$Facility:([^:]*):([^:]*):/i;

    if ($Component) {                # Found facility entry

        if ($Rename ne "*") {        # check for renaming

            print "Alias for $Facility is $Rename\n" if $WantTrace;

            $Facility = $Rename;     # found alias, start over 
            close FACLIST;
            open FACLIST, "<$Facilities_File";

        } else {

            # ... but we then use found facility field for message file name
            ($Facility) = /^($Facility)/i;

            print "Component: $Component, Facility: $Facility\n" if $WantTrace;

            last;
        }

    }    
}

if (! $Component) {                  # facility entry not found
    die "oerr: Unknown facility '$Facility' (or invalid entry)\n";
}


#
# The message file searched is always the US English file
my $Msg_File = catfile($ENV{ORACLE_HOME}, $Component, "mesg",
                       $Facility . "us.msg");

print "Message file: $Msg_File \n" if $WantTrace;


if (! open MSGFILE, "<$Msg_File") {
    die "oerr: Cannot access the message file $Msg_File\n", 
        "$OS_ERROR\n";
}

    
#
# Search the message file for the error code, printing the message text
# and any following comment lines, which should give the cause and action
# for the error.
my $found = 0;

while (<MSGFILE>) {
    if ($found) {
        if (/^\/\//) {
            print;
        } else {
            last;
        }
    }

    if (/^0*$Code[^0-9]/) {
        $found = 1;
        print;
    }
}

exit 0;


sub usage_string {
    return "Usage: oerr facility error\n\n",
    "Facility is identified by the prefix string in the error message.\n",
    "For example, if you get ORA-7300, \"ora\" is the facility and \"7300\"\n",
    "is the error.  So you should type \"oerr ora 7300\".\n\n",
    "If you get LCD-111, type \"oerr lcd 111\", and so on.\n";
}
