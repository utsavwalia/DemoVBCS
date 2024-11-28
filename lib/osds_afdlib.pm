#
# osds_afdlib.pm
# 
# Copyright (c) 2007, 2021, Oracle and/or its affiliates. 
#
#
#    NAME
#      osds_afdlib.pm - Windows OSD library components.
#
#    DESCRIPTION
#      Purpose
#          Windows OSD library functions for the install/runtime scripts.
#
#    NOTES
#      All user visible output should be done in the common code.
#      this will ensure a consistent look and feel across all platforms.
#
#

require Win32API::File;
use strict;
use acfslib;
use afdlib;
use usmvsn;
use Win32::OLE;
use Win32::Service;
use File::Path;
use File::Path qw/make_path/;
use File::Copy qw/copy/;
package osds_afdlib;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
                 lib_osds_am_root
                 lib_osds_check_driver_inuse
                 lib_osds_check_driver_installed
                 lib_osds_check_driver_loaded
                 lib_osds_check_loaded_drivers_mismatch
                 lib_osds_afd_control_devices_accessible
                 lib_osds_get_asm_user
                 lib_osds_get_drive_info
                 lib_osds_afd_load_driver
                 lib_osds_afd_unload_driver
                 lib_osds_afd_supported
                 lib_osds_afd_verify_devices
                 lib_osds_is_abs_path 
                 lib_osds_asmlib_installed 
                 lib_osds_afd_delete_oracleafd_disks 
                 lib_osds_afd_copy_library 
                 lib_osds_afd_post_load_setup 
                 @AFD_DRIVER_COMPONENTS
                 $ARCH
                 $OS_SUBDIR
                 $OS_TYPE
                 $REDIRECT
                 $TMPDIR
                 AFD_CTL_DEV
                 AFD_IDX                   
                 OPT_CHR
                 USM_FAIL
                 USM_SUCCESS
                 USM_SUPPORTED
                 USM_NOT_SUPPORTED
                 USM_REBOOT_RECOMMENDED
                 USM_TRANSIENT_FAIL
                 AFD_CONF_PATH
                 );

# return/exit codes
#
# USM_TRANSIENT_FAILures are those that can be easily filed by the admin.
# In the case of "afdroot install", the admin could fix the error and then
# resume a grid install, for example, from the checkpoint.
use constant USM_SUCCESS            => 0;
use constant USM_FAIL               => 1;
use constant USM_NOT_SUPPORTED      => 2;
use constant USM_REBOOT_RECOMMENDED => 3;
use constant USM_TRANSIENT_FAIL     => 1;
use constant USM_SUPPORTED          => 5;

use constant OPT_CHR => "/";            # Windows option character

use constant AFD_CTL_DEV => "\\\\.\\admin";      

use constant AFD_IDX => 0;                      # index into driver_ccomponents
# TODO: Currently we set AFD_IDX to zero to reference AFDCtl driver only, 
# as this index is mainly used in checking load/unload scenarios which is not 
# applicable for plug n play drivers like Dsk and Vol. 
# We need to revisit the logic that uses AFD_IDX later to cover vol/dsk drivers 
# as Windows is the only platform that currently has multiple AFD drivers.
our (@AFD_DRIVER_COMPONENTS) = ( 
    "Oracle AFDCtl", 
    "Oracle AFDDsk",
    "Oracle AFDVol"
    );

# Driver states
# See http://msdn.microsoft.com/en-us/library/ms685992(v=VS.85).aspx
use constant SERVICE_STOPPED          => 1;
use constant SERVICE_START_PENDING    => 2;
use constant SERVICE_STOP_PENDING     => 3;
use constant SERVICE_RUNNING          => 4;
use constant SERVICE_CONTINUE_PENDING => 5;
use constant SERVICE_PAUSE_PENDING    => 6;
use constant SERVICE_PAUSED           => 7;

# This removes output redirection on Windows.  
# For some reason, when run under the CRS environment, this causes
# scripts to fail with "cannot open file descriptor",
# or "cannot open pipe NOWAIT".
our ($REDIRECT)  = "";

our ($ARCH);
our ($OS_SUBDIR);
our ($OS_TYPE);
our ($ORACLE_HOME) = $ENV{ORACLE_HOME};
our ($TMPDIR) = "\\temp";

# AFD Library name
my ($LIBAFD)      = "oraafd".usmvsn::vsn_getmaj().".dll";

# AFD CONF PATH, Created when afd is loaded 
my ($SYSDRIVE)     = $ENV{SYSTEMDRIVE};

use constant AFD_CONF_PATH=> "$SYSDRIVE\\oracle\\oracleafd\\conf\\oracleafd.conf";

# AFD Disk dir path, Created when afd is loaded
my ($disksdir) =  "$SYSDRIVE\\oracle\\oracleafd\\disks";

# lib_osds_am_root
#   Windows Oracle always runs in admin mode
#
sub lib_osds_am_root
{
  # Windows Oracle always runs in admin mode
  return 1;
} # end lib_osds_am_root

# lib_osds_check_driver_inuse
#
#  Note: Check if Driver is still in use in Windows.
#
sub lib_osds_check_driver_inuse
{
  my ($driver) = @_;

#  /* TODO: Run afdtool.exe to unmanage all devices */

  return query("running", $driver);
} # end lib_osds_check_driver_inuse

# lib_osds_check_driver_installed()
#
sub lib_osds_check_driver_installed
{
  my ($driver) = @_;              # USM driver currently being examined
  my ($driver_found) = 0;         # as the name implies
  my ($retval) = 0;               # returned to the caller - assume no drivers

  $driver_found = query("installed", $driver);

  return $driver_found;
} # end lib_osds_check_driver_installed

# lib_osds_check_driver_loaded
#
sub lib_osds_check_driver_loaded
{
  my ($driver) = @_;

  return query("running", $driver);
} # end lib_osds_check_drivers_loaded

# lib_osds_check_loaded_drivers_mismatch
#
# Determine whether or not the installed drivers match the drivers that
# are loaded in the kernel.
# Solaris only for now.

sub lib_osds_check_loaded_drivers_mismatch
{
    return 0;
}

# lib_osds_afd_control_devices_accessible
#
# We test the AFD control device accessibility by opening them
#
# return true (1) or false (0)
#
sub lib_osds_afd_control_devices_accessible
{
  my ($file_handle);

  # createFile - 'k' = keep the file if it exists (don't create)
  #            - 'e' - the file must already exist (fail if it doesn't)
  #            - 'q' - query (no read or write)

  # see if we can open the AFD device
  $file_handle = Win32API::File::createFile(AFD_CTL_DEV, "q ke");
  if ($file_handle <= 0)
  {
    my ($device) = "AFD";
    acfslib::lib_error_print(9121, "failed to detect control device '%s'", $device);
    return 0;
  }
  Win32API::File::CloseHandle($file_handle);

  return 1;
} # end lib_osds_afd_control_devices_accessible

# Get the oracle binary user name
#
sub lib_osds_get_asm_user
{
  my ($username);
  my ($KFOD);
  my ($ret);
  my ($ADE_VIEW_ROOT) = $ENV{ADE_VIEW_ROOT};
  my (@out_array);

  if (defined($ADE_VIEW_ROOT))
  {
    $KFOD = "$ADE_VIEW_ROOT/oracle/rdbms/bin/kfod hostlist=local NOHDR=true";
  }
  else
  {
    $KFOD = "$ORACLE_HOME/bin/kfod hostlist=local NOHDR=true";
  }

  open(KFOD, "$KFOD |");
  chomp(my $kfodout = <KFOD>);
  close (KFOD);
  $ret = $?;
  # print "lib_get_get_asm_user: kfod return code = $ret\n";

  if ($ret ne 0)
  {
    # return an undefined value to signify that ASM is not running.
    $out_array[0] = $username;
  }
  elsif ($kfodout eq "")
  {
    # return an undefined value to signify that ASM is not running.
    $out_array[0] = $username;
  }
  else
  {
    # return a defined value.
    $out_array[0] = "admin";
  }
  $out_array[1] = 0;          # use 0 as the NT gid.

  return (@out_array);
} # end lib_osds_get_asm_user

# lib_osds_afd_load_driver()
#
sub lib_osds_afd_load_driver
{ 
  my ($driver) = @_;

  return common_driver_load_unload("start", $driver);
} # end lib_osds_afd_load_driver


# lib_osds_run_as_user
#
# Not used needed for Windows - basically a pass through stub
sub lib_osds_run_as_user
{
  my ($user_name, $cmd) = @_;
  my ($return_code);

  # strip off leading "./" if it exists
  $cmd =~ s/^\.\///;
  system($cmd);
  # Check the return code for 
  # failure to execute.  I don't check for signals (& 127).
  if ( $? == -1 )
  {
    $return_code = -1;
  } 
  else 
  {
    $return_code = $? >> 8;
  }
  return $return_code;
} # end lib_osds_run_as_user

# lib_osds_afd_unload_driver()
#
sub lib_osds_afd_unload_driver
{
  my ($driver, $install_files_loc) = @_;

  return common_driver_load_unload("stop", $driver);
} # end lib_osds_afd_unload_driver


# lib_osds_afd_supported.
#
# The fact that we got here means that there is some support for
# this platform. However, perhaps not all releases are supported.
# We make that determination here.
#
# return true or false
#
sub lib_osds_afd_supported
{
  # From:
  #   http://kobesearch.cpan.org/htdocs/Win32/Win32.pm.html#Win32_GetOSVersion
  #
  # Note: that you MUST have at least Perl V5.10 to get correct values
  # for Windows 7 and Server 2008.
  # 
  # Win32::GetOSVersion()
  # OS                    ID    MAJOR   MINOR  PRODUCT_TYPE
  # Win32                  0      -       -         -
  # Windows 95             1      4       0         -
  # Windows 98             1      4      10         -
  # Windows Me             1      4      90         -
  # Windows NT 3.51        2      3      51         -
  # Windows NT 4           2      4       0         -
  # Windows 2000           2      5       0         -
  # Windows XP             2      5       1         -
  # Windows Server 2003    2      5       2         -
  # Windows Vista          2      6       0         1
  # Windows Server 2008 R1 2      6       0         3
  # Windows 7              2      6       1         1
  # Windows Server 2008 R2 2      6       1         3
  # Windows 8              2      6       2         1
  # Windows Server 2012    2      6       2         3
  # Windows 8.1            2      6       3         1  
  # Windows Server 2012 R2 2      6       3         3

  my $afdEnv = $ENV{_AFD_ENABLE};
  if (!defined $afdEnv)
  {
    $afdEnv = "";
  }

  # revert to this code when ism lrgs run fine
  # If AFD is disabled by the env variable, do not proceed with install
  if (!($afdEnv eq "TRUE"))
  {
    acfslib::lib_error_print(618,
          "AFD is not supported on this operating system: '%s'", "Windows");
    return 0;
  }

  # GetOSVersion was deprecated in Windows 8.1. That means that while you can 
  # still call the APIs, Your app does not specifically target Windows 8.1, 
  # You will get Windows 8 versioning (6.2.0.0).

  my ($desc, $major, $minor, $build, $id, undef, undef, undef, $prod_type) =
                                                        Win32::GetOSVersion();

  $ARCH = $ENV{PROCESSOR_ARCHITECTURE};

  if ($ARCH eq "x86")
  {
    # Detect WoW64 mode, which is active when running a 32-bit binary
    # on a 64-bit architecture
    if (defined($ENV{PROCESSOR_ARCHITEW6432}) &&
        $ENV{PROCESSOR_ARCHITEW6432} eq "AMD64") 
    {
      $ARCH = "x86_64";
    }
    else
    {
      $ARCH = "i386";
    }
  }

  if (($ARCH eq "x64") || ($ARCH eq "AMD64") || ($ARCH eq "x86_64"))
  {
     $ARCH = "x86_64";
  }
  else
  {
    # TODO for other architectures
    acfslib::lib_error_print(9120,
                     "The '%s' machine architecture is not supported.", $ARCH);
    return 0;
  }

  # parse GetOSVersion() results - see subroutine header
  if (($id eq 2) && ($major == 6) && ($minor == 0) && ($prod_type == 3))
  {
    $OS_TYPE = "Windows Server 2008 R1";
    $OS_SUBDIR = "2008";
  }
  elsif (($id eq 2) && ($major == 6) && ($minor == 1) && ($prod_type == 3))
  {
    $OS_TYPE = "Windows Server 2008 R2";
    $OS_SUBDIR = "2008R2";
  }
  elsif (($id eq 2) && ($major == 6) && ($minor == 2) && ($prod_type == 3))
  {
    # We'll do a extra validation to determine if this Windows Server 2012 or
    # Windows Server 2012 R2
    my $wmi = Win32::OLE->GetObject("WinMgmts://./root/cimv2");
    my $list = $wmi->InstancesOf("Win32_OperatingSystem");
    my $version;
    for my $item ( Win32::OLE::in $list ) {
      $version = $item->{Version};
    }
    # For Windows Server 2012 R2 you got 6.3.9600
    if (defined($version) &&
        $version =~ /6.3/)
    {
      $OS_TYPE = "Windows Server 2012 R2";
      $OS_SUBDIR = "2012R2";
    }
    else
    {
      $OS_TYPE = "Windows Server 2012";
      $OS_SUBDIR = "2012";
    }
  }
  # Just in case
  elsif (($id eq 2) && ($major == 6) && ($minor == 3) && ($prod_type == 3))
  {
    $OS_TYPE = "Windows Server 2012 R2";
    $OS_SUBDIR = "2012R2";
  }

  # The above platforms are all that we support for now.
  if (defined($OS_TYPE))
  {
    return 1;
  }

  ##### We have a non-supported Windows version. Identify it.

  if (($id eq 1) && ($major == 4) && ($minor == 0))
  {
    $OS_TYPE = "Windows 95";
  }
  elsif (($id eq 1) && ($major == 4) && ($minor == 10))
  {
    $OS_TYPE = "Windows 98";
  }
  elsif (($id eq 1) && ($major == 4) && ($minor == 90))
  {
    $OS_TYPE = "Windows Me";
  }
  elsif (($id eq 2) && ($major == 3) && ($minor == 51))
  {
    $OS_TYPE = "Windows NT 3.51";
  }
  elsif (($id eq 2) && ($major == 4) && ($minor == 0))
  {
    $OS_TYPE = "Windows NT 4";
  }
  elsif (($id eq 2) && ($major == 5) && ($minor == 0))
  {
    $OS_TYPE = "Windows 2000";
  }
  elsif (($id eq 2) && ($major == 5) && ($minor == 1))
  {
    $OS_TYPE = "Windows XP";
  }
  elsif (($id eq 2) && ($major == 5) && ($minor == 2))
  {
    $OS_TYPE = "Windows Server 2003";
  }
  elsif (($id eq 2) && ($major == 6) && ($minor == 0) && ($prod_type == 1))
  {
    $OS_TYPE = "Windows Vista";
  }
  elsif (($id eq 2) && ($major == 6) && ($minor == 1) && ($prod_type == 1))
  {
    $OS_TYPE = "Windows 7";
  }
  elsif (($id eq 2) && ($major == 6) && ($minor == 2) && ($prod_type == 1))
  {
    # We'll do a extra validation to determine if this Windows 8 or
    # Windows 8.1
    my $wmi = Win32::OLE->GetObject("WinMgmts://./root/cimv2");
    my $list = $wmi->InstancesOf("Win32_OperatingSystem");
    my $version;
    for my $item ( Win32::OLE::in $list ) {
      $version = $item->{Version};
    }
    # For Windows 8.1 you got 6.3.9600
    if (defined($version) &&
        $version =~ /6.3/)
    {
      $OS_TYPE = "Windows 8.1";
    }
    else
    {
      $OS_TYPE = "Windows 8";
    }
  }
  elsif (($id eq 2) && ($major == 6) && ($minor == 3) && ($prod_type == 1))
  {
    $OS_TYPE = "Windows 8.1";
  }
    
  if (defined($OS_TYPE))
  {
    acfslib::lib_error_print(9125,
                            "AFD is not supported on this operating system: '%s'.",
                            $OS_TYPE);
  }
  else
  {
    acfslib::lib_error_print(9125,
                            "AFD is not supported on this operating system: '%s'.",
                            "unrecognized OS");
    acfslib::lib_error_print
      (9140,
       "unable to determine the correct drivers for this version of Windows: ID: %s Major: %s Minor: %s Product Type: %s",
       $id, $major, $minor, $prod_type);
  }

  return 0;

} # end lib_osds_afd_supported

# lib_osds_afd_verify_devices
#
sub lib_osds_afd_verify_devices
{
  return USM_SUCCESS;
} #end lib_osds_afd_verify_devices

######################################
## internal static functions
######################################

sub query
{
  my ($query_type, $driver) = @_;
  my ($retval)      = 0;
  my ($have_driver) = 0;
  my %driver_status;

  if ( Win32::Service::GetStatus( "", $driver, \%driver_status) == 0 )
  {
    # Driver not installed.
    # Warning: We can get here if the driver is in the "STOP_PENDING"
    # state.  Maybe this is a bug in Win32::Service.
    # Shouldn't matter to what we're doing ...
    return 0;
  }

  if ($query_type eq "running")
  {
    if ( $driver_status{CurrentState} == SERVICE_RUNNING )
    {
      $retval = 1;
    }
    elsif ( $driver_status{CurrentState} == SERVICE_STOP_PENDING )
    {
      # The driver is not stopped. Likely it is in use.
      $retval = 1;
    }
  }
  elsif ($query_type eq "installed")
  {
    # The fact that Win32::Service found the driver is sufficient.
    $retval = 1;
  }
  elsif ($query_type eq "query")
  {
    # Return the driver state
    return $driver_status{CurrentState};
  }
  else
  {
    acfslib::lib_error_print(9128, "unknown query type '%s'",  $query_type);
  }

  return $retval;
}

# common_driver_load_unload()
#
# Use Win32::Service to start or stop the specified driver.
# 
sub common_driver_load_unload
{ 
  my ($action, $driver) = @_;
  my ($ret)             = USM_FAIL;
  my $driverState       = 0;
  my ($timeoutMax) = 1200;
  my ($timeout) = 0;
  
  if ($action eq "start")
  {
    if (query("running", $driver)) 
    {
      # driver already running or was started
      $ret = USM_SUCCESS;
    }
    else
    {
      acfslib::lib_error_print(652,
         "Manual loading is not permitted for driver '%s' on this operating system", $driver);   
    }
  }
  else # ($action eq "stop")
  {
    $driverState = query ( "query", $driver );

    if ( $driverState == SERVICE_STOPPED )     
    { 
      return USM_SUCCESS;
    }

    if ( $acfslib::CRS_ACTION eq "clean" )   
    {
        # For clean we fire stop requests at the drivers in rapid
        # succession without regard for any STOP_PENDING states that
        # might be encountered.
        if ( $driverState == SERVICE_RUNNING )
        {
          return USM_FAIL;
        }
        else
        { 
          return USM_SUCCESS;
        }
    }

    #
    # Wait for driver to stop.  In this way we serialize the driver
    # stops and thus increase our chance of success.   This prevents us
    # from stopping a driver while a driver that depends on it is in the
    # "STOP_PENDING" state.
    #

    $driverState = query ( "query", $driver );
    while (( $driverState != SERVICE_STOPPED ) && ($timeout < $timeoutMax))
    {
        sleep 10;
        $timeout += 10;
        acfslib::lib_inform_print(653,
          "Waiting for driver '%s' to unload.", $driver);
        $driverState = query ( "query", $driver );
    }
    return USM_FAIL if ($timeout >= $timeoutMax);
    
    $ret = USM_SUCCESS;

  }
  return $ret;
} # end common_driver_load_unload

# lib_osds_get_drive_info
#   Get info for the drive letter.  Return a reference to a hash
#   containing the following elements:
#       Path
#       DriveLetter
#       ShareName
#       DriveType
#       RootFolder
#       AvailableSpace
#       FreeSpace
#       TotalSize
#       VolumeName
#       FileSystem
#       SerialNumber
#       IsReady

sub lib_osds_get_drive_info
{
    my $drive_letter = shift;
    my $fs = Win32::OLE->new("Scripting.FileSystemObject");
    $drive_letter = uc($drive_letter); # $fs->Drives->DriveLetter are uc
    foreach my $drv ( Win32::OLE::in($fs->Drives) )
    {
        return $drv if ( $drv->{DriveLetter} eq $drive_letter );
    }
    return 0;
}

#
# lib_osds_is_abs_path 
#    Note that we do not support mounting on a relative absolute path
#    like \blah\blah\blah.  The path must include a drive letter to be
#    consider absolute as in X:\blah\blah\blah.
#
sub lib_osds_is_abs_path
{
  my $path = shift;
  if ( $path =~ /^[[:alpha:]]:/ )
  {
    return 1;
  }
  return 0;
}

# lib_osds_asmlib_installed
# (linux specific check. NOOP for Windows)
#
sub lib_osds_asmlib_installed
{
  # 1 indicates ASMLIB not installed
  return 1;
} 

sub lib_osds_afd_delete_oracleafd_disks
{
  # Delete files created under \oracle\oracleafd\disks\* 
  
  if(opendir (DIR, $disksdir))
  {
    while (my $file = readdir(DIR)) {
      if($file ne "." && $file ne "..")
      {
        my $filepath = $disksdir."/".$file;
        if(-e $filepath)
        {
         unlink("$filepath");
        }  
      }
    }
    closedir(DIR);	 
  }
}

sub lib_osds_afd_copy_library
{
  my ($ret);
  my ($uid);
  my ($gid);
  my ($source);
  my ($libpath);
  my ($target)      = $ENV{_vendor_lib_loc};
  my ($return_code) = USM_SUCCESS;

  my ($asmadmin)    = acfslib::lib_get_asm_admin_name();
  my ($user)        = acfslib::getParam("ORACLE_OWNER"); 

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
    $target = "$SYSDRIVE\\oracle\\extapi\\64\\asm\\";
  }

  # oraafd19.dll goes to %SYSTEMDRIVE%\\oracle\\extapi\\...
  $source = "$ORACLE_HOME\\bin\\$LIBAFD";
  $libpath = $target.$LIBAFD;

  # Get Owner and group of source
  ($uid, $gid) = (stat($source))[4,5];

  #
  # NOTE: getpwnam/getgrnam are not implemented on Windows.
  #
  #if($user)
  #{
  #  $uid = getpwnam($user);
  #}
  #$gid = getgrnam($asmadmin);

  # create $target directory if it does not exist
  if(!(-d $target))
  {
     File::Path::make_path( $target, {mode => 0755} );
     if ($?)
     {
       acfslib::lib_error_print(9345,
                               "Unable to create directory: '%s'.", $target);
       return USM_FAIL;
     }
  }

  acfslib::lib_verbose_print (9504, "Copying file '%s' to the path '%s'",
                              $source, $target);

  # copy oraafd12.dll into $target
  File::Copy::copy($source, $target) or $return_code = USM_FAIL;

  if($return_code == USM_SUCCESS)
  {
     $ret = chmod 0755, $libpath;
     $ret = chown $uid, $gid, $libpath;
     if($ret != 1)
     {
        acfslib::lib_error_print(9426,
                         "unable to set the file attributes for file '%s'",
                         $libpath);
        return USM_FAIL;
     } 
  }

  return $return_code;
}

sub lib_osds_afd_post_load_setup
{

  my ($return_val) = USM_SUCCESS;

  # Make sure that the proper /dev files get created by udevd
  acfslib::lib_inform_print(649, "Verifying AFD devices.");

  $return_val = lib_osds_afd_verify_devices();
  if ($return_val != USM_SUCCESS)
  {
    # osds_verify_afd_devices() will print the specific error(s), if any;
    return $return_val;
  }

  #  create folder for disk dir
  `mkdir $disksdir`;

  # Enable logging
  `$ORACLE_HOME\\bin\\afdtool -log -d`;
  if ($?)
  {
     acfslib::lib_inform_print(9225, "Failed to start AFD logging.");

     # Though failed, continue with rest of the flow
  }

  # Scan devices and send other persistent states to AFD Driver
  `$ORACLE_HOME\\bin\\afdboot -scandisk`;

  return $return_val;
}

1;
# vim:ts=2:expandtab
