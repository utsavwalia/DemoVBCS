# 
#
# afddriverstate.pl
# 
# Copyright (c) 2012, 2021, Oracle and/or its affiliates. 
#
#    NAME
#      afddriverstate.pl -  report whether or not AFD drivers
#                            are installed or loaded or
#                            supported
#
#
#    DESCRIPTION
#      afddriverstate installed
#        prints "true" or "false"
#        returns 0 if true, 1 if false
#      afddriverstate loaded
#        prints "true" or "false"
#        returns 0 if true, 1 if false
#      afddriverstate version
#        prints the driver versions (if installed)
#      afddriverstate supported
#        prints "Supported" or "Not Supported"
#        returns 0 or 1, respectively
#
#    NOTES
#
# 

use strict;
use File::Find;
use File::Spec::Functions;
use Getopt::Std;
use acfslib;
use afdlib;
use osds_afddriverstate;

sub main
{
  my ($ret);
  my ($state);
  my ($sub_command);
  # user options
  my (%opt);                 # user options hash - used by getopts()
  # user options.
  my (%flags) = ( installed => 's',
                  loaded  => 's',
                  supported  => 's',
                  version  => 's',
                );

  $COMMAND = shift(@ARGV);
  $sub_command = shift(@ARGV);

  if (!defined($sub_command))
  {
    usage();
    exit USM_FAIL;
  }

  if ($sub_command eq "-h")
  {
    usage();
    exit USM_SUCCESS;
  }
  elsif (!(($sub_command eq "installed") || ($sub_command eq "supported") ||
       ($sub_command eq "loaded") || 
       ($sub_command eq "version")))
  {
    usage();
    exit USM_FAIL;
  }

  # parse user options
  %opt=();
  getopts($flags{$sub_command}, \%opt) or usage(), exit USM_FAIL;
  if ($opt{'s'})
  {
    # do not generate console output - default is not silent.
    $SILENT = 1;
  }

  if ($sub_command eq "supported")
  {
    if (lib_afd_supported() && 
        lib_asmlib_installed() &&
        (osds_afd_compatible($sub_command) == USM_SUPPORTED))
    {
      lib_inform_print_noalert(9200, "Supported");
      $state = USM_SUCCESS;
    }
    else
    {
      lib_inform_print_noalert(9201, "Not Supported");
      $state = USM_FAIL;

      # Let tgipapi in HAS know that afd is not supported
      # This will be written in the oracledrivers.conf file
      if ((-e $CLSECHO) &&
          (-x $CLSECHO))
      {
        my ($ORA_CRS_HOME) = $ENV{ORA_CRS_HOME};
        my ($CLSECHO_AFD) = catfile($ORA_CRS_HOME, "bin", "clsecho") .
            " -p usm -f afd";
        my $myclsecho = "$CLSECHO_AFD -c info -m";
        my @res = qx /$myclsecho 9201/;
        # write to oracledrivers.conf the last line of
        # clsecho statement, "*-9201: Not Supported"
        lib_oracle_drivers_conf($res[-1]);
      }
      else
      {
        my ($res) = "AFD-9201: Not Supported";
        lib_oracle_drivers_conf($res);
      }
    }
    exit $state;
  }

  $state = USM_FAIL;

  if ($sub_command eq "installed")
  {
    if (lib_check_afd_drivers_installed())
    {
      $state = USM_SUCCESS;
      lib_inform_print_noalert(9203,
                       "AFD device driver installed status: 'true'");
    }
    else
    {
      lib_inform_print_noalert(9204,
                     "AFD device driver installed status: 'false'");
    }
  }
  elsif ($sub_command eq "loaded")
  {
    if (lib_check_afd_drivers_loaded())
    {
      $state = USM_SUCCESS;
      lib_inform_print_noalert(9205,
                       "AFD device driver loaded status: 'true'");
    }
    else
    {
      lib_inform_print_noalert(9206,
                       "AFD device driver loaded status: 'false'");
    }
  } 
  elsif ($sub_command eq "version")
  {
    if (lib_check_afd_drivers_installed() == 1)
    {
      my $ref = lib_get_drivers_version();
      print_afd_version($ref);
      if (defined($ref))
      {
        $state = USM_SUCCESS;
      }
    }
    else
    {
      lib_error_print_noalert(642, "AFD not installed");
      $state = USM_FAIL;
    }
  } 
  else
  {
    usage();
    $state = USM_FAIL;
  }

  exit $state;
}

sub print_afd_version()
{
  my $ref = shift;
  my %drvdata;

  if (!defined($ref))
  {
    lib_inform_print_noalert(642, "AFD not installed");
  }
  else
  {
    %drvdata = %{$ref};
    # Expected string 4.1.12-32.el6uek.x86_64(x86_64)/170121/MAIN/170130/MAIN
    lib_inform_print_noalert(9325,"    Driver OS kernel version = %s.",
                             $drvdata{"Installed"}{"KERNVERS"});
    lib_inform_print_noalert(9326,"    Driver build number = %s.",
                             $drvdata{"Installed"}{"BuildNo"});
    lib_inform_print_noalert(9212,"    Driver build version = %s.",
                             $drvdata{"Installed"}{"Version"}); 
    lib_inform_print_noalert(9547,"    Driver available build number = %s.",
                             $drvdata{"Available"}{"BuildNo"});
    lib_inform_print_noalert(9548,"    Driver available build version = %s.",
                             $drvdata{"Available"}{"Version"});
  }
}

sub usage
{
  lib_error_print_noalert(651,
    "Usage: %s [-h] [-orahome <home_path>] {installed | loaded | version | supported} [-s]", $COMMAND);
}

main();
