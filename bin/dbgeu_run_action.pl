#!/usr/local/bin/perl
#
# $Header: dbgeu_run_action.pl 20-sep-2006.22:58:54 mfallen Exp $
#
# dbgeu_run_action.pl
#
# Copyright (c) 2006, Oracle. All rights reserved.  
#
#    NAME
#      dbgeu_run_action.pl - Diagnostic workBench Generic
#                            ddE User actions - RUN ACTION
#
#    DESCRIPTION
#      This script is used by DDE User Actions to capture the output
#      of external commands.
#
#    NOTES
#      <other useful comments, qualifications, etc.>
#
#    MODIFIED   (MM/DD/YY)
#    mfallen     09/20/06 - remove use diagnostics
#    mfallen     05/18/06 - cleanup debug information
#    mfallen     03/29/06 - creation
#

#------------------------------------------------------------------------------
# setup modules to use
use strict;
use warnings;
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# enable debug by setting $debug to anything but 0 (zero)
my $debug = 0;
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# check number of arguments
my $numargs = $#ARGV;

if ($debug)
  {
    print "Number of arguments: $#ARGV\n";
    print "Argument 1: $ARGV[0]\n";
    print "Argument 2: $ARGV[1]\n";
  }

($#ARGV==1) or die "Too few arguments provided: $! $?";
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# save current working directory
my $savedir = $ENV{'PWD'};
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# get input directory and verify it can be opened
my $indir;

# if an argument was provided, use it as the directory
if (@ARGV)
  {
   $indir = $ARGV[0];
  }
else
  {
   $indir = $ENV{'PWD'};
  }

opendir(DIR, $indir) or die "can't opendir $indir: $! $?";
closedir(DIR);

chdir($indir);
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# get output directory and verify it can be opened
my $outdir;

# if an argument was provided, use it as the directory
if (@ARGV)
  {
   $outdir = $ARGV[1];
  }
else
  {
   $outdir = $ENV{'PWD'};
  }

opendir(DIR, $outdir) or die "can't opendir $outdir: $! $?";
closedir(DIR);

chdir($outdir);
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# setup output file
my $outfile = ">$outdir/out.txt";
open(OUTFILE, $outfile) or die("Can't open ".$outfile.": $!");
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# get arguments for invocation
my @actarg;
my %adrenv;
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# get arguments for invocation
my $argfile="$indir/arguments.txt";
open(IFILE, $argfile) or die("Cannot open ".$argfile.": $! $?");

my ($par, $len, $val);
my $lim = 3;
my $i = 0;

# TODO - handle stray empty lines

while (<IFILE>)
  {
    # skip all comment lines
    next if /^#/;

    # skip lines without '::'
    next unless /:.*:/;

    print "Saw line: $_" if $debug;

    # split the line in three based on the first two colons
    ($par, $len, $val) = split(/:/, $_, $lim);

    print "par:$par len:$len val:$val\n" if $debug;

    chomp $par;

    # if length was specified, get a substring
    if ($len)
      {
        $val = substr($val, 0, $len);
      }
    else
      {
        chomp $val;
      }

    print "par:$par len:$len val:$val\n" if $debug;

    # if an argument, put into the argument array
    if ($par eq 'ARG')
      {
        print "Pushing into actarg\n" if $debug;
        push @actarg, $val;
      }
    # if an environment setting, put into the environment associative array
    else
      {
        print "Adding to adrenv\n" if $debug;
        $adrenv{$par} = $val;
      }
  }
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# get arguments for invocation
my $base = $adrenv{'ADR_BASE'};
my $home = $adrenv{'ADR_HOME'};
my $cmd  = $adrenv{'COMMAND'};
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# debug
#my ($key, $value);
#while ( ($key, $value) = each(%adrenv) )
#  {
#   print "\$key: $key \$value: $value\n";
#  }
#print "arg: @actarg\n";
#------------------------------------------------------------------------------

#------------------------------------------------------------------------------
# execute command
open(CMDFILE, " $cmd @actarg | ") or die "Command $cmd failed. $! $?\n";
print OUTFILE <CMDFILE>;

exit 0;

# End of program
#------------------------------------------------------------------------------

