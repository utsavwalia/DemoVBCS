# 
#
# afdroot.pl
# 
# Copyright (c) 2012, 2019, Oracle and/or its affiliates. All rights reserved.
#
#    NAME
#      afdroot.pl - <one-line expansion of the name>
#
#    DESCRIPTION
#      install/uninstall AFD components from the distribution files
#
#    NOTES
#      afdroot install -h [-s|-v] -l
#          install AFD kernel drivers and commands.
#      afdroot uninstall -h [-s|-v]
#          uninstall AFD kernel drivers and commands.
#      afdroot version_check -h -l
#          check if AFD components are available for installation.
#      afdroot scan
#          calls 'asmcmd afd_scan' as root to discover and manage AFD disks.
#          Note: not exposed, only used by ohasd root agent's action 'afdscan'.
#
#    INSTALL ACTIONS
#      - verify that the user has root privs.
#      - checks that the proper install files exists
#      - unloads currently loaded drivers (if any).
#      - removes currently installed AFD install files (if any).
#      - installs from the selected distribution files
#      - Loads the drivers to make sure that they load properly.
#      - Performs any required OSD actions, if needed.
#
#      User output should be done in this file when possible to ensure
#      cross platform similarity in command look and feel. However, it is 
#      understood that some OSD actions are specific to one platform only,
#      in which case it makes sense to do the output there.
#
#
# 

use strict;
use Getopt::Std;
use Cwd 'abs_path';
use File::Basename;
use File::Spec::Functions;
use File::Path;
use File::Path qw/make_path/;
use English;
use afdlib;
use acfslib;
use osds_acfsroot;
use osds_afdroot;

# acfsutil command line option switch.
use Config;
my ($optc);
$optc = '-';
$optc = '/' if ($Config{osname} =~ /Win/);

# set the product global variable to AFD
$acfslib::USM_CURRENT_PROD = USM_PROD_AFD;

sub main
{
  my ($sub_command);         # start or stop
  my ($preserve) = 0;        # uninstall: preserve tunable files - default = no.
  my ($return_code);         # as the name implies 
  # user options
  my (%opt);                 # user options hash - used by getopts()
  my ($install_kernel_vers); # -k : install kernel version (other than current)
  my ($install_files_loc);   # -l : location(s) of the distribution files 
  # -s : silent operation - no console output 
  # -v : verbose operation - additional output
  # -h : help

  # user flags. See description above or usage message output
  my (%flags) = ( install       => 'hsvk:l:',
                  uninstall     => 'hsvp',
                  version_check => 'hl:k:',
                  scan          => 'hs',
      );

  # process the command line for acfsutil cmdlog
  # We could just use "acfsutil cmdlog -s @ARGV"
  # but that wouldn't give us the absolute command path name;
  my ($opt, $opts);

  $opts = "";
  foreach $opt (@ARGV)
  {
    $opts = abs_path($0) if $opts eq "";  # command name
    $opts .= " $opt";
  }

  # supplied by the front end driver and 'guaranteed' to be there.
  # command is what the user actually typed in (sans directories).
  $COMMAND = shift(@ARGV);

  # supplied by user
  $sub_command = shift(@ARGV);

  # must be supplied by the user.
  if (defined($sub_command))
  {
    #Bug29862693: The below command issued during "transparent" GI ZIP only 
    if ($sub_command eq 'lib_run_func')
    {
      $return_code = acfslib::lib_run_func "@ARGV";
      afdroot_exit($return_code);
    }
    
    if (!(($sub_command eq 'install') ||
          ($sub_command eq 'uninstall') ||
          ($sub_command eq 'version_check') ||
          ($sub_command eq 'scan')))
    {
      # illegal sub-command
      usage("invalid", 0);
      afdroot_exit(USM_FAIL);
    }
  }
  else
  {
    # no sub-command
    usage("invalid", 0);
    afdroot_exit(USM_FAIL);
  }

  # parse user options
  %opt=();
  getopts($flags{$sub_command}, \%opt) or usage($sub_command, 1);
  if ($opt{'k'})
  {
    $install_kernel_vers = $opt{'k'};
  }
  if ($opt{'p'})
  {
    $preserve = 1;
  }
  if ($opt{'l'})
  {
    $install_files_loc = $opt{'l'};
    $install_files_loc =~ s/(\/|\\)$//;
    if (! File::Spec->file_name_is_absolute($install_files_loc))
    {
      lib_error_print(9388,
                      "An absolute path name must be specified for the alternate location.");
      afdroot_exit(USM_FAIL);
    }
  }
  if ($opt{'h'})
  {
    # print help information
    usage($sub_command, 0);
    afdroot_exit(USM_SUCCESS);
  }

  if ($opt{'s'} && $opt{'v'})
  {
    lib_error_print(9160,
                    "Can not use the silent and verbose options at the same time.");
    afdroot_exit(USM_FAIL);
  }

  if ($opt{'s'})
  {
    # do not generate console output - default is not silent.
    $SILENT = 1;
  }
  if ($opt{'v'})
  {
    # Generate additional console output - default is not verbose.
    $VERBOSE = 1;
  }

  ##### command parsing complete #####
  if ($sub_command eq 'scan')
  {
    # scan for AFD disks.
    # See notes in the file header. This internal scan subcommand is only used 
    # by orarootagent which has brought up oraafd resource before using this
    # subcommand.
    if (!lib_am_root())
    {
      lib_error_print(9130, "Root access required");
      afdroot_exit(USM_FAIL);
    }
    $return_code = afdroot_scan();
    afdroot_exit($return_code);
  }
  
  if ($sub_command eq "install")
  {
    if(!lib_asmlib_installed())
    {
      # Just fixing wrapper scripts with ORACLE_HOME 
      osds_afd_fix_wrapper_scripts();
      afdroot_exit(USM_NOT_SUPPORTED);
    } 
  }
  
  # check if AFD supported
  if (!lib_afd_supported())
  {
    # OSD specific message generated in lib_afd_supported().

    if (($sub_command eq "install") ||
        ($sub_command eq "version_check"))
    {
      # Resolve ORACLE_HOME in the "wrapper scripts".
      osds_afd_fix_wrapper_scripts();
      afdroot_exit(USM_NOT_SUPPORTED);
    }
    else
    {
      # all other sub-commands fall through.
    }
  }

  # sub commands "install", "uninstall", or "version_check"
  # perform required OSD initialization, if any.
  $return_code = osds_afd_initialize($install_kernel_vers, $sub_command);
  if ($return_code != USM_SUCCESS)
  {
    # error messages generated by osds_afd_initialize().
    afdroot_exit(USM_FAIL);
  }

  # use the default location for media unless the user specified otherwise
  if (!defined($install_files_loc))
  {
    $install_files_loc = $AFD_DFLT_DRV_LOC; 
  }

  # version availability checks don't require privileged access
  if ($sub_command eq 'version_check')
  {
    # check the availability of USM components
    $return_code = version_check($install_kernel_vers, $install_files_loc);
    afdroot_exit($return_code);
  }

  # verify root access
  if (!lib_am_root())
  {
    lib_error_print(9130, "Root access required");
    afdroot_exit(USM_FAIL);
  }

  if ($sub_command eq 'install')
  {
    my $current_umask = umask();
    if( ( defined($current_umask)) && ($current_umask != 00022))
    {
      my $str_umask = sprintf( "Current umask is '%o', setting to 0022", $current_umask);
      lib_trace(9999,  $str_umask);
      umask( 0022);
    }
    # install the USM components
    $return_code = install($install_kernel_vers,
                           $install_files_loc, $sub_command);
  }
  else
  {
    if ($sub_command eq 'uninstall')
    {
      # uninstall the USM components
      # pass $install_files_loc to uninstall() as distribution files may be
      # needed during uninstall process
      $return_code = uninstall($install_files_loc, $preserve, $sub_command);
    }
  }

  afdroot_exit($return_code);
} # end main

sub install
{
  my ($install_kernel_vers, $install_files_loc, $sub_command) = @_;
  my ($no_load) = 0;             # Do not load the newly installed bits.
  my ($preserve) = 1;            # Any tunable files are preserved.
  my ($return_code);
  my ($kernel_version) = osds_afd_get_kernel_version();
  my ($reboot_recommended) = 0;

  if (defined($install_kernel_vers))
  {
    # We're installing USM for another kernel version - do not attempt to
    # load the drivers. The presumed scenario is that the user wants to
    # install USM for an about to be upgraded kernel. This way, USM can
    # be up and running upon reboot. Dunno if anyone will ever use this.
    $kernel_version = $install_kernel_vers;
    $no_load = 1;
  }  
  
  # First, find the distribution files from which to install
  # No point in going on if they can't be found.
  $return_code = osds_afd_search_for_distribution_files($install_files_loc);
  if ($return_code == USM_SUCCESS)
  {
    lib_inform_print(627, "AFD distribution files found.");
  }
  else
  {
    lib_error_print(628, "AFD installation cannot proceed:");
    if (defined($install_files_loc))
    {
      lib_error_print(617,
                      "No AFD distribution media detected at " .
                      "location: '%s'", $install_files_loc);
    }
    else
    {
      lib_error_print(9303,
                      "No installation files found for OS kernel version " .
                      "%s.", $kernel_version);
    }
    return USM_FAIL;
  }

  # Can't continue if the currently loaded drivers can't be unloaded
  $return_code = lib_unload_afd_drivers($install_files_loc, $sub_command);
  if ($return_code != USM_SUCCESS)
  {
    if ($return_code == USM_REBOOT_RECOMMENDED)
    {
      lib_error_print(629, 
                      "Failed to unload AFD drivers. A system reboot is recommended.");
      return $return_code;
    }
    else
    {
      lib_error_print(630,
                      "Installation cannot proceed: Failed to unload AFD drivers.");
      return $return_code;
    }
  }

  # Pass $install_files_loc to uninstall() as distribution files may be
  # needed during uninstall process
  if (uninstall($install_files_loc, $preserve, $sub_command) == USM_FAIL)
  {
    lib_error_print(631, "AFD installation cannot proceed:");
    lib_error_print(9306, "Failed to uninstall previous installation.");
    return USM_FAIL;
  }

  # In ADE, create oracleafd.conf to test asmcmd commands that update the file
  if (defined($ENV{ADE_VIEW_ROOT}))
  {
    my ($uid, $gid);
    my $afdconf = AFD_CONF_PATH;
    my ( $name, $path, $suffix ) = fileparse( $afdconf, "\.conf");

    # create AFD CONF directory if it does not exist
    if(!(-d $path))
    {
      File::Path::make_path( $path, {mode => 0755} );
      if ($?)
      {
        lib_error_print(9345,
                        "Unable to create directory: '%s'.", $path);
        return USM_FAIL;
      }
    }

    # touch oracleafd.conf if it does not exist
    if (! -e $afdconf)
    {
      open HANDLE, ">$afdconf" or die "unable to open config file $afdconf: $!\n";
      close HANDLE;
    }

    # Populate with afd_diskstring. 
    open HANDLE, ">$afdconf";
    seek(HANDLE, 0, 0);
    truncate(HANDLE, 0);
    print HANDLE $AFD_DFLT_DSK_STR . "\n";
    close HANDLE;

    chmod 0664, $afdconf;

    # get the owner/group of the original file
    ($uid, $gid) = (stat($ENV{ADE_VIEW_ROOT}))[4,5];
    chown $uid, $gid, $afdconf;
  }

  # We have distribution files and no USM components are currently 
  # installed or loaded - we can proceed with the installation.
  lib_inform_print(636, "Installing requested AFD software.");

  # osds_search_for_distribution files() has set which files need
  # to be installed.
  $return_code = osds_afd_install_from_distribution_files($reboot_recommended);

  if ($return_code == USM_SUCCESS)
  {
    if ($no_load == 0)
    {
      lib_inform_print (637, "Loading installed AFD drivers.");
    }

    # ensure that all utilities and drivers are where they are expected to be
    $return_code = osds_load_and_verify_afd_state($no_load);
    if ($return_code == USM_SUCCESS)
    {
      lib_inform_print(638, "AFD installation correctness verified.");
    }
    else
    {
      lib_error_print(650,
                      "Failed to load AFD drivers. A system reboot is recommended.");
      lib_error_print(639, "AFD installation failed.");
      $return_code = USM_REBOOT_RECOMMENDED;
    }
  }
  else
  {
    if($return_code == USM_REBOOT_RECOMMENDED)
    {
      lib_error_print(650,
                      "Failed to load AFD drivers. A system reboot is recommended.");
      $return_code = USM_REBOOT_RECOMMENDED;
    }
    else
    {
      $return_code = USM_FAIL;
    }
    lib_error_print(640, "Failed to install AFD files.");
    lib_error_print(639, "AFD installation failed.");

    # On failure, remove oracleafd.conf
    if (defined($ENV{ADE_VIEW_ROOT}))
    {
      my $afdconf = AFD_CONF_PATH;
      unlink $afdconf if -e $afdconf;
    }
  }

  if ($return_code == USM_SUCCESS)
  {
    $return_code = acfslib::lib_oracle_drivers_conf("install");
  }
  return $return_code;
} # end install

sub afdroot_scan
{
  my ($return_code) = USM_SUCCESS;
  my $asmcmd = catfile ($ENV{'ORACLE_HOME'}, 'bin', 'asmcmd');
  my $cmd    = "$asmcmd afd_scan"; 
  my $ret;

  # execute the command
  $ret = system($cmd);
  
  if ($ret != 0)
  {
    lib_error_print(9999, "command '$cmd' failed ret '$ret'." );
    $return_code = USM_FAIL;
  }

  return $return_code;
} # end afdroot_scan

sub uninstall
{
  my ($install_files_loc, $preserve, $sub_command) = @_;
  my ($return_code);

  # Search for a previous installation
  # 19821209: Proceed even if driver file is not found in O.S path
  # (attempt to complete a partial [manual] cleanup)
  if (lib_check_any_afd_driver_installed())
  {
    lib_inform_print(632, "Existing AFD installation detected.");
  }

  # Can't continue if the currently loaded drivers can't be unloaded
  $return_code = lib_unload_afd_drivers(undef, $sub_command);
  if ($return_code != USM_SUCCESS)
  {
    return $return_code;
  }

  lib_inform_print(634, "Removing previous AFD installation.");

  # Pass $install_files_loc to osds_usm_uninstall() as distribution files may
  # be needed during uninstall process
  $return_code = osds_afd_uninstall($install_files_loc, $preserve);
  if ($return_code == USM_SUCCESS)
  {
    lib_inform_print(635,
                       "Previous AFD components successfully removed."); 
  }

  # in ADE, remove oracleafd.conf
  if (defined($ENV{ADE_VIEW_ROOT}))
  {
    my $afdconf = AFD_CONF_PATH;
    unlink $afdconf if -e $afdconf;
  }

  # Clean driver configuration from oracledrivers.conf file
  acfslib::lib_oracle_drivers_conf("uninstall");

  return $return_code;
} # end uninstall

sub version_check
{
  my ($install_kernel_vers, $install_files_loc) = @_;
  my ($return_code);
  my ($kernel_version) = osds_afd_get_kernel_version();

  $return_code = osds_afd_search_for_distribution_files($install_files_loc);

  if ($return_code == 0)
  {
    lib_error_print_noalert(616, 
          "Valid AFD distribution media detected at: '%s'",
          $install_files_loc);
  }
  else
  {
    lib_error_print_noalert(617, "No AFD distribution media detected at " .
                          "location: '%s'", $install_files_loc);
  }

  return $return_code;
} # end check

################################################
# The following are static functions.
################################################

sub usage
{
  my ($sub_command, $abort) = @_;

  if ($sub_command eq "install")
  {
    lib_error_print_noalert(601, " afdroot install: Install AFD components.");

    lib_error_print_noalert(602,
		    " %s [-h] [-s | -v] [-l <directory>]", 
		    "Usage: afdroot install");
    lib_error_print_noalert(603, 
		    "        [-h]             - print help/usage information");
    lib_error_print_noalert(604,
		    "        [-s]             - silent mode" .   
		    " (error messages only)");
    lib_error_print_noalert(605,
		    "        [-v]             - verbose mode");
    lib_error_print_noalert(606, 
		    "        [-l <directory>] - location of AFD" .   
		    " install files directory");
  }
  elsif ($sub_command eq "uninstall")
  {
    lib_error_print_noalert(607, " afdroot uninstall: Uninstall AFD" .
		    " components.");
    lib_error_print_noalert(608, " Usage: afdroot uninstall [-h] [-s | -v]");
    lib_error_print_noalert(603, 
		    "        [-h]             - print help/usage information");
    lib_error_print_noalert(604,
		    "        [-s]             - silent mode" .   
		    " (error messages only)");
    lib_error_print_noalert(605,
		    "        [-v]             - verbose mode");
  }
  elsif ($sub_command eq "version_check")
  {
    lib_error_print_noalert(610, " afdroot version_check: Check AFD version.");
    lib_error_print_noalert(611, 
		    " Usage: afdroot version_check [-h]");
    lib_error_print_noalert(603, 
		    "        [-h]             - print help/usage information");
  }
  else
  {
    lib_error_print_noalert(602,
		    " %s [-h] [-s | -v] [-l <directory>]", 
		    "Usage: afdroot install");
    lib_error_print_noalert(608, " Usage: afdroot uninstall [-h] [-s | -v]");
    lib_error_print_noalert(611, 
		    " Usage: afdroot version_check [-h]");
    lib_error_print_noalert(615, 
                    " For more information, use afdroot <command> -h");
  }

  if ($abort)
  {
    afdroot_exit(USM_FAIL);
  }
} # end usage

# afdroot_exit does not return
#
sub afdroot_exit
{
  my ($ret) = @_;
  # call acfsutil cmdlog - $optc handles the Windows/Unix cmd switch '-' or '/'.
  # the 't' option logs the termination of the command.
  #my ($cmd) =
  #        sprintf "$AFD_DFLT_CMD_LOC/acfsutil cmdlog %st $ret $COMMAND", $optc;
  #system($cmd);
  exit $ret;
}

main();
