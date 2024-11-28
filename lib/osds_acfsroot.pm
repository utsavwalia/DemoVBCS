#
#
# osds_acfsroot.pm
# 
# Copyright (c) 2007, 2021, Oracle and/or its affiliates. 
#
#
#    NAME
#      osds_acfsroot.pm - Windows OSD component of acfsroot.
#
#    DESCRIPTION
#      Purpose
#          Install/uninstall USM commands and drivers.
#
#    NOTES
#      All user visible output should be done in the common code when possible.
#      This will ensure a consistent look and feel across all platforms.
#      It is understood that due to the OSD nature of the file, some output
#      needs to be done here.
#
#

use strict;
use Win32;
use File::Spec::Functions;
require Win32API::File;
require Exporter;
package osds_acfsroot;

our @ISA = qw(Exporter);
our @EXPORT = qw(
                 osds_fix_wrapper_scripts
                 osds_get_kernel_version
                 osds_initialize
                 osds_install_from_distribution_files
                 osds_search_for_distribution_files
                 osds_load_and_verify_usm_state
                 osds_usm_uninstall
                 osds_patch_verify
                 osds_configure_acfs_remote
                 $MEDIA_FOUND
                 $ORACLE_HOME
                 $USM_DFLT_DRV_LOC
                 $USM_DFLT_CMD_LOC
                 $USM_TUNE_OS_DIR
                 $USM_TUNE_ORA_DIR
                 osds_acfsr_transport_config
                 osds_acfsr_transport_list
                 @OH_BIN_COMPONENTS 
                 @OH_LIB_COMPONENTS
                 @SBIN_COMPONENTS
                 @USM_PUB_COMPONENTS                                           
                 @MESG_COMPONENTS 
                );

use osds_acfslib;
use acfslib;
use usmvsn;

our ($ORACLE_HOME) = $ENV{ORACLE_HOME};

# If ORACLE_HOME points to the db home (no usm/install dir), point it to the
# CRS_HOME. Both ORACLE_HOME and ORA_CRS_HOME are set in the wrapper scripts for
# the individual commands.
$ORACLE_HOME = $ENV{ORA_CRS_HOME} if (!(-e "$ORACLE_HOME\\usm\\install"));

my  ($SYSTEM_ROOT) = $ENV{SYSTEMROOT};
my  ($MINUS_L_DRIVER_LOC);

use constant AVD_DRIVER => "oracleadvm.sys";
use constant OFS_DRIVER => "oracleacfs.sys";
use constant OKS_DRIVER => "oracleoks.sys";

# installation source locations
my ($SHIPHOME_BASE_DIR) = "$ORACLE_HOME\\usm\\install";
my ($CMDS_SRC_DIR)      = "$SHIPHOME_BASE_DIR\\cmds\\bin";
my ($MESG_SRC_DIR)      = "$SHIPHOME_BASE_DIR\\..\\mesg";
my ($USM_PUB_SRC_DIR)   = "$SHIPHOME_BASE_DIR\\..\\public";

our ($USM_DFLT_CMD_LOC) = "$ORACLE_HOME\\bin"; # exported loc of install cmds

# installed component locations
my ($DRIVER_DIR)      = "$SYSTEM_ROOT\\system32\\drivers";  # driver location
my ($OH_BIN_DIR)      = "$ORACLE_HOME\\bin";
my ($OH_LIB_DIR)      = "$ORACLE_HOME\\lib";
my ($MESG_DST_DIR)    = "$ORACLE_HOME\\usm\\mesg";
my ($USM_PUB_DST_DIR) = "$ORACLE_HOME\\usm\\public";

our ($USM_TUNE_OS_DIR)  = $DRIVER_DIR;
our ($USM_TUNE_ORA_DIR) = "$ORACLE_HOME\\acfs\\tunables";

# Used by '-l' only.
my ($USM_LIB_SRC_DIR);
my ($USM_BIN_SRC_DIR);

# ACFS library name.
my ($LIBACFS)          = "oraacfs".usmvsn::vsn_getmaj().".dll";

our ($MEDIA_FOUND) = '';                      # path name to media

my (@DRIVER_COMPONENTS) = (
    "oracleadvm.sys",      "oracleoks.sys",        "oracleacfs.sys",
    );

# Bug 21518337 
# tsc tkfvinfolink12 in which we extract the content of these elements. 
# added @SBIN_COMPONENTS as an empty array due Unix-like platforms
our @SBIN_COMPONENTS = ""; 

our (@OH_BIN_COMPONENTS) = (
    "$OH_BIN_DIR\\acfschkdsk.exe",        "$OH_BIN_DIR\\acfsrepl_preapply.exe",
    "$OH_BIN_DIR\\acfsdbg.exe",           "$OH_BIN_DIR\\acfsrepl_transport.exe",
    "$OH_BIN_DIR\\acfsdismount.exe",      "$OH_BIN_DIR\\acfsreplcrs.bat",
    "$OH_BIN_DIR\\acfsdriverstate.bat",   "$OH_BIN_DIR\\acfsroot.bat",
    "$OH_BIN_DIR\\acfsformat.exe",        "$OH_BIN_DIR\\acfsinstall.exe",
    "$OH_BIN_DIR\\acfssinglefsmount.bat", "$OH_BIN_DIR\\acfsload.bat",
    "$OH_BIN_DIR\\acfsutil.exe",          "$OH_BIN_DIR\\acfsmountvol.exe",
    "$OH_BIN_DIR\\advmutil.exe",          "$OH_BIN_DIR\\acfsregistrymount.bat",
    "$OH_BIN_DIR\\acfsrepl_apply.exe",    "$OH_BIN_DIR\\acfsrepl_initializer.exe",
    "$OH_BIN_DIR\\acfsrepl_monitor.exe",  "$OH_BIN_DIR\\$LIBACFS",
    "$OH_BIN_DIR\\acfsrepl_dupd.exe",
    );

our (@OH_LIB_COMPONENTS) = (
    "$OH_LIB_DIR\\acfsdriverstate.pl",   "$OH_LIB_DIR\\acfsroot.pl",
    "$OH_LIB_DIR\\acfsreplcrs.pl",       "$OH_LIB_DIR\\acfslib.pm",
    "$OH_LIB_DIR\\acfssinglefsmount.pl", "$OH_LIB_DIR\\acfsload.pl",
    "$OH_LIB_DIR\\acfstoolsdriver.bat",  "$OH_LIB_DIR\\osds_acfsdriverstate.pm",
    "$OH_LIB_DIR\\acfsregistrymount.pl", "$OH_LIB_DIR\\osds_acfslib.pm",
    "$OH_LIB_DIR\\osds_acfsroot.pm",     "$OH_LIB_DIR\\osds_acfssinglefsmount.pm",
    "$OH_LIB_DIR\\osds_acfsregistrymount.pm",
    "$OH_LIB_DIR\\osds_acfsload.pm",     "$OH_LIB_DIR\\oraacfs19.lib",
    "$OH_LIB_DIR\\usmvsn.pm",
    );

my (@CMD_COMPONENTS) = (@OH_BIN_COMPONENTS, @OH_LIB_COMPONENTS);

our (@MESG_COMPONENTS) = (
    "$MESG_DST_DIR\\acfsus.msb",
    "$MESG_DST_DIR\\acfsus.msg",
    );

our (@USM_PUB_COMPONENTS) = (
    "$USM_PUB_DST_DIR\\acfslib.h",
    );

my ($minus_l_specified) = 0;   # Alternate install location specified by user.

# set by osds_search_for_distribution_files() and
# consumed by osds_install_from_distribution_files() 
my ($MEDIA_PATH);

our ($USM_DFLT_DRV_LOC);

# Perl stat
use constant MODE => 2;

# osds_initialize
#
# Perform OSD required initialization if any
#
sub osds_initialize
{
  my ($install_kver, $sub_command, $install_location, $option_l_used) = @_;
  my @win_paths = ("2012", "2012R2", "2016", "2019" ,"");
  my $subdir;
  my $i;
  my $ospath;

  # lib_osds_usm_supported() has already determined and verified that the
  # machine architecture ($ARCH) and OS type are supported
  # and are valid.

  if (!((defined($ORACLE_HOME)) && (-e "$ORACLE_HOME/lib/acfsroot.pl")))
  {
    lib_error_print(9389,
    "ORACLE_HOME is not set to the location of the Grid Infrastructure home.");
    return USM_TRANSIENT_FAIL;
  }
 
  if (defined($install_location))
  {
    #Alternative location
    $USM_DFLT_DRV_LOC  = $install_location;
    $USM_DFLT_DRV_LOC .= "\\Windows\\$OS_SUBDIR\\$ARCH\\bin";
  }
  else
  {
    #Default location
    $USM_DFLT_DRV_LOC  = $SHIPHOME_BASE_DIR;
    $USM_DFLT_DRV_LOC .= "\\Windows\\$OS_SUBDIR\\$ARCH\\bin";
  }

  if (!$USM_DFLT_DRV_LOC ||
      !(-d $USM_DFLT_DRV_LOC))
  {
    lib_error_print( 9544, "Invalid files or directories found: '%s'",
                     $USM_DFLT_DRV_LOC);
    return USM_FAIL;
  }

  if( !$option_l_used && ($sub_command eq "install"))
  {
    # Validate install directories
    $ospath = $USM_DFLT_DRV_LOC . "/../../../";
    $i = 0;
    opendir DIR, $ospath or die "cannot open dir $ospath: $!";
    my @mcfiles = readdir(DIR);
    closedir(DIR);

    $i = 0;
    foreach $subdir ( @mcfiles)
    {
      chomp( $subdir);
      if( $subdir eq "." || $subdir eq ".." || $subdir eq ".ade_path" )
      {
        next;
      }

      if( $subdir ne $win_paths[$i] || $win_paths[$i] eq "")
      {
        lib_error_print( 9544,
        "Invalid files or directories found: '%s'",
        $subdir);
        return USM_FAIL;
      }
      $i++;
    }
  }

  return USM_SUCCESS;
}

# osds_get_kernel_version
#
sub osds_get_kernel_version
{
  return $OS_TYPE;
} # end osds_get_kernel_version

use File::Copy;

# osds_install_from_distribution_files
#
# Install the USM components from the specified distribution files
# The media has already been validated by the time we get here
# by osds_search_for_distribution_files(). Also, any previous USM installation
# will have been removed.
#
sub osds_install_from_distribution_files
{
  my ($component);                 # curent component being installed
  my ($driver_path);               # full path name of the driver source
  my ($acfsinstall);               # full path name of acfsinstall.exe
  my ($ret_val);                   # return code from system()
  my ($return_code) = USM_SUCCESS;

  # The commands have been verified to exist. 
  # No work is needed here.

  $acfsinstall = "$OH_BIN_DIR\\acfsinstall.exe";

  # install the drivers
  $driver_path = $MEDIA_PATH;

  lib_verbose_print (9503, "ADVM and ACFS driver media location is '%s'", 
                        $MEDIA_PATH);
  
  # install the OKS driver
  $ret_val = run_acfsinstall(
                      $acfsinstall, "/i", "/l", "$driver_path\\" . OKS_DRIVER);
  if ($ret_val == USM_FAIL)
  {
    my ($driver) = "OKS";
    lib_error_print(9340, "failed to install %s driver.", $driver);
    $return_code = $ret_val;
  }
  elsif ($ret_val == USM_REBOOT_RECOMMENDED)
  {
    # If we are sending USM_REBOOT_RECOMMMENDED, we don't need to continue
    # installing.
    return $ret_val;
  }

  # install the AVD driver
  $ret_val = run_acfsinstall(
                      $acfsinstall, "/i", "/a", "$driver_path\\" . AVD_DRIVER);
  if ($ret_val == USM_FAIL)
  {
    my ($driver) = "ADVM";
    lib_error_print(9340, "failed to install %s driver.", $driver);
    $return_code = $ret_val;
  }
  elsif ($ret_val == USM_REBOOT_RECOMMENDED)
  {
    # If we are sending USM_REBOOT_RECOMMMENDED, we don't need to continue
    # installing.
    return $ret_val;
  }

  # install the ACFS driver
  $ret_val = run_acfsinstall(
                      $acfsinstall, "/i", "/o", "$driver_path\\" . OFS_DRIVER);
  if ($ret_val == USM_FAIL)
  {
    my ($driver) = "ACFS";
    lib_error_print(9340, "failed to install %s driver.", $driver);
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
    $ret_val = 1;
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
      acfslib::lib_chmod("0755", $target);

      $source = File::Spec->rel2abs( $source);
      $target = File::Spec->rel2abs( $target);
      if( $target ne $source)
      {
          $ret_val = copy ($source, $target);
          if ($ret_val == 0)
          {
            #Error code format is "errno - message errno"
            #Sample: 2 - No such file or directory
            my $error_code = sprintf("%d - %s", $!, $!);
            lib_error_print(9346, "Unable to install file: '%s'.", $target);
            lib_error_print(9178, "Return code = %s", $error_code);
            $return_code = USM_FAIL;
          }
          acfslib::lib_chmod($orig_mode, $target);
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
      acfslib::lib_chmod("0755", $target);

      $source = File::Spec->rel2abs($source);
      $target = File::Spec->rel2abs($target);
      if( $target ne $source)
      {
          $ret_val = copy ($source, $target);
          if ($ret_val == 0)
          {
            #Error code format is "errno - message errno"
            #Sample: 2 - No such file or directory
            my $error_code = sprintf("%d - %s", $!, $!);
            lib_error_print(9346, "Unable to install file: '%s'.", $target);
            lib_error_print(9178, "Return code = %s", $error_code);
            $return_code = USM_FAIL;
          }
          acfslib::lib_chmod($orig_mode, $target);
      }
    }

    foreach $component (@USM_PUB_COMPONENTS)
    {
      my (@array) = split /\\/, $component;
      my ($file) = $array[-1];
      my ($target) = $component;
      my ($source) = "$USM_PUB_SRC_DIR\\$file";
      
      lib_verbose_print (9504, "Copying file '%s' to the path '%s'", 
                         $source,
                         $target);
      
      $orig_mode = (stat($target))[MODE] & 0777;
      acfslib::lib_chmod("0755", $target);

      $source = File::Spec->rel2abs( $source);
      $target = File::Spec->rel2abs( $target);
      if( $target ne $source)
      {
          $ret_val = copy ($source, $target);
          if ($ret_val == 0)
          {
            #Error code format is "errno - message errno"
            #Sample: 2 - No such file or directory
            my $error_code = sprintf("%d - %s", $!, $!);
            lib_error_print(9346, "Unable to install file: '%s'.", $target);
            lib_error_print(9178, "Return code = %s", $error_code);
            $return_code = USM_FAIL;
          }
          acfslib::lib_chmod($orig_mode, $target);
      }
    }
    #If we are using '-l' location, maybe the default location doesn't exist
    if (! -d $USM_DFLT_DRV_LOC)
    {
      File::Path::make_path( $USM_DFLT_DRV_LOC, {mode => 0644} );
    }

    # Copy the drivers to the install area so that
    # subsequent "acfsroot install"s will get the patched bits should
    # the user forget to use the -l option. It also allows us to compare
    # checksums on the drivers in the "install" area to the "installed"
    # area at load time. This will catch situations where users installed
    # new bits but did run "acfsroot install".
    foreach $component (@DRIVER_COMPONENTS)
    {
      my (@array) = split /\\/, $component;
      my ($file) = $array[-1];
      my ($target) = "$USM_DFLT_DRV_LOC/$component";
      my ($source) = "$MINUS_L_DRIVER_LOC\\$file";
      
      lib_verbose_print (9504, "Copying file '%s' to the path '%s'", 
                         $source,
                         $target);
      
      $orig_mode = (stat($target))[MODE] & 0777;
      acfslib::lib_chmod("0755" , $target);
      $source = File::Spec->rel2abs( $source);
      $target = File::Spec->rel2abs( $target);
      if( $target ne $source)
      {
          $ret_val = copy ($source, $target);
          if ($ret_val == 0)
          {
            #Error code format is "errno - message errno"
            #Sample: 2 - No such file or directory
            my $error_code = sprintf("%d - %s", $!, $!);
            lib_error_print(9346, "Unable to install file: '%s'.", $target);
            lib_error_print(9178, "Return code = %s", $error_code);
            $return_code = USM_FAIL;
          }
          acfslib::lib_chmod($orig_mode, $target);
      }
    }
  }

  # Copy ACFS library to the vendor specific location
  $ret_val = osds_install_acfslib();
  if($ret_val != USM_SUCCESS)
  {
    $return_code = USM_FAIL;
  }

  return $return_code;
} # end osds_install_from_distribution_files

# osds_search_for_distribution_files
#
# Search the location(s) specified by the user for valid media
# If a specific kernel and/or USM version is specified,
# look for that only that version.
#
sub osds_search_for_distribution_files

{
  my ($kernel_install_files_loc) = shift;
  # -l option specified (we know that the path is fully qualified).
  $minus_l_specified = shift;
  my ($component);
  my ($src);
  my ($retval);

  # $kernel_install_files_loc is where the drivers and drivers related files
  # live. - as of 11.2.0.3 and later, the commands are shipped in a separate
  # directory.

  if (-d $kernel_install_files_loc == 0)
  {
    return USM_FAIL;
  }

  # Look to see if an alternate location for the distribution was specified.
  if ($minus_l_specified)
  {
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
    # There are two possible strings to split:
    #      C:\ADE\madoming_rejected\oracle\usm\install\Windows\2012R2\x86_64\bin
    # or
    #      C:/shiphome/USMPATCH/usm/install\Windows\2012R2\x86_64\bin 
    my (@path_array) = split (/\\/, $USM_DFLT_DRV_LOC);
    my ($last_element) = $#path_array;
    my ($driver_relative_path) = "";
    my ($i);
 
    for ($i = 1; $i <= $last_element; $i++)
    {
      # strip off all array elements of out default "base" location. What's 
      # left will be the parts of the driver relative path.
      my ($element) = shift(@path_array);
      # Splitting with \, but we need to check elements containing "install"
      if (($element =~ /install/) &&
         !(grep{$_ =~ /install/} @path_array))
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
    $USM_PUB_SRC_DIR = "$kernel_install_files_loc\\..\\public";
    $USM_LIB_SRC_DIR = "$kernel_install_files_loc\\..\\lib";
    $USM_BIN_SRC_DIR = "$kernel_install_files_loc\\..\\bin";
    $kernel_install_files_loc .= "\\$driver_relative_path";
    $MINUS_L_DRIVER_LOC = "$kernel_install_files_loc";
    #We need to update USM_DFLT_DRV_LOC, now is pointing to '-l' location.
    $USM_DFLT_DRV_LOC = "$SHIPHOME_BASE_DIR\\$driver_relative_path";
  }

  # convert any '/' to '\'
  $kernel_install_files_loc =~ s/\//\\/g;

  # We need to uncompress driver files first
  lib_uncompress_all_driver_files($kernel_install_files_loc);


  my $os_detected = "";
  if ($OS_SUBDIR eq "2019")
  {
    $os_detected = "WIN10";
  }
  elsif ($OS_SUBDIR eq "2016")
  {
    $os_detected = "WIN10";
  }
  elsif( $OS_SUBDIR eq "2012R2" )
  {
    $os_detected = "WIN8.1";
  }
  elsif( $OS_SUBDIR eq "2012" )
  {
    $os_detected = "WIN8";
  }

  # test that all of our expected components exist in the distribution
  foreach $component (@DRIVER_COMPONENTS)
  {
    my ($target) = "$kernel_install_files_loc\\$component";
    my $os_name = "";
    my $os_version = "";
    my @os_tokens = ();
	my $str;

    if (-e $target == 0)
    {
      lib_error_print(9341, "Binary '%s' not found.", $target);
      $retval = USM_FAIL;
      next;
    }
	
    open (FIND, "findstr /C:\"KERNEL MODULE OS:\" $target |");
    $str = <FIND>;
    close(FIND);

    if ($str =~ /KERNEL MODULE OS: (\S+)/)
    {
      @os_tokens = split( /:/, $str);
      $os_name = @os_tokens[1];
      chomp( $os_name);
      $os_name =~ s/^\s+|\s+$//g;	  
    }
	
    open (FIND, "findstr /C:\"KERNEL MODULE OS VERSION:\" $target |");
    $str = <FIND>;
    close(FIND);
    if ($str =~ /KERNEL MODULE OS VERSION: (\S+)/)
    {
      @os_tokens = split( /:/, $str);
      $os_version = @os_tokens[1];
      chomp( $os_version);
      $os_version =~ s/^\s+|\s+$//g;
    }

    if( $os_name ne "Windows_NT" || $os_version ne $os_detected)
    {
       lib_error_print( 9545,
            "Verification error: kernel module '%(1)s' is incompatible with " .
            "the installed kernel version '%(3)s'. It is compatible with " .
            "kernel version '%(2)s'.",
       $component, "Windows " . $os_version, "Windows " . $os_detected);
       $retval = USM_FAIL;
    }
  }
  
  foreach $component (@CMD_COMPONENTS, @MESG_COMPONENTS, @USM_PUB_COMPONENTS)
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
      lib_error_print(9341, "Binary '%s' not found.", $src);
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
} # end osds_search_for_distribution_files

# osds_load_and_verify_usm_state
#
# If the install was for the current kerlel version, we load the drivers
# and test to see that the expected /dev entries get created.
#
sub osds_load_and_verify_usm_state
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
      lib_error_print(9330, "Binary '%s' not installed.", $driver_path);
    }
  }

  # verify that the commands reside in the target directory
  foreach $component (@CMD_COMPONENTS)
  {
    my ($command_path) = $component;
    
    if (! -e $command_path)
    {
      $fail = 1;
      lib_error_print(9330, "Binary '%s' not installed.", $command_path);
    }
  }
 
  if ($fail)
  {
    return USM_FAIL;
  } 

  lib_trace( 9999, "Resolve ORA_CRS_HOME in the command wrapper scripts.");
  osds_fix_wrapper_scripts();

  if ($no_load)
  {
    # We're installing USM for another kernel version - do not attempt to
    # load the drivers. The presumed scenario is that the user wants to
    # install USM for an about to be upgraded kernel. This way, USM can
    # be up and running upon reboot. Dunno if anyone will ever use this.
    return USM_SUCCESS;
  }

  # make sure all drivers are loaded (running in windows speak)
  lib_inform_print(9327, "Verifying ADVM/ACFS devices.");
  $return_val = lib_osds_verify_usm_devices();
  if ($return_val != USM_SUCCESS)
  {
    # osds_verify_usm_devices() will print the specific error(s), if any;
    return $return_val;
  }

  # # should we unload the drivers at this point?
  # osds_unload_drivers();

  return USM_SUCCESS;
} # end osds_load_and_verify_usm_state

use File::Path qw(rmtree);
# osds_usm_uninstall
#
sub osds_usm_uninstall
{
  my (undef, $preserve) = @_;
  my ($return_code) = USM_SUCCESS;        # Assume success
  my ($ret_val);                          # return value from system()
  my ($component);
  my ($command);                          # Command being executed by system()
  my ($acfsinstall);                      # path to acfsinstall.exe

  if (!$preserve)
  {
    # Names MUST match the ASM_OSD_TUNABLE_FILE_NAME define in asmdefs.h
    # and OFS_OSD_TUNABLE_FILE_NAME in ofsXXXtunables.h
    #
    # Note that win/if/asmdefs.h has "C:WINDOWS" hard coded. This is a bad idea.
    my ($advm_tunables_dir) = "C:\\WINDOWS\\system32\\drivers\\advm";
    my ($acfs_tunables_dir) = "C:\\WINDOWS\\system32\\drivers\\acfs";
    my ($advm_tunables) = $advm_tunables_dir . "\\tunables";
    my ($acfs_tunables) = $acfs_tunables_dir . "\\tunables";

    # I'd like to use the more modern remove_tree() but it's not exported by
    # our File::Path. So we use the legacy (but supported) rmtree().

    if (-d $advm_tunables_dir)
    {
      rmtree $advm_tunables_dir;
      if (-d $advm_tunables_dir)
      {
        lib_inform_print(9348, "Unable to remove '%s'.", $advm_tunables_dir);
      }
    }
    if (-d $acfs_tunables_dir)
    {
      rmtree $acfs_tunables_dir;
      if (-d $acfs_tunables_dir)
      {
        lib_inform_print(9348, "Unable to remove '%s'.", $acfs_tunables_dir);
      }
    }
  } 

  # uninstall the drivers
  # the driver files are deleted by acfsinstall.exe

  $acfsinstall = "$OH_BIN_DIR\\acfsinstall.exe"; 

  # we SHOULD have an installed acfsinstall.exe. But, just in case,
  # look in the default media distribution location if not. 
  if (! -e $acfsinstall)
  {
    $acfsinstall = "$USM_DFLT_DRV_LOC\\acfsinstall.exe";
  }
  if (! -e $acfsinstall)
  {
     lib_error_print(9341, "%s not found", $acfsinstall);
     exit(1);
  }

  # uninstall OFS
  $ret_val = run_acfsinstall($acfsinstall, "/u", "/o");
  if ($ret_val != USM_SUCCESS)
  {
    my ($driver) = "ACFS";
    lib_error_print(9329, "Failed to uninstall driver: '%s'.", $driver);
    $return_code = $ret_val;
  }

  # uninstall ADVM 
  $ret_val = run_acfsinstall($acfsinstall, "/u", "/a");
  if ($ret_val != USM_SUCCESS)
  {
    my ($driver) = "ADVM";
    lib_error_print(9329, "Failed to uninstall driver: '%s'.", $driver);
    $return_code = $ret_val;
  }

  # uninstall OKS
  $ret_val = run_acfsinstall($acfsinstall, "/u", "/l");
  if ($ret_val != USM_SUCCESS)
  {
    my ($driver) = "OKS";
    lib_error_print(9329, "Failed to uninstall driver: '%s'.", $driver);
    $return_code = $ret_val;
  }

  # remove components if acfsinstall (above) worked for all drivers
  if ($ret_val != USM_SUCCESS)
  {
    # remove commands
    foreach $component (@CMD_COMPONENTS)
    {
      my ($file) = "$ORACLE_HOME\\$component";
      unlink($file); 
    }

    # remove drivers
    foreach $component (@DRIVER_COMPONENTS)
    {
      my ($file) = "$DRIVER_DIR\\$component";
      unlink($file); 
    }
  }

  # Remove ACFS library from the vendor specific location
  $ret_val = osds_uninstall_acfslib();
  if($ret_val != USM_SUCCESS)
  {
    $return_code = USM_TRANSIENT_FAIL;
  }

  return $return_code;
} # end osds_usm_uninstall

###############################
# internal #static" functions #
###############################

# osds_fix_wrapper_scripts
#
# We need to resolve ORA_CRS_HOME in the command wrapper scripts.
#
sub osds_fix_wrapper_scripts
{
  lib_trace( 9176, "Entering '%s'", "fix wrp scripts");
  my ($prog); 
  my ($line);
  my (@buffer);
  my ($read_index, $write_index);
  my (@progs) = (
                "$ORACLE_HOME\\bin\\acfsdriverstate.bat",
                "$ORACLE_HOME\\bin\\acfsload.bat",
                "$ORACLE_HOME\\bin\\acfsregistrymount.bat",
                "$ORACLE_HOME\\bin\\acfssinglefsmount.bat",
                "$ORACLE_HOME\\bin\\acfsreplcrs.bat",
                "$ORACLE_HOME\\bin\\acfsroot.bat",
                );

  foreach $prog (@progs)
  {
    $read_index = 0;
    lib_trace( 9999, "Fixing $prog wrapper script.");
    if (open(READ, "<$prog"))
    {
      while ($line = <READ>)
      {
        if ($line =~ m/^set CRS_HOME=/)
        {
          chomp($line);
          lib_trace( 9999, "Old line: $line");
          $line = "set CRS_HOME=$ORACLE_HOME";
          lib_trace( 9999, "New line: $line");
          $line .= "\n";
        }
        $buffer[$read_index++] = $line;
      }
      close (READ);
    
      $write_index = 0;
      if (open WRITE, ">$prog")
      {
        while($write_index < $read_index)
        {
          print WRITE "$buffer[$write_index++]";
        }
        close (WRITE);
      }
      else
      {
        lib_trace( 9999, "Could not open file '$prog' for writing.");
      }
    }
    else
    {
      lib_trace( 9999, "Could not open file '$prog' for reading.");
    }
  }
  lib_trace( 9177, "Return from '%s'", "fix wrp scripts");
}
# end osds_fix_wrapper_scripte

# run_acfsinstall
#
sub run_acfsinstall
{
  my ($command_loc, $i_or_u, $driver, $driver_loc) = @_; 
  my ($line);
  my ($retval);

  if ($i_or_u eq "/i")
  {
   # quotes around $driver_loc in case the directory contains spaces.
   $line = `$command_loc /i $driver "$driver_loc" 2>&1`;
  }
  else           # "/u"
  {
    $line = `$command_loc /u $driver 2>&1`;
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
    # print whatever (already NLSed) output that acfsinstall.exe
    # may have generated
    lib_error_print(9999, $line);
    return USM_FAIL;
  }
  else
  {
    return USM_SUCCESS;
  }
}

sub osds_patch_verify
{
  my ($component);                 # curent component being verified
  my ($return_code) = USM_SUCCESS;
  
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

    if(md5compare($source,$target) == USM_FAIL)
    {
        lib_inform_print (9999, "$source");
		lib_inform_print (9999, "$target");
        lib_inform_print (9999,"\tFAIL");
        $return_code = USM_FAIL;
    }
    else
    {
        lib_verbose_print (9999, "$source");
        lib_verbose_print (9999, "\tPASS");
    }
  }
  
  foreach $component (@DRIVER_COMPONENTS)
  {
    my (@array) = split /\\/, $component;
    my ($file) = $array[-1];
    my ($target) = "$USM_DFLT_DRV_LOC/$component";
    my ($source) = "$MINUS_L_DRIVER_LOC\\$file";
     
    if(md5compare($source,$target) == USM_FAIL)
    {
        lib_inform_print (9999, "$source");
		lib_inform_print (9999, "$target");
        lib_inform_print (9999,"\tFAIL");
        $return_code = USM_FAIL;
    }
    else
    {
        lib_verbose_print (9999, "$source");
        lib_verbose_print (9999, "\tPASS");
    }
  }
  
  return $return_code;
}

# osds_install_acfslib
#
# Installs the ACFS shared libary into a vendor specific location.
# This allows DB homes to use ACFS functions without needing to know
# the location of the current GI home.
# Called during 'acfsroot install'.
sub osds_install_acfslib
{ 
  my ($return_code) = USM_SUCCESS;
  my ($target)      = $ENV{_vendor_lib_loc};
  my ($source);
  my ($libpath);
  my ($uid);
  my ($gid);
  my ($ret);

  if(!defined($target))
  {
    # Target should be of the type defined by rdbms
    #
    # #ifdef SS_64BIT_SERVER
    # #define SKGDLLVLL_DEFAULT "%SYSTEMDRIVE%\\oracle\\extapi\\64"
    # #else
    # #define SKGDLLVLL_DEFAULT "%SYSTEMDRIVE%\\oracle\\extapi\\32"
    # #endif
    #
    # NOTE: USM is not built for 32 bit Windows. 
    # So, ignoring 32 bit support.
    #
    $target = "$SYSTEM_DRIVE\\oracle\\extapi\\64\\acfs\\";
  }

  # oraacfs.dll goes to %SYSTEMDRIVE%\\oracle\\extapi\\...
  $source = "$ORACLE_HOME\\bin\\$LIBACFS";
  $libpath = $target.$LIBACFS; 

  # Get Owner and group of source
  ($uid, $gid) = (stat($source))[4,5];

  # create $target directory if it does not exist
  if(!(-d $target))
  {
     File::Path::make_path( $target, {mode => 0755} );
     if ($?)
     {
       lib_error_print(9345, "Unable to create directory: '%s'.", $target);
       return USM_FAIL;
     }
  }

  lib_verbose_print(9504, "Copying file '%s' to the path '%s'", 
                    $source, $target);

  # copy oraacfs.dll into $target
  unlink ("${target}\\${LIBACFS}") if (-e "${target}\\${LIBACFS}");
  File::Copy::copy($source, $target) or $return_code = USM_FAIL;

  if($return_code == USM_SUCCESS)
  {
    acfslib::lib_chmod("0755", $libpath);
    $ret = chown $uid, $gid, $libpath;
    if($ret != 1)
    {
      lib_error_print(9426,"unable to set the file attributes for file '%s'",
                      $libpath);
      return USM_FAIL;
    } 
  }

  return $return_code;
}

# osds_uninstall_acfslib
#
# Removes the ACFS library from the vendor specific location.
# Called during 'acfsroot uninstall'
sub osds_uninstall_acfslib
{
  my ($return_code) = USM_SUCCESS;
  my ($libpath);
  my ($target)      = $ENV{_vendor_lib_loc};

  if(!defined($target))
  {
    # Target should be of the type defined by rdbms
    #
    # #ifdef SS_64BIT_SERVER
    # #define SKGDLLVLL_DEFAULT "%SYSTEMDRIVE%\\oracle\\extapi\\64"
    # #else
    # #define SKGDLLVLL_DEFAULT "%SYSTEMDRIVE%\\oracle\\extapi\\32"
    # #endif
    $target = "$SYSTEM_DRIVE\\oracle\\extapi\\64\\acfs\\";
  }

  $libpath = $target.$LIBACFS;

  if(-e $libpath)
  {
    if (! unlink $libpath)
    {
      lib_inform_print(9348, "Unable to remove '%s'.", $libpath);
      $return_code = USM_FAIL;
    } 
  }

  return $return_code;
}

sub osds_configure_acfs_remote
{
    return 0;
}

sub osds_acfsr_transport_list
{
    return 0;
}

1;
