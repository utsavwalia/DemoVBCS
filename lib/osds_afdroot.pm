#
#
# osds_afdroot.pm
# 
# Copyright (c) 2007, 2021, Oracle and/or its affiliates. 
#
#
#    NAME
#      osds_afdroot.pm - Windows OSD component of afdroot.
#
#    DESCRIPTION
#      Purpose
#          Install/uninstall AFD commands and drivers.
#
#    NOTES
#      All user visible output should be done in the common code when possible.
#      This will ensure a consistent look and feel across all platforms.
#      It is understood that due to the OSD nature of the file, some output
#      needs to be done here.
#
#

use strict;
use usmvsn;
use Win32;
use File::Spec::Functions;
require Win32API::File;
require Exporter;
package osds_afdroot;
our @ISA = qw(Exporter);
our @EXPORT = qw(
                 osds_afd_fix_wrapper_scripts
                 osds_afd_get_kernel_version
                 osds_afd_initialize
                 osds_afd_install_from_distribution_files
                 osds_afd_search_for_distribution_files
                 osds_load_and_verify_afd_state
                 osds_afd_uninstall
                 $MEDIA_FOUND
                 $ORACLE_HOME
                 $AFD_DFLT_DRV_LOC
                 $USM_DFLT_CMD_LOC
                 $AFD_DFLT_DSK_STR
                 );

use acfslib;
use osds_acfslib;
use afdlib;
use osds_afdlib;
use osds_acfsroot;

our ($ORACLE_HOME) = $ENV{ORACLE_HOME};
my  ($SYSTEM_ROOT) = $ENV{SYSTEMROOT};
my  ($MINUS_L_DRIVER_LOC);

# If ORACLE_HOME points to the db home (no usm/install dir), point it to the
# CRS_HOME. Both ORACLE_HOME and ORA_CRS_HOME are set in the wrapper scripts for
# the individual commands.
$ORACLE_HOME = $ENV{ORA_CRS_HOME} if (!(-e "$ORACLE_HOME\\usm\\install"));

#default AFD discovery string
our ($AFD_DFLT_DSK_STR) = "afd_diskstring='\\\\.\\Harddiskvolume*'";

use constant AFD_DRIVER => "orclafdvol.sys";

# installation source locations
my ($SHIPHOME_BASE_DIR) = "$ORACLE_HOME\\usm\\install";
my ($CMDS_SRC_DIR)      = "$SHIPHOME_BASE_DIR\\cmds\\bin";
my ($MESG_SRC_DIR)      = "$SHIPHOME_BASE_DIR\\..\\mesg";

# AFD Library name
my ($LIBAFD_STATIC)     = "oraafd".usmvsn::vsn_getmaj().".lib";
my ($LIBAFD)            = "oraafd".usmvsn::vsn_getmaj().".dll";
my ($LIBAFD_BASENAME)   = "oraafd";

our ($USM_DFLT_CMD_LOC) = "$ORACLE_HOME\\bin"; # exported loc of install cmds

# installed component locations
my ($DRIVER_DIR)      = "$SYSTEM_ROOT\\system32\\drivers";  # driver location
my ($OH_BIN_DIR)      = "$ORACLE_HOME\\bin";
my ($OH_LIB_DIR)      = "$ORACLE_HOME\\lib";
my ($MESG_DST_DIR)    = "$ORACLE_HOME\\usm\\mesg";

# Used by '-l' only.
my ($USM_LIB_SRC_DIR);
my ($USM_BIN_SRC_DIR);

our ($MEDIA_FOUND) = '';                      # path name to media
my  (@DRIVER_COMPONENTS) = (
   "orclafdctl.sys",
   "orclafdvol.sys", 
   "orclafddsk.sys",
);

my (@OH_BIN_COMPONENTS) = (
   "$OH_BIN_DIR\\afdroot.bat",
   "$OH_BIN_DIR\\afdinstall.exe",
   "$OH_BIN_DIR\\afdload.bat",
   "$OH_BIN_DIR\\afddriverstate.bat",
   "$OH_BIN_DIR\\$LIBAFD",
   "$OH_BIN_DIR\\afdtool.exe",
);

my (@OH_LIB_COMPONENTS) = (
  "$OH_LIB_DIR\\afddriverstate.pl",   "$OH_LIB_DIR\\afdroot.pl",
  "$OH_LIB_DIR\\afdlib.pm",
  "$OH_LIB_DIR\\afdload.pl",
  "$OH_LIB_DIR\\afdtoolsdriver.bat",  "$OH_LIB_DIR\\osds_afddriverstate.pm",
  "$OH_LIB_DIR\\osds_afdlib.pm",
  "$OH_LIB_DIR\\osds_afdroot.pm", 
  "$OH_LIB_DIR\\osds_afdload.pm",     "$OH_LIB_DIR\\$LIBAFD_STATIC",
);

my (@CMD_COMPONENTS) = (@OH_BIN_COMPONENTS, @OH_LIB_COMPONENTS);

my (@MESG_COMPONENTS) = (
     "$MESG_DST_DIR\\afdus.msb",
);


my ($minus_l_specified) = 0;   # Alternate install location specified by user.

# set by osds_afd_search_for_distribution_files() and
# consumed by osds_afd_install_from_distribution_files() 
my ($MEDIA_PATH);

our ($AFD_DFLT_DRV_LOC);

# Perl stat
use constant MODE => 2;

# osds_afd_initialize
#
# Perform OSD required initialization if any
#
sub osds_afd_initialize
{
  # lib_osds_afd_supported() has already determined and verified that the
  # machine architecture ($ARCH) and OS type are supported
  # and are valid.

  if (!((defined($ORACLE_HOME)) && (-e "$ORACLE_HOME/lib/afdroot.pl")))
  {
    lib_error_print(9389,
    "ORACLE_HOME is not set to the location of the Grid Infrastructure home.");
    return USM_TRANSIENT_FAIL;
  }
  
  # default location - over-ride with the -l option
  $AFD_DFLT_DRV_LOC =
          "$ORACLE_HOME\\usm\\install\\Windows\\$OS_SUBDIR\\$ARCH\\bin";

  return USM_SUCCESS;
}

# osds_afd_get_kernel_version
#
sub osds_afd_get_kernel_version
{
  return $OS_TYPE;
} # end osds_afd_get_kernel_version

use File::Copy;

# osds_afd_install_from_distribution_files
#
# Install the AFD components from the specified distribution files
# The media has already been validated by the time we get here
# by osds_afd_search_for_distribution_files(). Also, any previous AFD installation
# will have been removed.
#
sub osds_afd_install_from_distribution_files
{
  my ($component);                 # curent component being installed
  my ($driver_path);               # full path name of the driver source
  my ($afdinstall);               # full path name of afdinstall.exe
  my ($ret_val);                   # return code from system()
  my ($return_code) = USM_SUCCESS;

  # The commands have been verified to exist. 
  # No work is needed here.

  $afdinstall = "$OH_BIN_DIR\\afdinstall.exe";

  # install the drivers
  $driver_path = $MEDIA_PATH;

  lib_verbose_print (626, "AFD driver media location is '%s'", 
                 $MEDIA_PATH);

  # install the AFD driver  
  $ret_val = run_afdinstall(
                      $afdinstall, "/i", "$driver_path\\");
  if ($ret_val == USM_FAIL)
  {
    my ($driver) = "AFD";
    lib_error_print(9340, "failed to install driver '%s'", $driver);
    $return_code = $ret_val;
  }
  elsif ($ret_val == USM_REBOOT_RECOMMENDED)
  {
    # If we are sending USM_REBOOT_RECOMMMENDED, we don't need to continue
    # installing.
    return $ret_val;
  }


  if ($minus_l_specified)
  {
    # Normally, the ORACLE_HOME/{bin,lib} components are installed via the
    # mapfiles. But, when the user specifies an alternate location via the
    # '-l' option on the command line, we need to install the alternate 
    # OH/{bin,lib} files also. The OH commands are, conveniently located
    # with the sbin commands.
    #
    # If we are replacing existing files, we want to preserve the original
    # file attributes.
    my ($orig_mode);

    foreach $component (@CMD_COMPONENTS) 
    {
      my (@array) = split /\\/, $component;
      my ($file) = $array[-1];
      my ($target) = $component;
      my ($source) = "$CMDS_SRC_DIR\\$file";

      if ($file =~ ".dll\$")
      {
         $source = "$USM_BIN_SRC_DIR\\$file";
      }
      elsif ($file =~ ".lib\$")
      {
         $source = "$USM_LIB_SRC_DIR\\$file";
      }

      lib_verbose_print (9504, "Copying file '%s' to the path '%s'", 
                        $source,
                        $target);

      $orig_mode = (stat($target))[MODE] & 0777;
      chmod 0755, $target;

      $ret_val = copy ($source, $target);

      chmod $orig_mode, $target;
      if ($ret_val == 0)
      {
        lib_error_print(9346, "Unable to install file: '%s'.", $target);
        $return_code = USM_FAIL;
      }
    }

    foreach $component (@MESG_COMPONENTS) 
    {
      my (@array) = split /\\/, $component;
      my ($file) = $array[-1];
      my ($target) = $component;
      my ($source) = "$MESG_SRC_DIR\\$file";

      lib_verbose_print (9504, "Copying file '%s' to the path '%s'", 
                        $source,
                        $target);

      $orig_mode = (stat($target))[MODE] & 0777;
      chmod 0755, $target;

      $ret_val = copy ($source, $target);

      chmod $orig_mode, $target;
      if ($ret_val == 0)
      {
        lib_error_print(9346, "Unable to install file: '%s'.", $target);
        $return_code = USM_FAIL;
      }
    }


    # Copy the drivers to the install area so that
    # subsequent "afdroot install"s will get the patched bits should
    # the user forget to use the -l option. It also allows us to compare
    # checksums on the drivers in the "install" area to the "installed"
    # area at load time. This will catch situations where users installed
    # new bits but did run "afdroot install".
    foreach $component (@DRIVER_COMPONENTS)
    {
      my (@array) = split /\\/, $component;
      my ($file) = $array[-1];
      my ($target) = "$AFD_DFLT_DRV_LOC/$component";
      my ($source) = "$MINUS_L_DRIVER_LOC\\$file";
      
      lib_verbose_print (9504, "Copying file '%s' to the path '%s'", 
                         $source,
                         $target);
      
      $orig_mode = (stat($target))[MODE] & 0777;
      chmod 0755, $target;

      $ret_val = copy ($source, $target);

      chmod $orig_mode, $target;
      if ($ret_val == 0)
      {
        lib_error_print(9346, "Unable to install file: '%s'.", $target);
        $return_code = USM_FAIL;
      }
    }
  }

  return $return_code;
} # end osds_afd_install_from_distribution_files

# osds_afd_search_for_distribution_files
#
# Search the location(s) specified by the user for valid media
# If a specific kernel and/or USM version is specified,
# look for that only that version.
#
sub osds_afd_search_for_distribution_files
{
  my ($kernel_install_files_loc, $kernel_version, $usm_version) = @_;
  my ($component);
  my ($src);
  my ($retval);

  # $kernel_install_files_loc is where the drivers and drivers related files
  # live. - the commands are shipped in a separate directory.
  #
  if (-d $kernel_install_files_loc == 0)
  {
    return USM_FAIL;
  }

  # Look to see if an alternate location for the distribution was specified.
  if ($kernel_install_files_loc ne $AFD_DFLT_DRV_LOC)
  {
    # -l option specified (we know that the path is fully qualified).
    $minus_l_specified = 1;

    # $kernel_install_files_loc is a misnomer for -l within this 'if clause',
    # where it's really the the directory path up to and including "install" -
    # but, what the heck. Once out of this clause, it really will mean the
    # location of the kernel drivers.

    # We use "install" as our starting point for finding our bits
    # so it had better be there.
    if (!($kernel_install_files_loc =~ /install$/))
    {
      # Error message generated by caller
      return USM_TRANSIENT_FAIL;
    }

    # We have the "base" path, up to "install".
    # It's time to find where the drivers are relative to that base.

    my (@path_array) = split (/\\/, $AFD_DFLT_DRV_LOC);
    my ($last_element) = $#path_array;
    my ($driver_relative_path) = "";
    my ($i);
 
    for ($i = 1; $i <= $last_element; $i++)
    {
      # strip off all array elements of out default "base" location. What's 
      # left will be the parts of the driver relative path.
      my ($element) = shift(@path_array);
      if ($element eq "install")
      {
        last;
      }
    }
  
    # Now assemble the driver relative path.
    $last_element = $#path_array;
    for ($i = 0; $i <= $last_element; $i++)
    {
      $driver_relative_path .= "$path_array[$i]\\";
    }

    # We now know where the drivers and commands live in the '-l' location.
    $CMDS_SRC_DIR = "$kernel_install_files_loc\\cmds\\bin";
    $MESG_SRC_DIR = "$kernel_install_files_loc\\..\\mesg";
    $USM_LIB_SRC_DIR = "$kernel_install_files_loc\\..\\lib";
    $USM_BIN_SRC_DIR = "$kernel_install_files_loc\\..\\bin";
    $kernel_install_files_loc .= "\\$driver_relative_path";
    $MINUS_L_DRIVER_LOC = "$kernel_install_files_loc";
  }

  # convert any '/' to '\'
  $kernel_install_files_loc =~ s/\//\\/g;

  # We need to uncompress driver files first
  lib_uncompress_all_driver_files($kernel_install_files_loc);

  # test that all of our expected components exist in the distribution
  foreach $component (@DRIVER_COMPONENTS)
  {
    my ($target) = "$kernel_install_files_loc\\$component";
    if (-e $target == 0)
    {
      lib_error_print(9341, "executable '%s' not found", $target);
      $retval = USM_FAIL;
    }
  }

  foreach $component (@CMD_COMPONENTS, @MESG_COMPONENTS)
  {
    if ($minus_l_specified)
    {
      my (@array)   = split /\\/, $component;
      my ($file)    = $array[-1];
      my ($subdir)  = $array[-2];

      if ($subdir eq "mesg")
      {
        $src  = "$MESG_SRC_DIR\\$file";
      }
      elsif ($file =~ ".dll\$")
      {
         $src  = "$USM_BIN_SRC_DIR\\$file";
      }
      elsif ($file =~ ".lib\$")
      {
         $src  = "$USM_LIB_SRC_DIR\\$file";
      }
      elsif ($subdir eq "bin")
      {
        $src  = "$CMDS_SRC_DIR\\$file";
      }
    }
    else
    {
      $src = $component;
    }

    if (! -e $src)
    {
      lib_error_print(9341, "executable '%s' not found", $src);
      $retval = USM_FAIL;
    }
  }


  if ($retval == USM_FAIL)
  {
    return USM_FAIL;
  }

  $MEDIA_PATH = $kernel_install_files_loc;
  $MEDIA_FOUND = "$MEDIA_PATH\n";

  return USM_SUCCESS;
} # end osds_afd_search_for_distribution_files

# osds_load_and_verify_afd_state
#
# If the install was for the current kernel version, we load the drivers
# and test to see that the expected /dev entries get created.
#
sub osds_load_and_verify_afd_state
{
  my ($no_load) = @_;

  # Make sure that all components are in place
  my ($fail) = 0;
  my ($component);
  my ($return_val);

  # verify that the drivers reside in the target directory
  foreach $component (@DRIVER_COMPONENTS)
  {
    my ($driver_path) = "$DRIVER_DIR\\$component";

    if (! -e $driver_path)
    {
      $fail = 1;
      lib_error_print(9330, "executable '%s' not installed", $driver_path);
    }
  }

  # verify that the commands reside in the target directory
  foreach $component (@CMD_COMPONENTS)
  {
    my ($command_path) = $component;
    
    if (! -e $command_path)
    {
      $fail = 1;
      lib_error_print(9330, "executable '%s' not installed", $command_path);
    }
  }
 
  if ($fail)
  {
    return USM_FAIL;
  } 

  osds_afd_fix_wrapper_scripts();

  if ($no_load)
  {
    # We're installing USM for another kernel version - do not attempt to
    # load the drivers. The presumed scenario is that the user wants to
    # install USM for an about to be upgraded kernel. This way, USM can
    # be up and running upon reboot. Dunno if anyone will ever use this.
    return USM_SUCCESS;
  }

  # Copy libafd[version].so to the required location. 
  lib_osds_afd_copy_library(); 

  # make sure all drivers are loaded (running in windows speak)
  # Post driver load, create /dev/oracleafd/disks
  $return_val = lib_afd_post_load_setup();
  if ($return_val != USM_SUCCESS)
  {
    # lib_afd_post_load_setup() will print the specific error, if any;
    return $return_val;
  }

  #
  # afd.conf is generated from HAS ROOT SCRIPTS
  # Please osd_setup() in crsutils.pm
  #

  return USM_SUCCESS;
} # end osds_load_and_verify_afd_state

use File::Path qw(rmtree);
# osds_afd_uninstall
#
sub osds_afd_uninstall
{
  my (undef, $preserve) = @_;
  my ($return_code) = USM_SUCCESS;        # Assume success
  my ($ret_val);                          # return value from system()
  my ($component);
  my ($command);                          # Command being executed by system()
  my ($afdinstall);                      # path to afdinstall.exe
  my ($target);
  my $SYSDRIVE = $ENV{SYSTEMDRIVE};

  #if (!$preserve)
  #{
    # Names MUST match the ASM_OSD_TUNABLE_FILE_NAME define in asmdefs.h
    # and OFS_OSD_TUNABLE_FILE_NAME in ofsXXXtunables.h
    #
    # Note that win/if/asmdefs.h has "C:WINDOWS" hard coded. This is a bad idea.
    #my ($afd_tunables_dir) = "C:\\WINDOWS\\system32\\drivers\\afd";
    # my ($afd_tunables) = $afd_tunables_dir . "\\tunables";

    # I'd like to use the more modern remove_tree() but it's not exported by
    # our File::Path. So we use the legacy (but supported) rmtree().

   # if (-d $afd_tunables_dir)
   # {
   #   rmtree $afd_tunables_dir;
   #   if (-d $afd_tunables_dir)
   #   {
   #     lib_inform_print(9348, "Unable to remove '%s'.", $afd_tunables_dir);
   #   }
   # }
  #} 

  # uninstall the drivers
  # the driver files are deleted by afdinstall.exe

  $afdinstall = "$OH_BIN_DIR\\afdinstall.exe"; 

  # we SHOULD have an installed afdinstall.exe. But, just in case,
  # look in the default media distribution location if not. 
  if (! -e $afdinstall)
  {
    $afdinstall = "$AFD_DFLT_DRV_LOC\\afdinstall.exe";
  }
  if (! -e $afdinstall)
  {
     lib_error_print(9341, "executable %s not found", $afdinstall);
     exit(1);
  }

  # uninstall AFD
  $ret_val = run_afdinstall($afdinstall, "/u");
  if ($ret_val != USM_SUCCESS)
  {
    my ($driver) = "AFD";
    lib_error_print(9329, "failed to uninstall driver '%s'", $driver);
    $return_code = $ret_val;
  }

  # Delete /dev/oracleafd/disks
  lib_osds_afd_delete_oracleafd_disks();

  # Remove "oraafd*.dll" from %SYSTEMDRIVE%\\oracle\\extapi\\64\\asm
  $target = "$SYSDRIVE\\oracle\\extapi\\64\\asm";
  my $file;  # place holder for the file to be removed
  opendir(DIR, $target);
  my @files = grep { /^($LIBAFD_BASENAME)\w*\.dll$/i } readdir(DIR);
  closedir(DIR);
    
  foreach $file(@files) 
  {
    unlink($file);
  }

  # remove components if afdinstall (above) worked for all drivers
  #if ($ret_val != USM_SUCCESS)
  #{
  #  # remove commands
  #  foreach $component (@CMD_COMPONENTS)
  #  {
  #    my ($file) = "$ORACLE_HOME\\$component";
  #    unlink($file); 
  #  }

  #  # remove drivers
  #  foreach $component (@DRIVER_COMPONENTS)
  #  {
  #    my ($file) = "$DRIVER_DIR\\$component";
  #    unlink($file); 
  #  }
  #}

  return $return_code;
} # end osds_afd_uninstall

###############################
# internal #static" functions #
###############################

# osds_afd_fix_wrapper_scripts
#
# We need to resolve ORA_CRS_HOME in the command wrapper scripts.
#
sub osds_afd_fix_wrapper_scripts
{
  my ($prog); 
  my ($line);
  my (@buffer);
  my ($read_index, $write_index);
  my (@progs) = (
                "$ORACLE_HOME\\bin\\afddriverstate.bat",
                "$ORACLE_HOME\\bin\\afdload.bat",
                );

  foreach $prog (@progs)
  {
    $read_index = 0;
    open READ, "<$prog" or next;
    while ($line = <READ>)
    {
      if ($line =~ m/^set CRS_HOME=/)
      {
         $line = "set CRS_HOME=$ORACLE_HOME\n";
      }
      $buffer[$read_index++] = $line;
    }
    close (READ);
    
    $write_index = 0;
    open WRITE, ">$prog";
    while($write_index < $read_index)
    {
      print WRITE "$buffer[$write_index++]";
    }
    close (WRITE);
  }
}
# end osds_afd_fix_wrapper_scripts

# run_afdinstall
#
sub run_afdinstall
{
  my ($command_loc, $i_or_u, $driver_loc) = @_; 
  my ($line);
  my ($retval);

  if ($i_or_u eq "/i")
  {
   # quotes around $driver_loc in case the directory contains spaces.
   $driver_loc =~ s/\s+$//;
   $line = `$command_loc /i $driver_loc`;
  }
  else           # "/u"
  {
    $line = `$command_loc /u 2>&1`;
  }

  # The return value is the exit status of the program as returned 
  # by the wait call. To get the actual exit value, shift right by eight. 
  # Check http://perldoc.perl.org/functions/system.html
  $retval = $? >> 8;

  if ($retval == USM_REBOOT_RECOMMENDED) #Status 3 is sending when we need to reboot
  {
    return USM_REBOOT_RECOMMENDED;	
  } 
  elsif ($retval != 0) 
  {
    # print whatever (already NLSed) output that afdinstall.exe
    # may have generated
    lib_error_print(9999, $line);
    return USM_FAIL;
  }
  else
  {
    return USM_SUCCESS;
  }
}

1;
