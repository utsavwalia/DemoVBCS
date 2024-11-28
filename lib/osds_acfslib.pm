#
#
# osds_acfslib.pm
#
# Copyright (c) 2007, 2021, Oracle and/or its affiliates. 
#
#
#    NAME
#      osds_acfslib.pm - Windows OSD library components.
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
use osds_acfsregistrymount;
use Win32;
use Win32::OLE;
use Win32::Service;
use Win32::TieRegistry;
use File::Path;
use File::Basename;
use File::Spec;
package osds_acfslib;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
                 lib_osds_check_uninstall_required
                 lib_osds_am_root
                 lib_osds_check_driver_inuse
                 lib_osds_check_driver_installed
                 lib_osds_check_driver_loaded
                 lib_osds_check_loaded_drivers_mismatch
                 lib_osds_control_devices_accessible
                 lib_osds_create_mount_point
                 lib_osds_device_from_mountpoint
                 lib_osds_get_advm_mounts
                 lib_osds_get_asm_user
                 lib_osds_get_drive_info
                 lib_osds_is_local_container
                 lib_osds_is_mounted
                 lib_osds_load_driver
                 lib_osds_mountpoint_descriptors
                 lib_osds_mount
                 lib_osds_run_as_user
                 lib_osds_unload_driver
                 lib_osds_unmount
                 lib_osds_usm_supported
                 lib_osds_validate_asmadmin_group
                 lib_osds_verify_usm_devices
                 lib_osds_is_abs_path
                 lib_osds_are_same_file
                 lib_osds_acfsr_configure
                 lib_osds_acfs_remote_supported
                 lib_osds_acfs_remote_installed
                 lib_osds_acfs_remote_loaded
                 lib_osds_get_drivers_path
                 lib_osds_get_drivers_version
                 lib_osds_check_config
                 lib_osds_check_kernel
                 lib_osds_uncompress_driver_files
                 lib_osds_acfs_reg_key
                 @DRIVER_COMPONENTS
                 $ACFSUTIL
                 $ARCH
                 $OS_SUBDIR
                 $OS_TYPE
                 $REDIRECT
                 $TMPDIR
                 $ORACLE_HOME
                 $SYSTEM_ROOT
                 $SYSTEM_DRIVE
                 AVD_CTL_DEV
                 OFS_CTL_DEV
                 AVD_IDX
                 OFS_IDX
                 OKS_IDX
                 OPT_CHR
                 USM_FAIL
                 USM_SUCCESS
                 USM_SUPPORTED
                 USM_NOT_SUPPORTED
                 USM_REBOOT_RECOMMENDED
                 USM_TRANSIENT_FAIL
                 %configuration
                 );

# return/exit codes
#
# USM_TRANSIENT_FAILures are those that can be easily filed by the admin.
# In the case of "acfsroot install", the admin could fix the error and then
# resume a grid install, for example, from the checkpoint.
use constant USM_SUCCESS            => 0;
use constant USM_FAIL               => 1;
use constant USM_NOT_SUPPORTED      => 2;
use constant USM_REBOOT_RECOMMENDED => 3;
use constant USM_TRANSIENT_FAIL     => 1;
use constant USM_SUPPORTED          => 5;

use constant OPT_CHR => "/";            # Windows option character

use constant AVD_CTL_DEV => "\\\\.\\.asm_ctl_spec";# really "\\.\.asm_ctl_spec"
use constant OFS_CTL_DEV => "\\\\.\\OFSCTL";       # ditto about the slashes

use constant AVD_IDX => 0;                      # index into driver_ccomponents
use constant OKS_IDX => 1;                      # index into driver_ccomponents
use constant OFS_IDX => 2;                      # index into driver_ccomponents
our (@DRIVER_COMPONENTS) = (
           "oracle advm", "oracle oks", "oracle acfs",
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
our ($ORACLE_HOME)  = lib_osds_acfs_reg_key("ORACLE_HOME");
our ($SYSTEM_ROOT)  = lib_osds_acfs_reg_key("SYSTEM_ROOT");
our ($SYSTEM_DRIVE) = lib_osds_acfs_reg_key("SYSTEM_DRIVE");
our ($UNAME_A)      = lib_osds_acfs_reg_key("PRODUCTNAME");
our ($ACFSUTIL)     = "$ORACLE_HOME\\bin\\acfsutil";
our ($SECURE_BOOT_STATE)  = lib_osds_acfs_reg_key("SECURE_BOOT_STATE");
our ($TMPDIR)       = dirname(acfslib::osds_get_state_file_name())."\\temp";

#Declare a hash array to store configuration values
our (%configuration) = ();

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
#  Note: this function does nothing in Windows.
#
sub lib_osds_check_driver_inuse
{
  my ($driver) = @_;

  # TODO - how can we do this???
  # According to Jerry, it can't be done. You just issue a stop and
  # if the driver's in use, the state will be STOP_PENDING instead of STOPPED

  # pretend the driver is not in use, that's all we can do.
  return 0;
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

# lib_osds_check_uninstall_required
#
sub lib_osds_check_uninstall_required
{
  my ($previous_install_detected_msg) = @_;
  my ($return_code);
  $return_code = acfslib::lib_check_any_driver_installed();
  if(($return_code) && ($previous_install_detected_msg))
  {
    acfslib::lib_inform_print(9312, "Existing ADVM/ACFS installation detected.");
  }
  return $return_code;
} # end lib_osds_check_uninstall_required

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

# lib_osds_is_mounted
#
# check to see if the specified mount point is active
#
# TODO - right now we only handle OFS file systems
#
sub lib_osds_is_mounted
{
  my ($mount_point) = @_;           # mount point to test
  my ($mounted) = 0;                # assume not mounted
  my ($result);

  # Change any '/' in the path to '\\'.
  # This is caused by the fvfs test.
  # Its mount point defaults to x\x\x/y.
  # We should be able to handle both cases, since I
  # can't guarantee unix admins will type it the same
  # as windows folks will.
  #
  # So we can end up with x/x\y and \s\s and \s\s/x and \\s\\s
  $mount_point =~ s/\//\\\\/g;
  # now, if we have \\, convert it to a single \ for the following compare.
  $mount_point =~ s/\\\\/\\/g;
  # Normalize drive letter specification by removing trailing backslash
  $mount_point = substr ($mount_point,0,2)
    if ( length($mount_point) == 3 && substr($mount_point,1,2) eq ":\\" );
  # disallow relative pathnames
  if ( ! acfslib::lib_is_abs_path ( $mount_point ) )
  {
    acfslib::lib_error_print(9366,
        "Relative path for mount point '%s' is not supported.", $mount_point);
    return $mounted;
  }

  # TODO: This used to have a 2>&1 in it.
  # Now it needs to have the failure case tested.
  #
  # Does it?  We don't check the errors.
  #
  open(CHECK, "$ORACLE_HOME/bin/acfsmountvol $REDIRECT |");
  while ($result = <CHECK>)
  {
    # remove all white space
    chomp($result);
    $result =~ s/^\s*//;
    # Normalize drive letter specification by removing trailing backslash
    $result = substr ($result,0,2)
      if ( length($result) == 3 && substr($result,1,2) eq ":\\" );
    if ($result eq $mount_point)
    {
      # the mountpoint is found.
      $mounted = 1;
      last;
    }
  }
  close(CHECK);
  return $mounted;
} # end lib_osds_is_mounted

# lib_osds_control_devices_accessible
#
# We test the USM control device accessibility by opening them
#
# return true (1) or false (0)
#
sub lib_osds_control_devices_accessible
{
  my ($file_handle);

  # createFile - 'k' = keep the file if it exists (don't create)
  #            - 'e' - the file must already exist (fail if it doesn't)
  #            - 'q' - query (no read or write)

  # see if we can open the ADVM device
  $file_handle = Win32API::File::createFile(AVD_CTL_DEV, "q ke");
  if ($file_handle <= 0)
  {
    my ($device) = "ADVM";
    # acfslib::lib_error_print(9121, "Failed to detect control '%s'.", $device);
    return 0;
  }
  Win32API::File::CloseHandle($file_handle);

  # see if we can open the ACFS device
  $file_handle = Win32API::File::createFile(OFS_CTL_DEV, "q ke");
  if ($file_handle <= 0)
  {
    my ($device) = "ACFS";
    # acfslib::lib_error_print(9121, "Failed to detect control '%s'.", $device);
    return 0;
  }
  Win32API::File::CloseHandle($file_handle);

  return 1;
} # end lib_osds_control_devices_accessible

# lib_osds_create_mount_point
#
# Create the mount point directory.
#

sub lib_osds_create_mount_point
{
  my $mount_point       = shift;
  my $create_mount_path = 0;
  my $drive_info        = 0;
  my $drive_letter      = "";
  my $folder            = "";

  #
  #  Extract the drive letter from the mount path, if any.
  #

  if ( $mount_point =~ /^[a-zA-Z]:/ )
  {
      # We have a drive letter.  See what we can find out about
      # it.
      $drive_letter = uc(substr($mount_point,0,1));
      $drive_info = lib_osds_get_drive_info ($drive_letter);
  }

  #
  #  Extract the folder part of the path, if any.
  #

  if ( $drive_letter eq "" )
  {
    $folder = $mount_point;
  }
  else
  {
    $folder = $mount_point;
    # Strip drive letter leaving single leading "\"
    $folder =~ s/^.:\\*/\\/;
    # If folder is "\", treat it like a drive letter. i.e. no
    # folder specified.
    $folder = "" if ( $folder eq "\\" );
  }

  #
  #  Verify that if we have a drive letter and a folder the 3rd
  #  char is a backslash.  This is invalid: C:dbhome.  This is
  #  valid: C:\dbhome
  #

  if ( $drive_letter ne "" &&
       $folder ne "" &&
       substr($mount_point,2,1) ne "\\" )
  {
      acfslib::lib_error_print(9000,
          "Invalid drive letter specification: %s", $mount_point);
      return USM_FAIL;
  }

  #
  #  There are some rules governing mount point directory creation.
  #

  if ( $drive_letter ne "" && $folder ne "" )
  {
    # Rule 1: If we have a drive letter and we're mounting on a
    # folder, create the folder.  Note that the drive letter must
    # exist and be a volume.

    if ( $drive_info && $drive_info->{FileSystem} ne "" )
    {
        # The drive exists and has a file system on it.
        $create_mount_path = 1;
    }
    else
    {
      if ( ! $drive_info )
      {
        # Drive doesn't exist
        acfslib::lib_error_print(10285,
          "Pathname '%s' does not exist.", $drive_letter . ":" );
        return USM_FAIL;
      }
      else
      {
        # drive exists but isn't an FS
        acfslib::lib_error_print(9999,
          "A folder was specified but ${drive_letter}: " .
          "does not contain a filesystem." );
        return USM_FAIL;
      }
    }
  }
  elsif ( $drive_letter ne "" && $folder eq "" )
  {
    # Rule 2: If we have only a drive letter and no folder is specified,
    # acfsmountvol will mount directly onto the driver letter.  The
    # drive letter must not exist.

    if ( $drive_info )
    {
      # The drive exists.  This is an error.  The user is asking
      # us to mount on <x>: We have no idea what <x:> is being
      # used for.  We don't want to mount over it. acfsmountvol
      # will throw an error.
      $create_mount_path = 0;
    }
    else
    {
      # The drive doesn't exist (good). acfsmountvol will mount
      # directly onto the drive.
      $create_mount_path = 0;
    }
  }

  elsif ( $drive_letter eq "" && $folder ne "" )
  {
    # Rule 3: If a folder is specified without a drive letter, create
    # the folder on the current drive.  Note that it is an error to
    # specify a folder without a mount path but we'll handle it.  It
    # should have been thrown out above us.
    $create_mount_path = 1;
  }

  #  Create the mount path if applicable.

  if ( $create_mount_path  )
  {
    acfslib::lib_inform_print(9255, "Creating '%s' mount point.", $mount_point);
    unless( defined eval {File::Path::mkpath($mount_point)})
    {
      acfslib::lib_error_print(9999, "System error: " . $@);
      acfslib::lib_error_print(9256, "Failed to create mountpoint '%s'.",
        $mount_point);
      return USM_FAIL;
    }
  }
  return USM_SUCCESS;
}

# lib_osds_device_from_mountpoint
#
# return the device name given a mount point
#
sub lib_osds_device_from_mountpoint
{
  my ($mountpoint) = @_;
  my ($device);
  my ($prev_str);
  my ($str);

  open (DEV, "$ORACLE_HOME/bin/acfsmountvol |");
  while ($str = <DEV>)
  {
    $str =~ s/\s+//;
    chomp($str);

    if ($str eq $mountpoint)
    {
      $device = lc($prev_str);
      last;
    }

    $prev_str = $str;
  }

  close (DEV);

  return $device;
} # end lib_osds_device_from_mountpoint

# lib_osds_get_advm_mounts
#
# return an doubly dimensioned array of devices and mountpoints
# of all currently mounted OFS file systems
# array element[0] is the device and array element[1] is the mountpoint
#
# TODO - Right now we can only do acfs mounts - not all advm mounts
#
sub lib_osds_get_advm_mounts
{
  my (@array);
  my ($result);
  my ($index) = 0;
  my ($have_device) = 0;
  my ($device, $mount_point);

  open (MOUNT, "$ORACLE_HOME/bin/acfsmountvol |");
  while ($result = <MOUNT>)
  {
    # A mount entry looks like (for example):
    #       <blank line>
    #       asm_dg_vol
    #           e:\mnt

    # remove leading and trailing space
    chomp($result);
    $result =~ s/^\s+//;

    if ($result eq "")
    {
      $have_device = 0;
      next;
    }
    if ($have_device == 0)
    {
      # our last result was a blank line so this has to be the device
      $device = $result;
      $have_device = 1;
    }
    else
    {
      # our last result was the device so this has to be the mountpoint
      $mount_point = $result;

      push @{$array[$index]}, $device, $mount_point;
      $index += 1;
      $have_device = 0;    # just in case
    }
  }
  close(MOUNT);
  return \@array;
} # end lib_osds_get_advm_mounts

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

# lib_osds_load_driver()
#
sub lib_osds_load_driver
{
  my ($driver) = @_;

  return common_driver_load_unload("start", $driver);
} # end lib_osds_load_driver

# lib_osds_mountpoint_descriptors
#
# called with action = 1 when the user calls "clean" for force any open file
# references to be cleared from a mount point to ensure that the unmount
# will succeed.
#
# called with action = 0 to print open references on the mount point.
#
use Cwd 'abs_path';
use File::Basename;

sub lib_osds_mountpoint_descriptors
{
  my ($mountpoint, $action) = @_;
  my ($handle) = "$ORACLE_HOME/bin/handle.exe";
  my ($len_mountpoint);        # mount point string length
  my ($device);                # mount point ADVM device name
  my ($have_device);           # found the mount point device
  my ($str);                   # temporary "working" variable
  my ($descriptor_list);       # list of open desctiptors
  my ($prog_name);             # executable program name
  my ($prog_path);             # Path of the binary
  my ($file_path);             # path of open file
  my ($pid) = "";              # process ID from sysinternals::Handle
  my ($retval) = USM_SUCCESS;  # return value

  # Normalize drive letter specification by removing trailing backslash
  $mountpoint = substr ($mountpoint,0,2)
    if ( length($mountpoint) == 3 && substr($mountpoint,1,2) eq ":\\" );

  # Escape the mountpoint characters.
  $mountpoint = quotemeta(lc($mountpoint));

  # get the device from the mount point
  open (DEV, "$ORACLE_HOME/bin/acfsmountvol |");
  while ($str = <DEV>)
  {
    $str =~ s/\s+//;
    chomp($str);
    # Don't store the quotemeta in this one cause we want the dev un meta'd
    # for later compares.
    $str = lc($str);
    if (quotemeta($str) eq $mountpoint)
    {
      $have_device = 1;
      $len_mountpoint = length($mountpoint);
      last;
    }
    else
    {
      $device = lc($str);
    }
  }
  close (DEV);

  if (!defined($have_device))
  {
    acfslib::lib_error_print(9122,
            "ADVM device not determined from mount point '%s'.", $mountpoint);
    if ($action)
    {
      return $retval;
    }
    else
    {
      return $descriptor_list;
    }
  }

  #### First we kill all the open file handles on the mount point

  # TODO: Figure a way to check the error case here,
  # this used to have a 2>&1 in it.
  # It was removed for Windows execution in a CRS enviroment, which
  # seems to choke on the redirection.
  # Or does it?  Perhaps it was choking on the eula.  Revisit this in MAIN.
  #
  # Do we not want to die if we can't open this?
  # Accept the eula so that it doesn't hang up CRS, waiting for GUI input.

  if (! -e $handle)
  {
    acfslib::lib_error_print(9123, "%s command not found.", $handle);
    if ($action)
    {
      return $retval;
    }
    else
    {
      return $descriptor_list;
    }
  }

  open (HANDLE, "$handle -a $REDIRECT /accepteula |");
  if ( $! != 0 )
  {
    acfslib::lib_error_print(9138,
                             "command '%s' completed with an error: %s",
                             $handle, $!);
    if ($action)
    {
      return $retval;
    }
    else
    {
      return $descriptor_list;
    }
  }
  while($str = <HANDLE>)
  {
    chomp $str;
    $str =~ s/^\s*//; # strip leading space

    # handle -a output consists of 3 or more lines per entry
    # line 1: ----------------------------------------------
    # line 2: <executable> pid: <pid> <domain>
    # line 3: {tab} <handle>: <type> <name>
    # -- or --
    # line 3: {tab} <handle>: <type> (---) <name>
    # line x: if it exists, repeat of line 3 format
    my @fields = split ( /\s+/, $str );

    #
    #  Check for the "line 1" case: a row of dashes.
    #

    next if ( $str =~ "^-+\$" );

    #
    #  Check for "line 2" case: a line containing a pid and program name
    #  Example format:
    #   gvim.exe pid: 4980 NEDCDOMAIN\gsanders
    #

    if ($fields[1] eq "pid:")
    {
      $pid = $fields[2];
      $prog_name = $fields[0];
      # The next line should be a "line 3" line.  It should contain a
      # handle and path.
      next;
    }

    #
    #  This is either a "line 3" or a line of Handle's front matter
    #  (i.e, version info, copyright, sysinternals web address, etc).
    #  If we don't have a pid yet, we're looking at front matter so
    #  move past it.
    #

    next if ( $pid == "" );

    #
    #  If we get here we have a "line 3" line containing a handle and
    #  path of open file.  Here's some format examples:
    #    2F0: File (RWD) \Device\Asm\asm-CRSDG1VOL1-279\foobar.txt
    #    280: File (RW-) C:\.foobar.txt.swp
    #  Double check that we have a handle field.
    #

    next if ( $fields[0] !~ /^\s*[0-9A-F]+:$/ );

    #
    #  We have a "line 3" line. It contains a handle and path.
    #

    $file_path = lc ($fields[-1]);

    #  Don't quotemeta this, as it could be either a device:
    #  \Device\Asm\asm-TEST1-54
    #  - or -
    #  a mountpoint:
    #  c:\blah\blah

    if ( ( $file_path =~ /\\device\\asm\\$device.*/i ) ||
         ( $file_path =~ /^$mountpoint/ ) )
    {
      if ($action == 1)
      {
        acfslib::lib_inform_print(9126,
           "Attempting to terminate the program '%s' with OS process ID '%s'.",
           $prog_name, $pid);
        $retval = system("tskill $pid");
        if ($retval)
        {
          my (%info) = get_pid_info($pid);
          if (defined($info{'PID'}))
          {
            acfslib::lib_inform_print(9136,"PID %s could not be killed.",$pid);
            report_pid_info(%info);
          }
          else
          {
            # the PID is no longer found
          }
        }
      }
      else
      {
        #print "prog_name $prog_name pid $pid prog_directory $prog_directory\n";
        $descriptor_list .= "$pid ";
      }
    }
  }
  close (HANDLE);

  ##### handle.exe doesn't get us the device name of running executables
  ##### so we have to find those separately.

  # If we cannot access WMI, we just keep going.
  my $processes = Win32::OLE->GetObject("winmgmts:")->InstancesOf("Win32_Process");
  for my $proc (in $processes)
  {
    $str =~ s/\s+/ /g;
    chomp($str);
    my (@str_array) = split(/ /, $str);
    my ($count) = 0;

    $prog_name = $proc->{Name};
    $prog_path = $proc->{ExecutablePath};
    $pid = $proc->{ProcessId};

    # ignore the "impossible"
    if ($prog_path =~ /^\\SystemRoot/)
    {
      next;
    }

    # ignore items without an ExecutablePath
    if ($prog_path eq "")
    {
      next;
    }

    # abs_path(), below, doesn't like drive letters in the name so we strip
    # it off - if it exists. NBD, abs_path() will put it back.
    if ($prog_path =~ /:/)
    {
      my @str_array = split(/:/, $prog_path);
      $prog_path = $str_array[1];
    }

    # get the mount point of the executable.
    # 1. strip off the file name (required for abs_path().
    # 2. get path name of the directory including the drive letter.
    # 3. trim off the trailing "fluff".
    # 4. convert to lower case to match $mountpoint format.
    # 5. reverse the '/' that abs_path() inserted after the ':'.
    # 6. Quote meta characters, such as \

    if (-e $prog_path)
    {
      $prog_path = dirname($prog_path);                    #1
      $prog_path = abs_path($prog_path) or next;           #2
      $prog_path = substr($prog_path, 0, $len_mountpoint); #3
      $prog_path = lc($prog_path);                         #4
      $prog_path =~ s/\//\\/;                              #5
      $prog_path = quotemeta($prog_path);                  #6
    }

    if ($mountpoint eq $prog_path)
    {
      if ($action == 1)
      {
        # TODO: Spit out message we are terminating a process.
        $retval = $proc->Terminate();
        if ($retval)
        {
            $pid = $proc->{CommandLine};
            my (%info) = get_pid_info($pid);
            acfslib::lib_inform_print(9136,"PID %s could not be killed.",$pid);
            report_pid_info(%info);
        }
      }
      else
      {
        # print "prog_name $prog_name location $prog_directory pid $pid\n";
        $descriptor_list .= "$pid ";
      }
    }
  }

  if ($action)
  {
    return $retval;
  }
  else
  {
    return $descriptor_list;
  }
} # end lib_osds_mountpoint_descriptors

# lib_osds_mount
#
# Mount the specified file system
#
sub lib_osds_mount
{
  my ($device, $mount_point, $options) = @_;
  my ($result);
  my $nlsLangSave                      = $ENV{NLS_LANG};
  my $status                           = USM_FAIL;

  # We are looking for the English word, "Successfully" to determine if
  # the mount worked.

  $ENV{NLS_LANG} = "english";

  # We ignore the mount options since there are only 3 and none apply
  #   /a - mount all volumes in the registry - nope, don't want that
  #   /h - print help info - nope, don't want that
  #   /v - verbose mode - nope, don't want that

  open (MOUNT, "$ORACLE_HOME/bin/acfsmountvol $mount_point $device |");
  while ($result = <MOUNT>)
  {
    if ($result =~ /Successfully/)
    {
      $status = USM_SUCCESS;
      last;
    }
    # debug
    # print "$result\n";
  }
  close(MOUNT);

  # restore native language setting
  $ENV{NLS_LANG} = $nlsLangSave;

  return $status;

} # end lib_osds_mount

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

# lib_osds_unload_driver()
#
# ACFS is a registered file system and needs to be de-registered before
# the driver can be stopped. ofsutil detach does this.
#
sub lib_osds_unload_driver
{
  my ($driver, $install_files_loc) = @_;
  my ($detach_cmd);

  if ($driver eq $DRIVER_COMPONENTS[OFS_IDX])
  {
    my ($retval);

    # ACFS driver
    #
    # We look for acfsutil in the installed location first. If that fails, we
    # use the acfsutil in the install source location(s). This can either be
    # in the shiphome or, if we are in a development environment, the view or
    # \usm\bin. We run with the "force" detach option so that we won't abort
    # in case there are version differences between acfsutil and the
    # installed ACFS driver)
    #
    # NOTE: acfsroot.pl may change $ACFSUTIL, declared above, removing the .exe
    if((-e $ACFSUTIL) || (-e "$ACFSUTIL.exe"))
    {
      $detach_cmd = "$ACFSUTIL detach /f";
    }
    elsif(-e "/usm/bin/acfsutil.exe")
    {
       $detach_cmd = "/usm/bin/acfsutil.exe detach /f";
    }
    elsif(defined($install_files_loc) &&
         (-e $install_files_loc . "/cmds/bin/acfsutil.exe"))
    {
       $detach_cmd = $install_files_loc . "/cmds/bin/acfsutil.exe detach /f";
    }

    if (!defined($detach_cmd))
    {
      acfslib::lib_error_print(9123, "'%s' command not found", "acfsutil");
      return USM_FAIL;
    }

    $retval = system ($detach_cmd);
    if ($retval)
    {
      my ($driver) = "ACFS";
      acfslib::lib_error_print(9124, "%s driver failed to detach from the " .
                                     "system driver stack.", $driver);
      return USM_FAIL;
    }
  }

  return common_driver_load_unload("stop", $driver);
} # end lib_osds_unload_driver

# lib_osds_unmount
#
# unmount the specified file system
#
# TODO - right now we only handle OFS file systems
#
sub lib_osds_unmount
{
  my ($mountpoint) = @_;
  my ($result);
  my ($ret_val) = USM_SUCCESS;

  # the failure case here must be tested.
  # only the "does it work" case has been tested.
  # TODO: test this failure case.

  # This used to have a 2>&1 in it.
  # But CRS on Windows doesn't seem to like that format.
  # We don't check the return code of dismount for anything. To
  # verify that the FS is actually unmounted, go looking for the
  # mount.  If it's still there the unmount failed.
  system("$ORACLE_HOME/bin/acfsdismount $mountpoint");
  if (acfslib::lib_is_mounted($mountpoint) )
  {
     # we got an error if we got here
     $ret_val = USM_FAIL;
  }
  return $ret_val;
} # end lib_osds_unmount

# lib_osds_usm_supported.
#
# The fact that we got here means that there is some support for
# this platform. However, perhaps not all releases are supported.
# We make that determination here.
#
# return true or false
#
sub lib_osds_usm_supported
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
  # Windows 10             2     10       0         1
  # Windows Server 2016    2     10       0         3

  # GetOSVersion was deprecated in Windows 8.1. That means that while you can
  # still call the APIs, Your app does not specifically target Windows 8.1,
  # You will get Windows 8 versioning (6.2.0.0).
  # Even for Windows 2016 or 10, you will get 6.2.0

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
                     "The '%s' machine architecture not supported.", $ARCH);
    return 0;
  }

  # parse GetOSVersion() results - see subroutine header
  if (($id eq 2) && ($major == 6) && ($minor == 2) && ($prod_type == 3))
  {
    # We'll do a extra validation to determine if this Windows Server 2012 or
    # Windows Server 2012 R2 or Windows Server 2016
    my $wmi = Win32::OLE->GetObject("WinMgmts://./root/cimv2");
    my $version;
    if (defined($wmi))
    {
      my $list = $wmi->InstancesOf("Win32_OperatingSystem");
      for my $item ( Win32::OLE::in $list ) {
        $version = $item->{Caption};
      }
    }
    # If wmi is not available, we'll try with systeminfo
    else
    {
      my ($OSNAME) = `systeminfo | findstr /B /C:"OS Name"`;
      chomp($OSNAME);
      $version = acfslib::trim(substr($OSNAME, index($OSNAME, ':') + 1));
    }
    acfslib::lib_trace( 9999, "Windows OS Version: $version");

    if (defined($version) &&
        ($version =~ /2012/) &&
        ($version =~ /R2/))
    {
      $OS_TYPE = "Windows Server 2012 R2";
      $OS_SUBDIR = "2012R2";
    }
    elsif (defined($version) &&
           $version =~ /2016/)
    {
      $OS_TYPE = "Windows 2016";
      $OS_SUBDIR = "2016";
    }
    elsif (defined($version) &&
        $version =~ /2012/)
    {
      $OS_TYPE = "Windows Server 2012";
      $OS_SUBDIR = "2012";
    }
    elsif (defined($version) &&
        $version =~ /2019/)
    {
      $OS_TYPE = "Windows Server 2019";
      $OS_SUBDIR = "2019";
    }
    # If $version is not defined, we cannot assign OS_TYPE and OS_SUBDIR
    if ((!$version) && (not defined($ENV{_ORA_USM_NOT_SUPPORTED})))
    {
      acfslib::lib_error_print(9140,
                               "Unable to determine the correct drivers for " .
                               "this version of Windows: " .
                               "ID:%s Major:%s Minor:%s Product Type:%s",
                               $id, $major, $minor, $prod_type);
      acfslib::lib_error_print(9194, "unable to query the WMI service " .
                                     "to identify the Windows OS Version");
      return 0;
    }
  }
  # Just in case
  elsif (($id eq 2) && ($major == 6) && ($minor == 3) && ($prod_type == 3))
  {
    $OS_TYPE = "Windows Server 2012 R2";
    $OS_SUBDIR = "2012R2";
  }
  elsif (($id eq 2) && ($major == 6) && ($minor == 4) && ($prod_type == 3))
  {
    $OS_TYPE = "Windows Server 2016";
    $OS_SUBDIR = "2016";
  }
  elsif (($id eq 2) && ($major == 10) && ($minor == 0) && ($prod_type == 3))
  {
    $OS_TYPE = "Windows Server 2016";
    $OS_SUBDIR = "2016";
  }

  $configuration{unamea} = $UNAME_A;
  $configuration{env_var} = (defined($ENV{_ORA_USM_NOT_SUPPORTED})? "yes" : "no");

  # The above platforms are all that we support for now.
  if ((defined($OS_TYPE)) && (not defined($ENV{_ORA_USM_NOT_SUPPORTED})))
  {
    $configuration{version} = $OS_TYPE;
    return 1;
  }
  elsif ((defined($OS_TYPE)) && (defined($ENV{_ORA_USM_NOT_SUPPORTED})))
  {
    acfslib::lib_error_print(9125,
                            "ADVM/ACFS is not supported on this OS: '%s'",
                            $OS_TYPE . " (via ENV VARIABLE)");
    return 0;
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
  elsif (($id eq 2) && ($major == 6) && ($minor == 0) && ($prod_type == 3))
  {
    # There is no Product called "Windows Server 2008 R1"
    # W2008 Server with SP1/SP2 is based on 6.0 kernel
    $OS_TYPE = "Windows Server 2008";
  }
  elsif (($id eq 2) && ($major == 6) && ($minor == 1) && ($prod_type == 3))
  {
    # Kernel based on 6.1 version
    $OS_TYPE = "Windows Server 2008 R2";
  }
  elsif (($id eq 2) && ($major == 6) && ($minor == 0) && ($prod_type == 1))
  {
    $OS_TYPE = "Windows Vista";
  }
  elsif (($id eq 2) && ($major == 6) && ($minor == 1) && ($prod_type == 1))
  {
    $OS_TYPE = "Windows 7";
  }
  elsif (($id eq 2) && ($major == 6) && ($minor == 2)) 
  #&& ($prod_type == 1)) Not check Product Type. It could be 2019 Server
  {
    # We'll do a extra validation to determine if this Windows 8, 8.1 or 10
    my $wmi = Win32::OLE->GetObject("WinMgmts://./root/cimv2");
    my $version;
    my $list = $wmi->InstancesOf("Win32_OperatingSystem");
    if (defined($wmi))
    {
      for my $item ( Win32::OLE::in $list ) {
        $version = $item->{Caption};
      }
    }
    # If wmi is not available, we'll try with systeminfo
    else
    {
      my ($OSNAME) = `systeminfo | findstr /B /C:"OS Name"`;
      chomp($OSNAME);
      $version = acfslib::trim(substr($OSNAME, index($OSNAME, ':') + 1));
    }
    acfslib::lib_trace( 9999, "Windows OS Version: $version");

    if (defined($version) &&
        $version =~ /8.1/)
    {
      $OS_TYPE = "Windows 8.1";
    }
    elsif (defined($version) &&
           $version =~ /8/)
    {
      $OS_TYPE = "Windows 8";
    }
    elsif (defined($version) &&
           $version =~ /10/)
    {
      $OS_TYPE = "Windows 10";
    }
    # Windows 2019
    elsif (defined($version) &&
           $version =~ /2019/)
    {
      $OS_TYPE = "Windows Server 2019";
    }
    # If $version is not defined, we cannot assign OS_TYPE
    if ((!$version) && (not defined($ENV{_ORA_USM_NOT_SUPPORTED})))
    {
      acfslib::lib_error_print(9140,
                              "Unable to determine the correct drivers for " .
                              "this version of Windows: " .
                              "ID:%s Major:%s Minor:%s Product Type:%s",
                              $id, $major, $minor, $prod_type);
      acfslib::lib_error_print(9194, "unable to query the WMI service " .
                                     "to identify the Windows OS Version");
    }
  }
  elsif (($id eq 2) && ($major == 6) && ($minor == 3) && ($prod_type == 1))
  {
    $OS_TYPE = "Windows 8.1";
  }
  elsif (($id eq 2) && ($major == 6) && ($minor == 4) && ($prod_type == 1))
  {
    $OS_TYPE = "Windows 10";
  }
  elsif (($id eq 2) && ($major == 10) && ($minor == 0) && ($prod_type == 1))
  {
    $OS_TYPE = "Windows 10";
  }

  if (defined($OS_TYPE))
  {
    acfslib::lib_error_print(9125,
                            "ADVM/ACFS is not supported on this OS: '%s'",
                            $OS_TYPE);
  }
  else
  {
    acfslib::lib_error_print(9125,
                            "ADVM/ACFS is not supported on this OS: '%s'",
                            "unrecognized OS");
    acfslib::lib_error_print(9140,
                            "Unable to determine the correct drivers for " .
                            "this version of Windows: " .
                            "ID:%s Major:%s Minor:%s Product Type:%s",
                            $id, $major, $minor, $prod_type);
  }

  return 0;

} # end lib_osds_usm_supported

# lib_osds_verify_usm_devices
#
sub lib_osds_verify_usm_devices
{
  my ($driver);                   # USM driver currently being examined
  my ($num_drivers_loaded) = 0;   # as the name implies
  my ($retval) = 0;               # returned to the caller - assume no drivers
  my ($file_handle);

  # make sure all drivers are loaded (running in Windows speak)
  foreach $driver ($DRIVER_COMPONENTS[OKS_IDX],
                   $DRIVER_COMPONENTS[AVD_IDX], $DRIVER_COMPONENTS[OFS_IDX])
  {
    acfslib::lib_inform_print(9157, "Detecting driver '%s'.", $driver);
    $num_drivers_loaded += query("running", $driver);
  }

  if ($num_drivers_loaded != 3)
  {
    acfslib::lib_error_print(9127,
                                "Not all ADVM/ACFS drivers have been loaded.");
    return USM_FAIL;
  }

  if (!lib_osds_control_devices_accessible())
  {
    # lib_osds_control_devices_accessible will print specific errors
    return USM_FAIL;
  }

  # start the persistent log
  # We only warn if persistent logging can't be started.
  `$ACFSUTIL plogconfig /d`;
  if ($?)
  {
    acfslib::lib_inform_print(9225, "Failed to start OKS persistent logging.");
  }

  return USM_SUCCESS;
} #end lib_osds_verify_usm_devices

# lib_osds_validate_asmadmin_group
#
# Make sure that the $asmadmin group name actually exists.
#
sub lib_osds_validate_asmadmin_group
{
  my ($asmadmin) = @_;
  my ($retcode) = USM_SUCCESS;

  acfslib::lib_trace(9176, "Entering '%s'", "va admin group");

  # No /etc/group file etc. on Windows, just return USM_SUCCESS.
  acfslib::lib_trace(9178, "Return code = %s", $retcode);
  acfslib::lib_trace(9177, "Return from '%s'",  "va admin group");

  return $retcode;
} #end lib_osds_validate_asmadmin_group

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

# get_pid_info
#
# Collect and return information, for a given PID.
# Returns an undefined %pid_hash if the PID is not found.
#
sub get_pid_info
{
  my ($pid) = @_;   # target PID
  my ($task_info);  # output line from the tasklist / command
  my (%pid_hash);   # return: hashed output from the tasklist command for $pid

  # This used to have a 2>&1 in it.
  # TODO: Figure a way to check for the error of tasklist here.
  #
  # This was removed since CRS on Windows seems to disallow the redirection.
  open TL, "tasklist /v |"
          or warn ("Failed to run 'tasklist /v': $!"), return %pid_hash;
  # tasklist /v format is:
  # COMMAND PID SESSION SESSION# MEM K STATUS USER -- varies (see below) --
  #   0      1     2       3      4  5   6     7     8    9     10
  while ($task_info = <TL>)
  {
    my (@array) = split /\s+/, $task_info;
    %pid_hash = (
      COMMAND => $array[0],
      PID     => $array[1],
      SESSION => $array[2],
      SESS_NUM=> $array[3],
      MEM     => $array[4] . $array[5],
      STATUS  => $array[6],
    );

    if ($array[9] eq "SERVICE")
    {
      # e.g., "NT AUTHORITY\NETWORK SERVICE"
      $pid_hash{'USER'} = $array[7] . " $array[8]" . " $array[9]";
      $pid_hash{'CPU_TIME'} = $array[10];
      $pid_hash{'TITLE'} = $array[11];
    }
    elsif ($array[8] =~ "SYSTEM")
    {
      # e.g., "NT AUTHORITY\SYSTEM"
      $pid_hash{'USER'} =  $array[7] . " $array[8]";
      $pid_hash{'CPU_TIME'} = $array[9];
      $pid_hash{'TITLE'} = $array[10];
    }
    else
    {
      # e.g., "FOODOMAIN\user"
      $pid_hash{'USER'} = $array[7];
      $pid_hash{'CPU_TIME'} = $array[8];
      $pid_hash{'TITLE'} = $array[9];
    }


    if ($pid eq $pid_hash{'PID'})
    {
      close(TL);
      return %pid_hash;
    }
  }

  # Target PID not found.
  close (TL);
  undef %pid_hash;
  return %pid_hash;
} # end get_pid_info

sub report_pid_info
{
  my (%info) = @_;
  acfslib::lib_inform_print(9141, "         COMMAND %s", $info{'COMMAND'});
  acfslib::lib_inform_print(9142, "         STATUS %s", $info{'STATUS'});
  acfslib::lib_inform_print(9143, "         USER %s", $info{'USER'});
  acfslib::lib_inform_print(9144, "         CPU_TIME %s", $info{'CPU_TIME'});
  acfslib::lib_inform_print(9145, "         MEM %s", $info{'MEM'});
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
    if ((query("running", $driver)) ||
        (Win32::Service::StartService("", $driver)))
    {
      # driver already running or was started
      $ret = USM_SUCCESS;
    }
  }
  else # ($action eq "stop")
  {
    $driverState = query ( "query", $driver );

    if ( $driverState == SERVICE_RUNNING )
    {
        if ( ! Win32::Service::StopService("", $driver) )
        {
          acfslib::lib_error_print(9456,
             "An attempt to stop the driver %s failed.", $driver);
          return USM_FAIL;
        }
    }

    if ( $acfslib::CRS_ACTION eq "clean" )
    {
        # For clean we fire stop requests at the drivers in rapid
        # succession without regard for any STOP_PENDING states that
        # might be encountered.
        return USM_SUCCESS;
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
        acfslib::lib_inform_print(9291,
          "Waiting for the Windows 'sc stop %s' command to complete.",
          $driver);
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

# Returns 1 if both files are the same, either through a hard link or through
# a symbolic link path. Windows specific.
use File::stat;
sub lib_osds_are_same_file
{
  my ($source, $target) = @_;
  my ($s_sb, $t_sb);
  my $extsource;
  my $exttarget;
  my $link;

  if( -e $source)
  {
    $extsource = (fileparse( $source, qr/\.[^.]*/))[2];
    if( $extsource eq ".lnk")
    {
      $link = new Win32::Shortcut;
      $link->Load( $source);
      $source = $link->Path();
    }
  }

  if( -e $target)
  {
    $exttarget = (fileparse( $target, qr/\.[^.]*/))[2];
    if( $exttarget eq ".lnk")
    {
      $link = new Win32::Shortcut;
      $link->Load( $target);
      $target = $link->Path();
    }
  }

  if ( -e $source && -e $target ){
    $t_sb = stat($target);
    $s_sb = stat($source);

    if ( $t_sb->dev==$s_sb->dev && $t_sb->ino==$s_sb->ino ){
      return 1;
    }
  }

  return 0;
}

# lib_osds_is_local_container
#
# Linux and Solaris only for now

sub lib_osds_is_local_container
{
    return 0;
}

# This function will modify the values of the acfslib::acfsr hash.
# The first value is 'True' when ACFS Remote is supported, 'False' otherwise.
# In order to determine if it is supported we
#   - Retrieve the passed argument. It will either be "DOMAINSERVICES"
#     or "MEMBER".
#   - Depending on cluster class, determine if the current OS is supported.
#   If it is supported, other values will be pushed into the array
# Is ISCSI supported? 'True' or 'False'.
sub lib_osds_acfs_remote_supported
{
    my $cluster_class = shift;

    if($cluster_class eq 'MEMBER')
    {
        $acfslib::acfsr{'ACFS Remote'} = 'False';
=head
        # Enable this and remove the above push  when we support this platform
        # There might be more checks needed before saying 'True'
        $acfslib::acfsr{'ACFS Remote'} = 'True';
=cut
    }
    elsif($cluster_class eq 'DOMAINSERVICES')
    {
        $acfslib::acfsr{'ACFS Remote'} = 'False';
=head
        # Enable this and remove the above push  when we support this platform
        # There might be more checks needed before saying 'True'
        $acfslib::acfsr{'ACFS Remote'} = 'True';
=cut
    }
    else
    {
        $acfslib::acfsr{'ACFS Remote'} = 'False';
    }
    # Check ISCSI support
    # Allan Graves (located in office 4223) told me we can assume ISCSI
    # is supported in all platforms.
    $acfslib::acfsr{'iSCSI'} = 'True';
=head2
    # Check if this is an ODA DomU
    if(isODADomu())
    {
        # Xen Blkfrnt support
        $acfslib::acfsr{'ACFS Remote'} = 'False';
    }
=cut
}

# This function will modify the values of the acfslib::acfsr hash.
# The first value is 'True' when ACFS Remote is installed, 'False' otherwise.
# In order to determine if it is installed we need to look for
# /etc/modprobe.d/oracleadvm.conf (Linux location, this may vary in other OS)
#   If found, read it and look for asm_acfsr_mode option
#       As of 2/3/16 modes are:
#           DOMAINSERVICES = 1
#           MEMBER         = 2
#       The list can be found in acfsroot.pl.
#       Perhaps I should move that list somewhere else?
#   Any of those modes mean 'installed'. Any other value (or a lack of one)
#   means not installed.
#   If it is supported, other values will be pushed into the array
# Is ISCSI setup? 'True' or 'False'.
sub lib_osds_acfs_remote_installed
{

    my $mode = 0;
    my $conf_location = "/etc/modprobe.d/oracleadvm.conf";
    my $fh;
    my $line;
    my $cluster_class;

    if(-e $conf_location)
    {
        open ($fh,"<$conf_location") or die "$!";
        while($line = <$fh>)
        {
            if($line =~ /asm_acfsr_mode=(\d)/)
            {
                $mode = $1;
            }
        }
        close $fh;
    }

# Change these to true when we support ACFS Remote on this platform.
# There might be other checks needed beforehand.
    if($cluster_class eq 'MEMBER' && $mode eq 2)
    {
        $acfslib::acfsr{'ACFS Remote'} = 'False';
    }
    elsif($cluster_class eq 'DOMAINSERVICES' && $mode eq 1)
    {
        $acfslib::acfsr{'ACFS Remote'} = 'False';
    }
    else
    {
        $acfslib::acfsr{'ACFS Remote'} = 'False';
    }

    $acfslib::acfsr{'iSCSI'} = 'False';

}

# This function will modify the values of the acfslib::acfsr hash.
# The first value is 'True' when ACFS Remote is loaded, 'False' otherwise.
# Is ISCSI setup and running? 'True' or 'False'.
sub lib_osds_acfs_remote_loaded
{
    $acfslib::acfsr{'ACFS Remote'} = 'False';
# Hint: sc query iscsi should show the state of the service
    $acfslib::acfsr{'iSCSI'} = 'False';
}
# Not implemented in this platform yet.
sub lib_osds_acfsr_configure
{
    return 0;
}

# Get the Oracle Home driver path
sub lib_osds_get_home_driver_path
{
  my $type = $OS_SUBDIR;
  my ($base, $ARCH) = @_;
  chomp ($type);
  chomp ($ARCH);
  $base .= "/Windows/$type/$ARCH/bin";
  # Convert path into something findstr understands
  $base =~ s/\//\\\\/g;
  $base =~ s/:/:\\\\/g;

  return $base;
}

sub lib_osds_get_drivers_version
{
  my %drvdata;           # (BuildNo,Version,BugList,BugHash,KERNELVERS)
  my @array;
  my $str;
  my $kernelvers;
  my @drvpath;           # (/lib/modules,ORACLE_HOME/install...)
  my @drvattr  = ("USM BUILD LABEL:","TXN BUGS:","TXN BUGS HASH:",
                  "USM VERSION:", "USM VERSION FULL:");
  my $type     = "Installed";
  my $driver;
  my $prod;

  if ($acfslib::USM_CURRENT_PROD eq "prod_afd")
  {
    $prod = "orclafdvol.sys";
  }
  else
  {
    $prod = "oracleoks.sys";
  }

  # $OS_TYPE (e.g., "Windows Server 2003")
  lib_osds_usm_supported();
  $kernelvers = $ARCH;
  $drvdata{"Installed"}{"KERNVERS"}= "$OS_TYPE ($kernelvers)";
  $drvdata{"OS"}{"KERNVERS"}= "$kernelvers";

  # Loaded drivers location
  $drvpath[0] = "$SYSTEM_ROOT/system32/drivers/$prod";
  # Oracle home drivers location
  $drvpath[1] = $ORACLE_HOME."/usm/install";
  $drvpath[1] = lib_osds_get_home_driver_path ($drvpath[1],
                $kernelvers);
  # convert driver name format into something findstr understands
  $drvpath[0]=~ s/\//\\\\/g;  $drvpath[0]=~ s/:/:\\\\/g;
  $drvpath[1] =~ s/\//\\\\/g; $drvpath[1] =~ s/:/:\\\\/g;
  acfslib::lib_uncompress_all_driver_files($drvpath[1]);
  # Include driver to oracle_home driver path
  $drvpath[1] = $drvpath[1] . "\\" . $prod;

  foreach $driver (@drvpath)
  {
    if (! -e $driver)
    {
      next;
    }
    foreach (@drvattr)
    {
      # The usm_label_info[] global contains:
      open (FIND, "findstr /C:\"$_\" $driver |");
      $str = <FIND>;
      close(FIND);
      if ($_ eq "USM BUILD LABEL:" && $str =~ /USM BUILD LABEL: (\S+)/)
      {
        # USM BUILD LABEL: USM_MAIN_WINDOWS.X64_100506
        $str = $1;
        # Get the first 50 characters
        $str = sprintf("%.50s", $str);
        # So, USM_MAIN_NT_090112 becomes 090112.
        @array = split (/_/, $str);
        $str = $array[3];
        $drvdata{$type}{"BuildNo"} = sprintf("%.6s", $str);
      }
      elsif ($_ eq "TXN BUGS:" && $str =~ /TXN BUGS: (\S+)/)
      {
	# Expected strings
	# usm_ade_label_info_make_header.pl: TXN BUGS: 1345543,14579183
	# usm_ade_label_info_make_header.pl: TXN BUGS:
        $str = $1;
        # Get the first 50 characters
        $str = sprintf("%.50s", $str);
	$drvdata{$type}{"BugList"} = (split("\s+",$str))[0];
        # 1345543,14579183 or BUGS:
	chomp ($drvdata{$type}{"BugList"});
        if ($drvdata{$type}{"BugList"} !~ /^\d+/)
	{
          $drvdata{$type}{"BugList"} = "NoTransactionInformation";
	}
      }
      elsif ($_ eq "TXN BUGS HASH:" && $str =~ /TXN BUGS HASH: (\d+)/)
      {
	# usm_ade_label_info_make_header.pl: TXN BUGS HASH: 1345579183
        $str = $1;
        # Get the first 50 characters
        $str = sprintf("%.50s", $str);
        $drvdata{$type}{"BugHash"} = $str;
	#1345579183
	chomp ($drvdata{$type}{"BugHash"});
      }
      elsif ($_ eq "USM VERSION:" && $str =~ /USM VERSION: (\S+)/)
      {
        $str = $1;
        # Get the first 10 characters
        $str = sprintf("%.10s", $str);
        $drvdata{$type}{"Version"} = $str;
	chomp ($drvdata{$type}{"Version"});
        #usm_ade_label_info_make_header.pl: USM VERSION: 18.0.0.0.0
      }
      elsif ($_ eq "USM VERSION FULL:" && $str =~ /USM VERSION FULL: (\S+)/)
      {
        #usm_ade_label_info_make_header.pl: USM VERSION FULL: 18.1.0.0.0
        $str = $1;
        # Get the first 10 characters
        $str = sprintf("%.10s", $str);
        $drvdata{$type}{"VSNFULL"} = $str;
	chomp ($drvdata{$type}{"VSNFULL"});
      }
    }
    $type = "Available";
  }

  # Return an undefined variable if we don't have all of our info.
  # That signals failure to the caller.
  return undef if (!defined($drvdata{"Installed"}{"KERNVERS"})   ||
                   !defined($drvdata{"Installed"}{"BuildNo"})    ||
                   !defined($drvdata{"Installed"}{"Version"})    ||
                   !defined($drvdata{"Installed"}{"BugList"})    ||
                   !defined($drvdata{"Installed"}{"BugHash"})    ||
                   !defined($drvdata{"Installed"}{"VSNFULL"})    ||
                   !defined($drvdata{"Available"}{"BuildNo"})    ||
                   !defined($drvdata{"Available"}{"Version"})    ||
                   !defined($drvdata{"Available"}{"BugList"})    ||
                   !defined($drvdata{"Available"}{"BugHash"})    ||
                   !defined($drvdata{"OS"}{"KERNVERS"})          ||
                   !defined($drvdata{"Available"}{"VSNFULL"}));

  return (\%drvdata);
}

# Check if configuration machine is ready to install and load ACFS/ADVM drivers
# return true or false
sub lib_osds_check_config()
{
  if ( $SECURE_BOOT_STATE eq "0x00000001" )
  {
    acfslib::lib_inform_print(9461, "ADVM/ACFS is not supported on this Secure Boot configuration.");
    return 0;
  }
  return 1;
}

# Check if machine supports ACFS/ADVM drivers
# return true or false
sub lib_osds_check_kernel()
{
  return 1;
}

# sub lib_osds_acfs_reg_key
#
# Bug 13636598 lib_osds_acfs_reg_key
# Get a Windows registry key
#
# return a Windows registry key value
sub lib_osds_acfs_reg_key
{
  # Following lines for reference
  #
  # SYSTEM_ROOT:
  #   HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRoot
  # PRODUCTNAME:
  #   HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProductName
  # ORACLE_HOME:
  #   HKLM\SOFTWARE\Oracle\olr\crs_home

  my ( $str )      = $_[0];
  my ( $tmp )      = "";
  my ( $path_key ) = "";
  my ( $value )    = "";
  my ( $key )      = "";
  my ( $HKLM )     = "HKEY_LOCAL_MACHINE";

  # ENV variables if returned value is empty from
  # sub lib_osds_acfs_reg_key_value
  my ( $ORACLE_HOME_ENV)  = $ENV{ORACLE_HOME};
  my ( $SYSTEM_ROOT_ENV)  = $ENV{SYSTEMROOT};
  my ( $SYSTEM_DRIVE_ENV) = $ENV{SYSTEMDRIVE};

  # crs_home is the same directory for the ENV{ORACLE_HOME} variable
  # it should be the same than the KEY_OraGI##Home# key
  # We are doing this since the customer could have other keys for ORACLE_HOME
  if ( $str =~ /ORACLE_HOME/ )
  {
    $path_key = "$HKLM\\SOFTWARE\\Oracle\\olr\\";
    $key      = "crs_home";
    $value = lib_osds_acfs_reg_key_value($path_key, $key);

    if (!length $value)
    {
      # We're in a development environment, we'll use that $ORACLE_HOME.
      # $value must be empty in ADE
      $value = $ORACLE_HOME_ENV;
    }
  }
  elsif( ($str =~ /SYSTEM_ROOT/) || ($str =~ /SYSTEM_DRIVE/) )
  {
    $path_key = "$HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\";
    $key      = "SystemRoot";
    $value = lib_osds_acfs_reg_key_value($path_key, $key);

    if (!length $value)
    {
      $value = $SYSTEM_ROOT_ENV;
    }

    if ($str =~ /SYSTEM_DRIVE/)
    {
      # Split Drive letter from /SYSTEMROOT/ which should be one like C:
      # Split will create an array of strings, from a given string.
      # Here we are asking for '\' as string delimiter for the new substrings,
      # the '2' is to limit the array size to 2 strings. e.g. "C:\Windows"
      # would give me ['C:', 'Windows'], another example "C:\Foo\Bar\Baz"
      # would give me ['C:', 'Foo Bar Baz'].
      # Since we only care for the first element of the array, we are limiting
      # it to 2 elements. If we didn't limit it to 2, this the last example
      # would return ['C:', 'Foo', 'Bar', 'Baz']
      my @words = split(/\\/, $value, 2);
      $value = $words[0];
    }
  }
  elsif( $str =~ /PRODUCTNAME/ )
  {
    # ProductName cannot be null or empty since Windows is the owner
    $path_key = "$HKLM\\SOFTWARE\\Microsoft\\Windows NT\\CurrentVersion\\";
    $key      = "ProductName";
    $value = lib_osds_acfs_reg_key_value($path_key, $key);
  }
  elsif( $str =~ /SECURE_BOOT_STATE/ )
  {
    # Avoiding srg install failures
    if (!defined($ENV{ADE_VIEW_ROOT}))
    {
      $path_key = "$HKLM\\SYSTEM\\CurrentControlSet\\Control\\SecureBoot\\State\\";
      $key      = "UEFISecureBootEnabled";
      $value = lib_osds_acfs_reg_key_value($path_key, $key);
    }
  }

  return $value;
} # end sub lib_osds_acfs_reg_key

 # sub lib_osds_acfs_reg_key_value
 #
 # Bug 13636598 lib_osds_acfs_reg_key
 # Get value for a Windows registry key or subkey
 #
 # return a Windows registry key value
 sub lib_osds_acfs_reg_key_value
 {
   my ( $key, $val ) = @_;
   my ( $key_val )   = "";

   # Try to read the value, if any error trace the issue displaying they
   # registry key, it should be fixed manually by the Admin.
   $key_val = $Win32::TieRegistry::Registry->{"$key" . "$val"};

   return $key_val;
 } # end sub lib_osds_acfs_reg_key_value

#Uncompress driver files in Windows
sub lib_osds_uncompress_driver_files
{
  # Empty function, Windows is not compressed
}

1;
# vim:ts=2:expandtab
