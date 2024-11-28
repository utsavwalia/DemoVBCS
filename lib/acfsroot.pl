#
#
# acfsroot.pl
#
# Copyright (c) 2007, 2021, Oracle and/or its affiliates. 
#
#    NAME
#      acfsroot.pl
#
#    DESCRIPTION
#      install/uninstall USM components from the distribution files
#      See section 4.2.1 of Design Note Supporting USM Installation
#
#    NOTES
#      acfsroot install [-h] [-s | -v | -t <0,1,2>] [-l <directory>]
#                       [-m Domain|Member]
#                       [-c <cluster manifest file location>]
#          install USM kernel drivers and commands.
#      acfsroot uninstall [-h] [-s | -v | -t <0,1,2>]
#          uninstall USM kernel drivers and commands.
#      acfsroot version_check [-h] [-t <0,1,2>]
#          check if USM components are available for installation.
#      acfsroot enable [-h] [-s | -v | -t <0,1,2>]
#          enable ADVM/ACFS CRS resources.
#      acfsroot disable [-h] [-s | -v | -t <0,1,2>]
#          disable ADVM/ACFS CRS resources.
#      acfsroot patch_verify [-l <directory>]
#          verify acfsroot installation
#
#    INSTALL ACTIONS
#      - verify that the user has root privs.
#      - checks that the proper install files exists
#      - unloads currently loaded drivers (if any).
#      - removes currently installed USM install files (if any).
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

use strict;
use Getopt::Std;
use Cwd 'abs_path';
use File::Basename;
use File::Copy;
use English;
use acfslib;
use osds_acfsroot;
use File::Spec::Functions;

# acfsutil command line option switch.
use Config;
my ($optc);
$optc = '-';
$optc = '/' if ($Config{osname} =~ /Win/);
my ($option_l_used);

sub main
{
  my ($sub_command);         # start or stop
  my ($preserve) = 0;        # uninstall: preserve tunable files - default = no
  my ($return_code);         # as the name implies
  # user options
  my (%opt);                 # user options hash - used by getopts()
  my ($install_kernel_vers); # -k : install kernel version (other than current)
  my ($install_files_loc);   # -l : location(s) of the distribution files
                             # -s : silent operation - no console output
                             # -v : verbose operation - additional output
                             # -m : Member - enables SHMU
                             #      Domain - enables SHML
                             # -c : Cluster credentials
                             # -h : help

  my ($cluster_manifest_loc);# This variable has the location of
                             # the cluster manifest file needed by acfsroot
  # In a DSC, the asm_storage_mode is near.
  my $asm_storage_mode = 'near';
  $option_l_used      = 0;   # -l option defined flag
  my ($option_e_used) = "";  # -e option defined flag for tsc tkfvinfolink12
  #                               only for internal use
  # user flags. See description above or usage message output
  my (%flags) = ( install        => 'hsvk:t:l:m:c:',
                  uninstall      => 'hsvpt:',
                  enable         => 'hst:v',
                  disable        => 'hsvt:',
                  version_check  => 'ht:k:',
                  patch_verify   => 'vl:',
                  print_elements => 'h:e:',
      );

  # supplied by the front end driver and 'guaranteed' to be there.
  # command is what the user actually typed in (sans directories).
  $COMMAND = shift(@ARGV);

  # supplied by user
  $sub_command = shift(@ARGV);

  # Enable command line access to library functions
  if (defined($sub_command) && ($sub_command eq 'lib_run_func'))
  {
    $return_code = lib_run_func "@ARGV";
    acfsroot_exit($return_code);
  }

  if (!lib_usm_supported() && defined($sub_command))
  {
    # OSD specific message generated in lib_usm_supported().

    if ($sub_command eq "install")
    {
      # Resolve ORACLE_HOME in the "wrapper scripts".
      osds_fix_wrapper_scripts();
      acfsroot_exit(USM_NOT_SUPPORTED);
    }
    elsif ($sub_command eq "enable")
    {
      # Enable requires a previous installation.
      acfsroot_exit(USM_NOT_SUPPORTED);
    }
    else
    {
      # all other sub-commands fall through.
    }
  }

  # sub commands "install", "uninstall", "enable", "disable", or "version_check"
  # must be supplied by the user.
  if (defined($sub_command))
  {
    if ($sub_command eq "-h")
    {
      usage("invalid", 0);
      acfsroot_exit(USM_SUCCESS);
    }
    elsif (!(($sub_command eq 'install')          ||
             ($sub_command eq 'uninstall')        ||
             ($sub_command eq 'enable')           ||
             ($sub_command eq 'disable')          ||
             ($sub_command eq 'version_check')    ||
             ($sub_command eq 'transport_config') ||
             ($sub_command eq 'transport_list')   ||
             ($sub_command eq 'patch_verify')     ||
             ($sub_command eq 'print_elements')))
    {
      # Illegal sub-command
      #If we are here. This is an invalid option.
      #Removing leading "-" in $sub_command. I'm getting the following error:
      # (Bad argc for usm:acfs-532)
      $sub_command =~ s/^[-]+//;
      if (!($sub_command eq "help"))
      {
        lib_error_print(532, "invalid option: %s", $sub_command);
      }
      usage("invalid", 0);
      acfsroot_exit(USM_FAIL);
    }
  }
  else
  {
    # no sub-command
    usage("invalid", 0);
    acfsroot_exit(USM_FAIL);
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
    $install_files_loc =~ s/(\/|\\)+$//;
    if (! File::Spec->file_name_is_absolute($install_files_loc))
    {
      lib_error_print(9388,
        "An absolute path name must be specified for the alternate location.");
      acfsroot_exit(USM_FAIL);
    }
    $option_l_used = 1;
  }
  if ($opt{'h'})
  {
    # print help information
    usage($sub_command, 0);
    acfsroot_exit(USM_SUCCESS);
  }
  if ($opt{'e'}){
    $option_e_used = $opt{'e'};
  }

  if ($opt{'s'} && $opt{'v'})
  {
    lib_error_print(9160,
      "Can not use the silent and verbose options at the same time.");
    acfsroot_exit(USM_FAIL);
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
  if ($opt{'c'})
  {
    # We get the location of the cluster manifest file
    $cluster_manifest_loc = $opt{'c'};
    $cluster_manifest_loc =~ s/(\/|\\)+$//;

    # If the file does not exist, we return an error
    unless (-e $cluster_manifest_loc)
    {
      lib_error_print(9195, "Unable to access the specified Cluster Manifest File: %s",
                      $cluster_manifest_loc);
      acfsroot_exit(USM_FAIL);
    }
  }

  # Add the content of $Config{osname} when the OS becomes supported
  my (%supportedOSforODA) = ('linux' => 1);

  # In order to determine if we need
  # to setup acfs remote, we need to go and do a series of checks in
  # the crsconfig_params file. Based on this table we will then define
  # this flag with the appropriate mode, if necessary.
  # 1) Local ASM Member Cluster - No SHIM Mode
  # 2) Local ASM Cluster        - No SHIM Mode
  # 3) App Member Cluster       - ASU Mode
  # 4) DB Member Cluster        - ASU Mode
  # 5) ODA domU                 - ASU Mode
  # 6) OPC domU                 - ASU Mode
  # 7) ODA dom1                 - ASL Mode
  # 8) OPC dom0                 - ASL Mode
  # 9) Domain Cluster           - ASL Mode
  #
  #
  # HOW TO disable ACFSR?
  # In a Member Cluster installation, ASM must be present locally in order for
  # ACFS to operate normally. We will rely on crsconfig_params' ASM_CONFIG to
  # be 'near' meaning ASM is running locally. This will setup the drivers in
  # standalone mode.
  # In a Domain Services Cluster installation, ASM would in theory always be
  # present. In order to disable ACFSR, we will use a USM_DISABLE_CCMB_INSTALL
  # environment variable to signal that we do NOT want the drivers to run in
  # ACFSR mode.
  #
  # We only check, if the O.S. is supported
  if ( (!defined($opt{'m'})) && defined($supportedOSforODA{$Config{osname}}))
  {
    if( isDomainClass() || isODA() || isOPCDom0() )
    {
      if( defined($ENV{'USM_DISABLE_ACFSR_INSTALL'}) &&
          $ENV{'USM_DISABLE_ACFSR_INSTALL'} == 1)
      {
        $opt{'m'} = 'Standalone';
      }
      else
      {
        $opt{'m'} = 'Domain';
      }
    }
    elsif ( (isMemberClass() || isODADomu() || isOPCDomu()) )
    {
      # We get the asm cluster mode. If it's a client, then we need
      # to check whether it's an indirect or direct storage
      my $asm_cluster_mode = lib_get_asm_cluster_mode();
      if ($asm_cluster_mode eq "CLIENT")
      {
        # If the cluster_manifest_loc is not defined, then the credentials
        # may be found under $ORACLE_HOME/gpnp/seed/asm/credentials.xml
        if (!defined($cluster_manifest_loc))
        {
          $cluster_manifest_loc = File::Spec->catfile($ORACLE_HOME,"gpnp","seed"
                                                      ,"asm","credentials.xml");
        }
        # If we are in an MC, the asm_storage_mode could be different
        # If we are in a Direct mode, we set it to 'near'
        # If we are in an Indirect mode, we set it to 'far'
        $asm_storage_mode = lib_get_asm_mode($cluster_manifest_loc); 
        $osds_acfslib::asm_storage_mode = $asm_storage_mode;
      }
      if ($osds_acfslib::asm_storage_mode eq "near")
      {
        $opt{'m'} = 'Standalone';
      }
      else
      {
        $opt{'m'} = 'Member';
      }
      
    }
  }

  if ($opt{'m'})
  {
    if ($supportedOSforODA{$Config{osname}})
    {
      # When modifying the supported modes, make sure you update
      # usm/src/cmds/internal/acfspatch/acfspatchinstall.pl
      my %supportedModes = ('Standalone' => 0,
                            'Domain'     => 1,
                            'Member'     => 2);

      if(exists($supportedModes{$opt{'m'}}) &&
         defined($osds_acfslib::DOM))
      {
        $osds_acfslib::DOM = $supportedModes{$opt{'m'}};
      }
      else
      {
        lib_error_print(9192, "unknown installation mode: %s",
                        $opt{'m'});
        acfsroot_exit(USM_FAIL);
      }
    }
    else
    {
      lib_error_print(9193,
                      "Use of the -m flag is not supported in this OS.");
      acfsroot_exit(USM_FAIL);
    }
  }

  $_ORA_USM_TRACE_ENABLED = 0;
  $_ORA_USM_TRACE_LEVEL = 0;
  if ( defined $opt{'t'}  )
  {
    if ($opt{'v'} || $opt{'s'})
    {
      lib_error_print(9188,
      "cannot use the trace option with the silent or verbose options");
      acfsroot_exit(USM_FAIL);
    }
    $_ORA_USM_TRACE_LEVEL = $opt{'t'};

    if( $_ORA_USM_TRACE_LEVEL == 0){
        $SILENT = 1;
        $VERBOSE = 0;
    }elsif( $_ORA_USM_TRACE_LEVEL == 1){
        $VERBOSE = 1;
        $SILENT = 0;
    }elsif( $_ORA_USM_TRACE_LEVEL == 2){
        $VERBOSE = 1;
        $SILENT = 0;
        $_ORA_USM_TRACE_ENABLED = 1;
    }else{
        lib_error_print( 9175, "Invalid trace level. Valid values for trace level are 0, 1 or 2.");
        acfsroot_exit(USM_FAIL);
    }
  }

  ##### command parsing complete #####

  #We'll be passing $install_files_loc for finding the
  #drivers in the alternate location, but we need to pass
  #the base location for install directory
  my $base_install_location;
  if (defined($install_files_loc))
  {
    my ($tmp) = -1;
    do
    {
      $tmp = index($install_files_loc, "/install", $tmp+1);
    } while (index($install_files_loc, "/install", $tmp+1) != -1);
    if ($tmp != -1)
    {
      $base_install_location = substr($install_files_loc, 0, $tmp+8);
    }
  }

  # perform required OSD initialization, if any.
  $return_code = osds_initialize($install_kernel_vers,
                                 $sub_command,
                                 $base_install_location,
                                 $option_l_used);
  if ($return_code != USM_SUCCESS)
  {
    # error messages generated by osds_initialize().
    acfsroot_exit(USM_FAIL);
  }

  # use the default location for media unless the user specified otherwise
  if (!defined($install_files_loc))
  {
    lib_trace(9999, "Setting install_files_loc to default for main");
    $install_files_loc = $USM_DFLT_DRV_LOC;
  }

  # version availability checks don't require privileged access
  if ($sub_command eq 'version_check')
  {
    # check the availability of USM components
    $return_code = version_check($install_kernel_vers, $install_files_loc);
    acfsroot_exit($return_code);
  }
  elsif ($sub_command eq 'print_elements')
  {
    # $option_e_used argument is for internal use: tkfvinfolink12
    # our_array_elements prints all the elements in arrays:
    # OH_BIN_COMPONENTS, MESG_COMPONENTS and USM_PUB_COMPONENTS
    our_array_elements($option_e_used);
    acfsroot_exit(USM_SUCCESS);
  }

  # verify root access
  if (!lib_am_root())
  {
    lib_error_print(9130, "Root access required");
    acfsroot_exit(USM_FAIL);
  }

  if ($sub_command eq 'install')
  {
    # During an install, which happens as part of an upgrade, utilize commands
    # out of the install area.  This prevents system installed commands,
    # such as acfsutil, from the previous version throwing an error when we
    # call it with a new option.
    # For 12.1, cmdlog is one such option which is not found in previous
    # releases.
    lib_trace( 9180, "Sub-command is '%s'", "install" );
    if (!defined($ENV{ADE_VIEW_ROOT}))
    {
      $ACFSUTIL = File::Spec->catfile($USM_DFLT_CMD_LOC, "acfsutil");
      lib_verbose_print_noalert(9505,
                        "Using acfsutil executable from location: '%s'",
                        $ACFSUTIL);
    }

    my $current_umask = umask();
    if( (defined($current_umask)) && ($current_umask != 00022))
    {
      my $str_umask = sprintf( "Current umask is '%o', setting to 0022", $current_umask);
      lib_trace(9999,  $str_umask);
      umask( 0022);
    }

    # install the USM components
    $return_code = install($install_kernel_vers,
                           $install_files_loc,
                           $sub_command,
                           $asm_storage_mode);
  }
  elsif ($sub_command eq 'uninstall')
  {
    # Set ACFSUTIL if not ADE Environment. If we remove /sbin/acfsutil
    # we might need to log actions after this.
    if (!defined($ENV{ADE_VIEW_ROOT}))
    {
      $ACFSUTIL = File::Spec->catfile($USM_DFLT_CMD_LOC, "acfsutil");
      lib_verbose_print_noalert(9505,
                         "Using acfsutil executable from location: '%s'",
                         $ACFSUTIL);
    }

    # uninstall the USM components
    # pass $install_files_loc to uninstall() as distribution files may be
    # needed during uninstall process
    $return_code = uninstall($install_files_loc, $preserve, $sub_command);
  }
  elsif ($sub_command eq 'enable')
  {
    # enable the ACFS resources
    $return_code = enable();
  }
  elsif ($sub_command eq 'disable')
  {
    # disable the ACFS resources
    $return_code = disable();
  }
  elsif ($sub_command eq 'patch_verify')
  {
    # verify patch installation
    osds_search_for_distribution_files($install_files_loc, $option_l_used);
    $return_code = osds_patch_verify();
    if($return_code == USM_SUCCESS)
    {
      lib_inform_print (9999,"Patch verify: SUCCESS");
    }
    else
    {
      lib_inform_print (9999,"Patch verify: FAILED");
    }
  }

  acfsroot_exit($return_code);
} # end main

sub install
{
  # We need to know the asm storage mode so that the drivers
  # are set correctly
  my ($install_kernel_vers, $install_files_loc, $sub_command,
      $asm_storage_mode) = @_;
  my ($no_load)  = 0;            # Do not load the newly installed bits.
  my ($preserve) = 1;            # Any tunable files are preserved.
  my ($return_code);
  my ($kernel_version) = osds_get_kernel_version();
  my ($reboot_recommended) = 0;
  my ($previous_install_detected_msg) = 0; # Do not print out the "previous
                                           # install detected" message when
  # calling lib_check_uninstall_\
  # required() because it is going
  # to get printed out when we call
  # uninstall().
  my ($alt_files_loc) = $install_files_loc;
  my ($tmp) = -1;
    lib_trace( 9176, "Entering '%s'", "install");

  if (defined($install_kernel_vers))
  {
    lib_trace( 9181, "Kernel version is '%s'", $install_kernel_vers);
    # We're installing USM for another kernel version - do not attempt to
    # load the drivers. The presumed scenario is that the user wants to
    # install USM for an about to be upgraded kernel. This way, USM can
    # be up and running upon reboot. Dunno if anyone will ever use this.
    $kernel_version = $install_kernel_vers;
    $no_load = 1;
  }

  # First, find the distribution files from which to install,
  # no point in going on if they can't be found.
  if (!defined($install_files_loc))
  {
    lib_trace(9999, "Setting install_files_loc to default for install");
    $install_files_loc = $USM_DFLT_DRV_LOC;
  }
  $return_code = osds_search_for_distribution_files($install_files_loc,
                                                    $option_l_used);

  # We try again instead of failing right away, using $install_files_loc
  if (($return_code != USM_SUCCESS) && (defined($install_files_loc)))
  {
    # Windows compatibility
    $install_files_loc =~ s/\\/\//g;

    do
    {
      $tmp = index($install_files_loc, "/install", $tmp+1);
    } while (index($install_files_loc, "/install", $tmp+1) != -1);
    if ($tmp != -1)
    {
      $alt_files_loc = substr($install_files_loc, 0, $tmp+8);
      lib_inform_print(9507, "Searching the alternative location: '%s'",
                       $alt_files_loc);
      $return_code = osds_search_for_distribution_files($alt_files_loc,
                                                        $option_l_used);
    }
  } # Done trying again

  if ($return_code == USM_SUCCESS)
  {
    $install_files_loc = $alt_files_loc;
    lib_inform_print(9300, "ADVM/ACFS distribution files found.");
  }
  else
  {
    lib_error_print(9301, "ADVM/ACFS installation cannot proceed:");
    if (defined($install_files_loc))
    {
      lib_error_print(9317,
                      "No ADVM/ACFS distribution media detected at " .
                      "location: '%s'", $install_files_loc);
    }
    else
    {
      lib_error_print(9303,
                      "No installation files found for OS kernel version %s.", $kernel_version);
    }
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    lib_trace( 9177, "Return from '%s'", "install");
    return USM_FAIL;

  }

  # Do not erase the oracleadvm.conf file


  # Can't continue if the currently loaded drivers can't be unloaded
  $return_code = lib_unload_usm_drivers($install_files_loc, $sub_command);
  if (($return_code != USM_SUCCESS) || (testFailMode() == 1))
  {
    if (($return_code == USM_REBOOT_RECOMMENDED) || (testFailMode() == 1))
    {
      lib_error_print(9427, "Failed to unload ADVM/ACFS drivers. A system reboot is recommended.");
      lib_trace( 9178, "Return code = %s", "USM_REBOOT_RECOMMENDED");
      lib_trace( 9177, "Return from '%s'", "install");
      return $return_code;
    }
    else
    {
      lib_error_print(9304,
                      "Installation cannot proceed: Failed to unload ADVM/ACFS drivers.");
      lib_trace( 9178, "Return code = %s", "NOT USM_REBOOT_RECOMMENDED");
      lib_trace( 9177, "Return from '%s'", "install");
      return $return_code;
    }
  }

  # Pass $install_files_loc to uninstall() as distribution files may be
  # needed during uninstall process
  if (uninstall($install_files_loc, $preserve, $sub_command) == USM_FAIL)
  {
    lib_error_print(9305, "ADVM/ACFS installation cannot proceed:");
    lib_error_print(9306, "Failed to uninstall previous installation.");
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    lib_trace( 9177, "Return from '%s'", "install");
    return USM_FAIL;
  }

  # Check tunable files
  check_tunable_files();

  # We have distribution files and no USM components are currently
  # installed or loaded - we can proceed with the installation.
  lib_inform_print(9307, "Installing requested ADVM/ACFS software.");

  # osds_search_for_distribution files() has set which files need
  # to be installed.
  $return_code = osds_install_from_distribution_files($reboot_recommended);

  # Save driver version before doing actual driver load.
  if ($return_code == USM_SUCCESS)
  {
    $return_code = acfslib::lib_oracle_drivers_conf("install");
  }
  else
  {
    if ($return_code == USM_REBOOT_RECOMMENDED)
    {
      lib_error_print(9428,
                      "Failed to load ADVM/ACFS drivers. A system reboot is recommended.");
      lib_error_print(9310, "ADVM/ACFS installation failed.");
      lib_trace( 9178, "Return code = %s", "USM_REBOOT_RECOMMENDED");
      $return_code = USM_REBOOT_RECOMMENDED;
    }
    else
    {
      lib_error_print(9429, "Failed to install ADVM/ACFS files.");
      lib_error_print(9310, "ADVM/ACFS installation failed.");
      lib_trace( 9178, "Return code = %s", "USM_FAIL");
      $return_code = USM_FAIL;
    }
  }

  if ($return_code == USM_SUCCESS)
  {
    if ($no_load == 0)
    {
      lib_inform_print (9308, "Loading installed ADVM/ACFS drivers.");
    }

    # ensure that all utilities and drivers are where they are expected to
    # be
    $return_code = osds_load_and_verify_usm_state($no_load,
                                                  $asm_storage_mode);
    if (($return_code == USM_SUCCESS) && (testFailMode() != 2))
    {

      lib_inform_print(9309, "ADVM/ACFS installation correctness verified.");

      # TODO Check for return code.
      acfslib::lib_osds_acfsr_configure($asm_storage_mode);

    }
    else
    {
      lib_error_print(9428,
                      "Failed to load ADVM/ACFS drivers. A system reboot is recommended.");
      lib_error_print(9310, "ADVM/ACFS installation failed.");
      lib_trace( 9178, "Return code = %s", "USM_REBOOT_RECOMMENDED");
      $return_code = USM_REBOOT_RECOMMENDED;
    }
  }

  lib_trace( 9177, "Return from '%s'", "install");
  return $return_code;
} # end install

# Enable ACFS drivers and registry resources
sub enable
{
  my $ret = USM_SUCCESS;
  my $ret1 = USM_SUCCESS;

  lib_trace( 9176, "Entering '%s'", "enable");
  # We are guaranteed here that the ADVM/ACFS supports this OS.

  if ((lib_check_drivers_installed() == 0) || (lib_check_drivers_loaded() == 0))
  {
    lib_error_print(9167,
              "ADVM/ACFS is not installed or loaded. Run 'acfsroot install'.");
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    lib_trace( 9177, "Return from '%s'", "enable");
    return USM_FAIL;
  }

  if (!((-e <$acfslib::_ORACLE_HOME/bin/crsctl*>) ||
        (-l <$acfslib::_ORACLE_HOME/bin/crsctl*>)))
  {
    lib_error_print(5062, "cannot query CRS resource");
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    lib_trace( 9177, "Return from '%s'", "enable");
    return USM_FAIL;
  }

  # For some reason, crsctl will sometimes return 0 even if
  # crs is down.  I suppose this is because the command
  # executed successfully.
  open CRSCTL, "$acfslib::_ORACLE_HOME/bin/crsctl check crs |";
  while (<CRSCTL>)
  {
    if (/CRS-4639/)
    {
      lib_error_print(5062, "cannot query CRS resource");
      close CRSCTL;
      lib_trace( 9178, "Return code = %s", "USM_FAIL");
      lib_trace( 9177, "Return from '%s'", "enable");
      return USM_FAIL;
    }
  }
  close CRSCTL;

  if (usm_resource_exists("drivers") == USM_SUCCESS)
  {
    # Upgrade the resources.
    $ret1 = modify_usm_drivers_resource();
    if ($ret1 != USM_SUCCESS)
    {
      $ret = USM_FAIL;
    }
  }
  else
  {
    # Install and start the resources.
    $ret1 = add_usm_drivers_resource();
    if ($ret1 != USM_SUCCESS)
    {
      $ret = USM_FAIL;
    }

    $ret1 = start_usm_drivers_resource();
    if ($ret1 != USM_SUCCESS)
    {
      $ret = USM_FAIL;
    }
  }
  if( $ret == USM_SUCCESS){
      lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
  }elsif( $ret == USM_FAIL){
      lib_trace( 9178, "Return code = %s", "USM_FAIL");
  }else{
      lib_trace( 9178, "Return code = %s", "$ret");
  }
  lib_trace( 9177, "Return from '%s'", "enable");

  return $ret;
}

# Disable ACFS drivers and registry resources
sub disable
{
  my $ret = USM_SUCCESS;

  lib_trace( 9176, "Entering '%s'", "disable");

  my $ret1 = delete_usm_drivers_resource();
  if ($ret1 != USM_SUCCESS)
  {
    $ret = USM_FAIL;
  }

  if( $ret == USM_SUCCESS){
      lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
  }elsif( $ret == USM_FAIL){
      lib_trace( 9178, "Return code = %s", "USM_FAIL");
  }else{
      lib_trace( 9178, "Return code = %s", "$ret");
  }

  lib_trace( 9177, "Return from '%s'", "disable");
  return $ret;
}

sub uninstall
{
  my ($install_files_loc, $preserve, $sub_command) = @_;
  my ($return_code);
  my ($previous_install_detected_msg) = 1; # print out the "previous
                                           # installation detected" message
                                           # when we call:
                                           # lib_check_uninstall_required
  lib_trace( 9176, "Entering '%s'", "uninstall");
  # If we're executing an uninstall and a previous installation does not exist
  if (($sub_command eq "uninstall")
    && (!lib_check_uninstall_required($previous_install_detected_msg)))
  {
    lib_error_print(9313, "No ADVM/ACFS installation detected.");
    lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
    lib_trace( 9177, "Return from '%s'", "uninstall");
    return USM_SUCCESS;
  }

  # Can't continue if the currently loaded drivers can't be unloaded
  $return_code = lib_unload_usm_drivers(undef, $sub_command);
  if ($return_code != USM_SUCCESS)
  {
    lib_trace( 9178, "Return code = %s", "NOT USM_SUCCESS");
    lib_trace( 9177, "Return from '%s'", "uninstall");
    return $return_code;
  }

  lib_inform_print(9314, "Removing previous ADVM/ACFS installation.");

  # Pass $install_files_loc to osds_usm_uninstall() as distribution files may
  # be needed during uninstall process
  $return_code = osds_usm_uninstall($install_files_loc, $preserve);
  if ($return_code == USM_SUCCESS)
  {
    lib_inform_print(9315,
                       "Previous ADVM/ACFS components successfully removed.");
  }

  # Clean driver configuration from oracledrivers.conf file
  acfslib::lib_oracle_drivers_conf("uninstall");

  if( $return_code == USM_SUCCESS){
      lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
  }elsif( $return_code == USM_FAIL){
      lib_trace( 9178, "Return code = %s", "USM_FAIL");
  }else{
      lib_trace( 9178, "Return code = %s", "$return_code");
  }
  lib_trace( 9177, "Return from '%s'", "uninstall");

  return $return_code;
} # end uninstall

sub version_check
{
  lib_trace( 9176, "Entering '%s'", "vers check");
  my ($install_kernel_vers, $install_files_loc) = @_;
  my ($return_code);
  my ($kernel_version) = osds_get_kernel_version();

  $return_code = osds_search_for_distribution_files($install_files_loc,
                                                    $option_l_used);

  if ($return_code == 0)
  {
    lib_inform_print(9316,
          "Valid ADVM/ACFS distribution media detected at: '%s'",
          $install_files_loc);
  }
  else
  {
    if (!defined($install_files_loc))
    {
      $install_files_loc = "";
    }
    lib_error_print(9317, "No ADVM/ACFS distribution media detected at " .
                          "location: '%s'", $install_files_loc);
  }

  lib_trace( 9178, "Return code = %s", "$return_code");
  lib_trace( 9177, "Return from '%s'", "vers check");
  return $return_code;
} # end check

################################################
# The following are static functions.
################################################

sub usage
{
  my ($sub_command, $abort) = @_;

  lib_trace( 9176, "Entering '%s'", "usage");
  if ($sub_command eq "install")
  {
    lib_error_print_noalert(9161,
                    " acfsroot install: Install ADVM/ACFS components.");

    lib_error_print_noalert(9185,
                    " %s [-h] [-s | -v | -t <0,1,2>] [-l <directory>]",
                            "Usage: acfsroot install");

    lib_error_print_noalert(9132,
		    "        [-h]             - print help/usage information");
    lib_error_print_noalert(9131,
		    "        [-s]             - silent mode" .
		    " (error messages only)");
    lib_error_print_noalert(9159,
		    "        [-v]             - verbose mode");
    lib_error_print_noalert(9332,
		    "        [-l <directory>] - location of the" .
		    " installation directory");
    lib_error_print_noalert(9189,
                    "        [-t <0,1,2> ]    - trace level");

  }
  elsif ($sub_command eq "uninstall")
  {
    lib_error_print_noalert(9162, " acfsroot uninstall: Uninstall ADVM/ACFS" .
		    " components.");
    lib_error_print_noalert(9186,
                     " Usage: acfsroot uninstall [-h] [-s | -v | -t <0,1,2>]");
    lib_error_print_noalert(9132,
		    "        [-h]             - print help/usage information");
    lib_error_print_noalert(9131,
		    "        [-s]             - silent mode" .
		    " (error messages only)");
    lib_error_print_noalert(9159,
		    "        [-v]             - verbose mode");
    lib_error_print_noalert(9387,
		    "        [-p]             - preserve tunable parameters");
    lib_error_print_noalert(9189,
                    "        [-t <0,1,2> ]    - trace level");

  }
  elsif ($sub_command eq "version_check")
  {
    lib_error_print_noalert(9163,
                    " acfsroot version_check: Check ADVM/ACFS version.");
    lib_error_print_noalert(9191,
	            " Usage: acfsroot version_check [-h] [-t <0,1,2>]");
    lib_error_print_noalert(9132,
		    "        [-h]             - print help/usage information");
    lib_error_print_noalert(9189,
                    "        [-t <0,1,2> ]    - trace level");

  }
  elsif ($sub_command eq "enable")
  {
    lib_error_print_noalert(9164,
                    " acfsroot enable: Enable ADVM/ACFS CRS resources.");
    lib_error_print_noalert(9184, " %s [-h] [-s | -v | -t <0,1,2>]",
		    "Usage: acfsroot enable");
    lib_error_print_noalert(9132,
		    "        [-h]             - print help/usage information");
    lib_error_print_noalert(9131,
		    "        [-s]             - silent mode" .
		    " (error messages only)");
    lib_error_print_noalert(9159,
		    "        [-v]             - verbose mode");
    lib_error_print_noalert(9189,
                    "        [-t <0,1,2> ]    - trace level");

  }
  elsif ($sub_command eq "disable")
  {
    lib_error_print_noalert(9165,
                    " acfsroot disable: Disable ADVM/ACFS CRS resources.");
    lib_error_print_noalert(9184, " %s [-h] [-s | -v | -t <0,1,2>]",
		    "Usage: acfsroot disable");
    lib_error_print_noalert(9132,
                            "        [-h]             - print help/usage information");
    lib_error_print_noalert(9131,
		    "        [-s]             - silent mode" .
                            " (error messages only)");
    lib_error_print_noalert(9159,
		    "        [-v]             - verbose mode");
    lib_error_print_noalert(9189,
                    "        [-t <0,1,2> ]    - trace level");
  }
  else
  {
    lib_error_print_noalert(9185,
                            " %s [-h] [-s | -v | -t <0,1,2>] [-l <directory>]",
                            "Usage: acfsroot install");
    lib_error_print_noalert(9186,
                     " Usage: acfsroot uninstall [-h] [-s | -v | -t <0,1,2>]");
    lib_error_print_noalert(9191,
                            " Usage: acfsroot version_check [-h] [-t <0,1,2>]");
    lib_error_print_noalert(9184, " %s [-h] [-s | -v | -t <0,1,2>]",
                                                     "Usage: acfsroot enable");
    lib_error_print_noalert(9184, " %s [-h] [-s | -v | -t <0,1,2>]",
                                                     "Usage: acfsroot disable");
  }

  lib_trace( 9177, "Return from '%s'", "usage");

  if ($abort)
  {
    acfsroot_exit(USM_FAIL);
  }
} # end usage

# acfsroot_exit does not return
#
sub acfsroot_exit
{
  my ($ret) = @_;
  lib_trace( 9176, "Entering '%s'", "acroot ex");
  lib_trace( 9178, "Return code = %s", "$ret");
  lib_trace( 9177, "Return from '%s'", "acroot ex");
  exit $ret;
}

# A function for error path testing; returns 0 if we are not testing an error path
sub testFailMode
{
  lib_trace( 9176, "Entering '%s'", "fail mode");
  if (defined($ENV{ADE_VIEW_ROOT}) && defined($ENV{_ORA_ACFSROOT_TEST}))
  {
    # 1 = Simulates failure during unload of drivers
    # 2 = Simulates failure during load of drivers
    lib_trace( 9178, "Return code = %s", "$ENV{_ORA_ACFSROOT_TEST}");
    lib_trace( 9177, "Return from '%s'", "fail mode");
    return ($ENV{_ORA_ACFSROOT_TEST});
  }
  lib_trace( 9178, "Return code = %s", "0");
  lib_trace( 9177, "Return from '%s'", "fail mode");
  return 0;
}

# check_tunable_files
#
# Check if tunables files exists in ORACLE_HOME and copy to O.S. Path
sub check_tunable_files
{
  #Check if $USM_TUNE_ORA_DIR exists
  unless (-d $USM_TUNE_ORA_DIR)
  {
    File::Path::make_path($USM_TUNE_ORA_DIR, {mode => 0755});
  }

  foreach my $tunefile ("acfstunables", "advmtunables")
  {
    my ($OS_TUNABLE_FILE) = "";
    my ($ORA_TUNABLE_FILE) = "";

    $OS_TUNABLE_FILE = File::Spec->catfile($USM_TUNE_OS_DIR, $tunefile);
    $ORA_TUNABLE_FILE = File::Spec->catfile($USM_TUNE_ORA_DIR, $tunefile);

    #If tunables file exists in the ORA_HOME location
    if (-e $ORA_TUNABLE_FILE)
    {
        unless (-l $ORA_TUNABLE_FILE)
        {
            if ((-e $OS_TUNABLE_FILE) ||
                (-l $OS_TUNABLE_FILE))
            {
                unlink($OS_TUNABLE_FILE);
            }
            unless (copy($ORA_TUNABLE_FILE,$OS_TUNABLE_FILE))
            {
                #Error
                lib_error_print(9999,
                                "Failed copying $ORA_TUNABLE_FILE to $OS_TUNABLE_FILE: $!.");
            }
        }
    }
    # In the else case, ORA_TUNABLE_FILE doesn't exists
    # If OS_TUNABLE_FILE exists, we'll copy to ORA_TUNABLE_FILE
    elsif (-e $OS_TUNABLE_FILE)
    {
        if ((-e $ORA_TUNABLE_FILE) ||
            (-l $ORA_TUNABLE_FILE))
        {
            unlink($OS_TUNABLE_FILE);
        }
        copy($OS_TUNABLE_FILE,$ORA_TUNABLE_FILE);
        acfslib::lib_chmod ("0664", $ORA_TUNABLE_FILE);
    }
  }
}

# our_array_elements
#
# Internal function for printing all the elements for arrays:
# OH_BIN_COMPONENTS, MESG_COMPONENTS, USM_PUB_COMPONENTS
# Use:
#     acfsroot print_elements -e <array>
sub our_array_elements
{
  my $str          = $_[0];
  my $last         = "";
  my $CLSECHO_ACFS = catfile($acfslib::_ORACLE_HOME, "bin", "clsecho ");
  my $split_char   = '/';
     $split_char   = '\\\\' if ($Config{osname} =~ /Win/);

  # Expected output:
  #  acfsdriverstate
  #  acfsload
  #  acfsregistrymount
  #  ...
  if ($str eq "OH_BIN_COMPONENTS")
  {
    my @COMP = (@OH_BIN_COMPONENTS, @OH_LIB_COMPONENTS);
    foreach my $value (@COMP)
    {
      $last = (split /$split_char/, $value)[-1];
      system("$CLSECHO_ACFS $last");
    }
  }
  elsif ($str eq "MESG_COMPONENTS")
  {
    foreach my $value (@MESG_COMPONENTS)
    {
      $last = (split /$split_char/, $value)[-1];
      system("$CLSECHO_ACFS $last");
    }
  }
  elsif ($str eq "USM_PUB_COMPONENTS")
  {
    foreach my $value (@USM_PUB_COMPONENTS)
    {
      $last = (split /$split_char/, $value)[-1];
      system("$CLSECHO_ACFS $last");
    }
  }
  elsif ($str eq "SBIN_COMPONENTS")
  {
    # Windows does not have SBIN_COMPONENTS
    if (! ($Config{osname} =~ /Win/) ){
       foreach my $value (@SBIN_COMPONENTS)
       {
         $last = (split /$split_char/, $value)[-1];
         system("$CLSECHO_ACFS $last");
       }
     }
   }
  else
  {
    system("$CLSECHO_ACFS Incorrect argument: $str");
  }
} # end our_array_elements()

main();
