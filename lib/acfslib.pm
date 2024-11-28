#
# osdsacfslib.pm
#
# Copyright (c) 2007, 2021, Oracle and/or its affiliates. 
#
#
#    NAME
#      acfslib.pm - Common (non platform specific) functions used by
#                   the install/runtime scripts.
#
#    DESCRIPTION
#      Purpose
#          See above.
#
#    NOTES
#      All user visible output should be done in the common code.
#      this will ensure a consistent look and feel across all platforms.
#
#

use strict;
use Cwd;
use Cwd qw(chdir);
use Cwd 'abs_path';
use File::Basename;
use Net::Domain qw(hostname);
package acfslib;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
                 lib_am_root
                 lib_asm_connect
                 lib_asm_disconnect
                 lib_asm_enable_volume
                 lib_asm_disable_volume
                 lib_asm_mount_diskgroup
                 lib_check_drivers_installed
                 lib_check_any_driver_installed
                 lib_check_uninstall_required
                 lib_check_drivers_loaded
                 lib_count_drivers_loaded
                 lib_check_loaded_drivers_mismatch
                 lib_check_in_progress
                 lib_control_devices_accessible
                 lib_create_mount_point
                 lib_device_from_mountpoint
                 lib_end_check_in_progress
                 lib_error_print
                 lib_error_print_noalert
                 lib_get_advm_mounts
                 lib_get_asm_admin_name
                 lib_get_asm_mode
                 lib_get_asm_cluster_mode
                 lib_get_asm_user
                 lib_get_drive_info
                 lib_inform_print
                 lib_inform_print_noalert
                 lib_verbose_print
                 lib_verbose_print_noalert
                 lib_is_local_container
                 lib_is_mounted
                 lib_is_mount_available
                 lib_load_usm_drivers
                 lib_mount
                 lib_mountpoint_descriptors
                 lib_recover_stale_mounts
                 lib_run_as_user
                 lib_run_func
                 lib_trace
                 lib_unload_usm_drivers
                 lib_unmount
                 lib_usm_supported
                 lib_verify_usm_devices
                 lib_is_abs_path
                 lib_print_cmd_header
                 lib_get_oracle_home
                 lib_oracle_drivers_conf
                 lib_get_drivers_version
                 lib_set_crsctl_actions
                 trim
                 $COMMAND
                 $SILENT
                 $VERBOSE
                 $_ORA_USM_TRACE_ENABLED
                 $_ORA_USM_TRACE_LEVEL
                 $ACFSUTIL
                 $USM_CURRENT_PROD
                 $_ORACLE_HOME
                 $CLSECHO
                 AVD_IDX
                 OFS_IDX
                 OKS_IDX
                 OPT_CHR
                 CHECK_IN_PROGRESS_NO
                 CHECK_IN_PROGRESS_YES
                 CHECK_IN_PROGRESS_TIMEOUT
                 CLSAGFW_AE_SUCCESS
                 CLSAGFW_AE_FAIL
                 CLSAGFW_ONLINE
                 CLSAGFW_UNPLANNED_OFFLINE
                 CLSAGFW_PLANNED_OFFLINE
                 CLSAGFW_UNKNOWN
                 CLSAGFW_PARTIAL
                 CLSAGFW_FAILED
                 CRS_ACTION
                 USM_FAIL
                 USM_TRANSIENT_FAIL
                 USM_SUCCESS
                 USM_SUPPORTED
                 USM_NOT_SUPPORTED
                 USM_REBOOT_RECOMMENDED
                 USM_PROD_ACFS
                 USM_PROD_OKA
                 USM_PROD_AFD
                 USM_PROD_OLFS
                 add_usm_drivers_resource
                 usm_resource_exists
                 modify_usm_drivers_resource
                 delete_usm_drivers_resource
                 start_usm_drivers_resource
                 md5compare
                 lib_are_same_file
                 lib_is_number
                 isODA
                 isODADomu
                 isOPCDom0
                 isOPCDomu
                 isDomainClass
                 isMemberClass
                 lib_acfs_remote_supported
                 lib_acfs_remote_installed
                 lib_acfs_remote_loaded
                 lib_uncompress_all_driver_files
                 lib_chmod
                );

use DBI;
use osds_acfslib;
use File::Spec::Functions;
use File::Path;
use Digest::MD5 qw(md5 md5_hex md5_base64);
use usmvsn;
use Config;

our ($SILENT) = 0;                       # input option (-s)
our ($VERBOSE) = 0;                      # input option (-v)
our ($_ORACLE_HOME) = "";
our ($_LIB_VERSION) = "";
our ($_ORA_USM_TRACE_ENABLED) = 0;
our ($_ORA_USM_TRACE_LEVEL) = 0;
our ($COMMAND) = "No Command Specified";                     # currently executing command
our (%acfsr) = ( 'ACFS Remote' => 'False',
                 'iSCSI'       => 'False',
    );

my ($ADE_VIEW_ROOT) = $ENV{ADE_VIEW_ROOT};
my ($ORACLE_HOME) = $ENV{ORACLE_HOME};
my ($ORA_CRS_HOME) = $ENV{ORA_CRS_HOME};
my ($CRS) = $ENV{_ORA_AGENT_ACTION};     # defined if invoked via CRS
my ($CACHED_ASMADMIN);                   # avoid calling osdbagrp -a repeatedly

our ($CLSECHO);                           # Just used for check if the file exists
if ($Config{osname} =~ /Win/)
{
  # This variable is used for check if clsecho binary exists.
  # If you check, I'm not adding the exe suffix to CLSECHO_ACFS or
  # $CLSECHO_OKA. These variables are fine, you can run the command
  # in Windows environment, even when you don't include .exe suffix.
  # But if you want to check if the file exists (-e $CLSECHO), you
  # will need the complete name.
  ($CLSECHO) = catfile($ORA_CRS_HOME, "bin", "clsecho.exe");
}
else
{
  ($CLSECHO) = catfile($ORA_CRS_HOME, "bin", "clsecho");
}

# '-l' = write to CRS alert log. Look at common_print()
my ($CLSECHO_ACFS) = catfile($ORA_CRS_HOME, "bin", "clsecho") . " -p usm -f acfs";

# if the message to print is from OKA
my ($CLSECHO_OKA) = catfile($ORA_CRS_HOME, "bin", "clsecho") . " -p usm -f oka";

# if the message to print is from AFD
my ($CLSECHO_AFD) = catfile($ORA_CRS_HOME, "bin", "clsecho") . " -p usm -f afd";

our $CRS_ACTION = "";                    # if set, contains "start", "stop",
# "check", "clean", etc.

# CRS check function return codes from crs/agentfw/include/clsagfw.h
use constant CLSAGFW_ONLINE            => 0;
use constant CLSAGFW_UNPLANNED_OFFLINE => 1;
use constant CLSAGFW_PLANNED_OFFLINE   => 2;
use constant CLSAGFW_UNKNOWN           => 3;
use constant CLSAGFW_PARTIAL           => 4;
use constant CLSAGFW_FAILED            => 5;

# CRS return codes for functions other than check()
use constant CLSAGFW_AE_SUCCESS        => 0;
use constant CLSAGFW_AE_FAIL           => 1;

use constant PRINT_INFORM              => 0;
use constant PRINT_ERROR               => 1;
use constant PRINT_VERBOSE             => 2;

use constant PRINT_NOALERTLOG          => 0;
use constant PRINT_ALERTLOG            => 1;

# read_or_verify_message
use constant MSG_READ                  => 0;
use constant MSG_VERIFY                => 1;

# Other components may use acfslib modules.
# This helps to identify the product we are.
use constant USM_PROD_ACFS            => "prod_acfs";
use constant USM_PROD_OKA             => "prod_oka";
use constant USM_PROD_AFD             => "prod_afd";
use constant USM_PROD_OLFS            => "prod_olfs";

# to identify the product. Default is ACFS
our ($USM_CURRENT_PROD) = USM_PROD_ACFS;

my ($OSNAME) = $Config{osname};
chomp($OSNAME);
lib_get_oracle_home(); # Define _ORACLE_HOME variable

# lib_am_root
#
# call into lib_osds_am_root
#
sub lib_am_root
{
  return lib_osds_am_root();
} # end lib_am_root


sub lib_trace
{
  my ($msg_id) = shift(@_);         # PRINT_ERROR, PRINT_INFORM
  my ($msg) = shift(@_);
  my (@arg_array) = @_;

  if( $_ORA_USM_TRACE_ENABLED == 1){
    lib_inform_print_noalert( $msg_id, $msg, @arg_array);
  }
  return USM_SUCCESS;
}

#
# connect to the ASM instance
#
sub lib_asm_connect
{
  my ($dbh);
  my (%session_mode);
  my ($driver) = 'dbi:Oracle:';
  my ($usr) = '/'; # According to perl DBI and DBD docs, this allows for
  # connecting to Oracle as the local OS authenticated user.
  my ($pswd) = '';

  lib_trace( 9176, "Entering '%s'", "la connect");
  # $session_mode{'ora_session_mode'} = 2;    # sysdba
  $session_mode{'ora_session_mode'} = 32768;  # sysasm
  $session_mode{'PrintError'} = 0;

  $dbh = DBI->connect($driver, $usr, $pswd, \%session_mode);
  warn "$DBI::errstr\n" unless defined ($dbh);
  if (!defined ($dbh))
  {

    if (defined($ENV{ADE_VIEW_ROOT}))
    {
      # On non-Linux platforms, ADE changes your gid when you enter a view.
      # This program is called as root, which then does a "su <user>" in
      # order to perform the ASM functions. The "su" command will revert
      # your gid back to the original gid. This means that you can no longer
      # "talk" to ASM. The -no_newgid option on your "ade useview <view>"
      # command will prevent the gid switch.
      my ($my_gid_list) = $(;
      my ($asm_user, $asm_gid) = lib_get_asm_user();
      my (@array) = split(/ /, $my_gid_list);
      my ($my_gid) = $array[0];

      # On NT, $asm_gid comes back as 0 from lib_get_asm_user().
      if (($my_gid != $asm_gid) && $asm_gid)
      {
        # No internationalization of the message because this is development
        lib_error_print(9999, "\nASM/user gid mismatch ($asm_gid/$my_gid).");
        lib_error_print(9999,
                        "You may need the -no_newgrp option on the ade useview command.");
      }
    }
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    return USM_FAIL;
  }

  lib_trace( 9177, "Return from '%s'", "la connect");
  return $dbh;
}

#
# connect to the ASM instance
#
sub lib_asm_disconnect
{
  my ($dbh);
  lib_trace( 9176, "Entering '%s'", "la disconnect");
  if (defined($dbh))
  {
    $dbh->disconnect();
  }
  lib_trace( 9177, "Return from '%s'", "la disconnect");
} # end_lib_asm_disconnect

# lib_asm_enable_volume
#
# If the specified volume is not ASM enabled - enable it.
#
# The caller must have verified that the diskgroup is mounted.
#
sub lib_asm_enable_volume
{
  my ($dbh, $diskgroup, $volume) = @_;
  my ($diskgroup_uc, $volume_uc);
  my ($qry);                  # SQL query
  my ($dg_state);             # ASM state of the diskgroup
  my ($sth);                  # SQL statement handle
  my ($row);                  # SQL table row
  my ($found_diskgroup) = 0;
  my ($found_volume) = 0;
  my ($return_val) = USM_SUCCESS;
  lib_trace( 9176, "Entering '%s'", "la enable volume");
  # ASM returns select data in upper case and so our comparisons have to
  # match case.
  $diskgroup_uc = uc($diskgroup);
  $volume_uc = uc($volume);

  $qry = "SELECT NAME_KFVOL,STATE_KFVOL FROM X\$kfvol xvols " .
      "WHERE xvols.device_kfvol = '$ENV{_ORA_VOLUME_DEVICE}' " .
      "AND xvols.filenum_kfvol <> 0";

  $sth = asm_select_stmt($dbh, $qry);
  lib_trace( 9183, "Query = '%s'", $qry);

  while (defined ($row = asm_fetch_row($sth)))
  {
    if ( $row->{'NAME_KFVOL'} eq $volume_uc )
    {
      $found_volume = 1;
      if ($row->{'STATE_KFVOL'} != 1 )
      {
        # enable the volume
        lib_inform_print(9103, "Enabling volume '%s' on diskgroup '%s'.",
                                                       $volume, $diskgroup);
        $qry = "alter diskgroup $diskgroup enable volume $volume";
        $return_val = asm_do_stmt($dbh, $qry);
        if ($return_val == USM_FAIL)
        {
          lib_error_print(9104, "Enable of volume '%s' failed.", $volume);
        }
      }
      last;
    }
  }
  eval { $sth->finish(); };

  if (! $found_volume)
  {
    lib_error_print(9105, "Volume '%s' not found in '%s'.", $volume, $diskgroup);
    $return_val = USM_FAIL;
  }

  if( $return_val == USM_SUCCESS){
      lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
  }elsif( $return_val == USM_FAIL){
      lib_trace( 9178, "Return code = %s", "USM_FAIL");
  }else{
      lib_trace( 9178, "Return code = %s", "$return_val");
  }

  lib_trace( 9177, "Return from '%s'", "la enable volume");

  return $return_val
} # end asm_enable_volume

# lib_asm_disable_volume
#
# If the specified volume is not ASM disabled - disable it.
#
# The caller must have verified that the diskgroup is mounted.
#
sub lib_asm_disable_volume
{
  my ($dbh, $diskgroup, $volume) = @_;
  my ($diskgroup_uc, $volume_uc);
  my ($qry);                  # SQL query
  my ($dg_state);             # ASM state of the diskgroup
  my ($sth);                  # SQL statement handle
  my ($row);                  # SQL table row
  my ($found_diskgroup) = 0;
  my ($found_volume) = 0;
  my ($return_val) = USM_SUCCESS;
  lib_trace( 9176, "Entering '%s'", "la disable volume");
  # ASM returns select data in upper case and so our comparisons have to
  # match case.
  $diskgroup_uc = uc($diskgroup);
  $volume_uc = uc($volume);

  $qry = "SELECT NAME_KFVOL,STATE_KFVOL FROM X\$kfvol xvols " .
         "WHERE xvols.device_kfvol = '$ENV{_ORA_VOLUME_DEVICE}' " .
         "AND xvols.filenum_kfvol <> 0";

  $sth = asm_select_stmt($dbh, $qry);
  lib_trace( 9183, "Query = '%s'", $qry);

  while (defined ($row = asm_fetch_row($sth)))
  {
    if ( $row->{'NAME_KFVOL'} eq $volume_uc )
    {
      $found_volume = 1;
      if ($row->{'STATE_KFVOL'} != 0 )
      {
        # disable the volume
        lib_inform_print(9999,
          "Disabling volume '$volume' on diskgroup '$diskgroup'." );
        $qry = "alter diskgroup $diskgroup disable volume $volume";
        $return_val = asm_do_stmt($dbh, $qry);
        if ($return_val == USM_FAIL)
        {
          lib_error_print(9999, "disable of volume '$volume' failed.");
        }
      }
      last;
    }
  }
  eval { $sth->finish(); };

  if (! $found_volume)
  {
    lib_error_print(9105, "Volume '%s' not found in '%s'.", $volume, $diskgroup);
    $return_val = USM_FAIL;
  }

  if( $return_val == USM_SUCCESS){
      lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
  }elsif( $return_val == USM_FAIL){
      lib_trace( 9178, "Return code = %s", "USM_FAIL");
  }else{
      lib_trace( 9178, "Return code = %s", "$return_val");
  }

  lib_trace( 9177, "Return from '%s'", "la disable volume");

  return $return_val
} # end asm_disable_volume

# lib_asm_mount_diskgroup
#
# If the specified diskgroup is not ASM mounted - mount it.
#
sub lib_asm_mount_diskgroup
{
  my ($dbh, $diskgroup) = @_;
  my ($diskgroup_uc);
  my ($qry);                  # SQL query
  my ($dg_state);             # ASM state of the diskgroup
  my ($sth);                  # SQL statement handle
  my ($row);                  # SQL table row
  my ($found_diskgroup) = 0;
  my ($return_val);
  lib_trace( 9176, "Entering '%s'", "la mount dg");
  # ASM returns select data in upper case and so our comparisons have to
  # match case.
  $diskgroup_uc = uc($diskgroup);

  $return_val = USM_SUCCESS;

  # see if the diskgroup exists
  $qry= "select name,state from v\$asm_diskgroup";
  lib_trace( 9183, "Query = '%s'", $qry);
  $sth = asm_select_stmt($dbh, $qry);
  while (defined ($row = asm_fetch_row($sth)))
  {
    if ($row->{'NAME'} eq $diskgroup_uc)
    {
      $dg_state = $row->{'STATE'};
      $found_diskgroup = 1;
      last;
    }
  }
  eval { $sth->finish(); };

  if (! $found_diskgroup)
  {
    lib_error_print(9106, "Diskgroup '%s' not found.", $diskgroup);
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    lib_trace( 9177, "Return from '%s'", "la mount dg");
    return USM_FAIL;
  }

  if ($dg_state eq 'DISMOUNTED')
  {
    lib_inform_print(9107, "ASM mounting diskgroup '%s'.", $diskgroup);
    $qry = "alter diskgroup $diskgroup mount";
    lib_trace( 9183, "Query = '%s'", $qry);
    $return_val = asm_do_stmt($dbh, $qry);
    if ($return_val == USM_FAIL)
    {
      lib_error_print(9108, "ASM mount of diskgroup '%s' failed.", $diskgroup);
      lib_trace( 9178, "Return code = %s", "USM_FAIL");
      lib_trace( 9177, "Return from '%s'", "la mount dg");
      return USM_FAIL;
    }
  }
  if( $return_val == USM_SUCCESS){
      lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
  }elsif( $return_val == USM_FAIL){
      lib_trace( 9178, "Return code = %s", "USM_FAIL");
  }else{
      lib_trace( 9178, "Return code = %s", "$return_val");
  }

  lib_trace( 9177, "Return from '%s'", "la mount dg");

  return $return_val;
} # end lib_asm_mount_and_enable

# lib_check_drivers_installed
#
sub lib_check_drivers_installed
{
  my ($driver);
  my ($num_drivers_installed) = 0;
  lib_trace( 9176, "Entering '%s'", "lc drivers installed");
  foreach $driver ($DRIVER_COMPONENTS[OKS_IDX],
                   $DRIVER_COMPONENTS[AVD_IDX], $DRIVER_COMPONENTS[OFS_IDX])
  {
    if($VERBOSE)
    {
      lib_inform_print(9155, "Checking for existing '%s' driver " .
                 "installation.",
                 $driver);
    }
    if (lib_osds_check_driver_installed($driver))
    {
      $num_drivers_installed++;
    }
  }

  if ($num_drivers_installed != 3)
  {
    lib_trace( 9178, "Return code = %s", "0");
    lib_trace( 9177,  "Return from '%s'", "lc drivers installed");
    return 0;
  }

  lib_trace( 9178, "Return code = %s", "1");
  lib_trace( 9177, "Return from '%s'", "lc drivers installed");
  return 1;
} # end lib_check_drivers_installed

# lib_check_any_driver_installed
#
sub lib_check_any_driver_installed
{
  my ($driver);
  lib_trace( 9176, "Entering '%s'", "lc check any driver");
  foreach $driver ($DRIVER_COMPONENTS[OKS_IDX],
                   $DRIVER_COMPONENTS[AVD_IDX], $DRIVER_COMPONENTS[OFS_IDX])
  {
    if($VERBOSE)
    {
      lib_inform_print(9155, "Checking for existing '%s' driver " .
                 "installation.",
                 $driver);
    }
    if (lib_osds_check_driver_installed($driver))
    {
      lib_trace( 9178, "Return code = %s", "1");
      lib_trace( 9177, "Return from '%s'", "lc check any driver");

      return 1;
    }
  }

  lib_trace( 9178, "Return code = %s", "0");
  lib_trace( 9177, "Return from '%s'", "lc check any driver");
  return 0;

} # end lib_check_any_driver_installed

# lib_check_uninstall_required
#
sub lib_check_uninstall_required
{
  my ($previous_install_detected_msg) = @_;
  return lib_osds_check_uninstall_required($previous_install_detected_msg);
} # end lib_check_uninstall_required

# lib_count_drivers_loaded
#
sub lib_count_drivers_loaded
{
  my ($driver);
  my ($num_drivers_loaded) = 0;
  lib_trace( 9176, "Entering '%s'", "count drivers");
  foreach $driver ($DRIVER_COMPONENTS[OKS_IDX],
                   $DRIVER_COMPONENTS[AVD_IDX], $DRIVER_COMPONENTS[OFS_IDX])
  {
    if (lib_osds_check_driver_loaded($driver))
    {
      $num_drivers_loaded++;
    }
  }
  lib_trace( 9178, "Return code = %s", "$num_drivers_loaded");
  lib_trace( 9177, "Return from '%s'",  "count drivers");
  return $num_drivers_loaded;
} # end lib_osds_count_drivers_loaded

# lib_check_drivers_loaded
#
sub lib_check_drivers_loaded
{
  my ($num_drivers_loaded) = 0;
  my ($return_val);
  lib_trace( 9176, "Entering '%s'", "check drivers loaded");
  $num_drivers_loaded = lib_count_drivers_loaded();

  if ($num_drivers_loaded != 3)
  {
    $return_val = 0;
  }
  else
  {
    $return_val = 1;
  }
  lib_trace( 9178, "Return code = %s", "$return_val");
  lib_trace( 9177, "Return from '%s'",  "check drivers loaded");
  return $return_val;
} # end lib_osds_check_drivers_loaded

# lib_check_loaded_drivers_mismatch
#
# Determine whether or not the installed drivers match the drivers that
# are loaded in the kernel.

sub lib_check_loaded_drivers_mismatch
{
  return lib_osds_check_loaded_drivers_mismatch();
}

use constant CHECK_IN_PROGRESS_NO      => 0;
use constant CHECK_IN_PROGRESS_YES     => 1;
use constant CHECK_IN_PROGRESS_TIMEOUT => 2;

# lib_check_in_progress
#
# Use a temp file to mark a check being in progress
#
# Returns:
#     CHECK_IN_PROGRESS_NO - no previous check currently in progress
#     CHECK_IN_PROGRESS_YES - previous check currently in progress
#     CHECK_IN_PROGRESS_TIMEOUT - previous check in progress timeout exceeded
#
# We return a CHECK_IN_PROGRESS_NO even if the directory or the file creation
# fails. This, effectively, disables the function because the caller will
# think that there is no check in progress and so the check proceeds normally.
# This is better than returning a 1, which would make the caller think that
# is a check in progress - even if there isn't one.
#
sub lib_check_in_progress
{
  my ($fname) = @_;                     # temp file name
  my ($pname);                          # full path name for temp file name
  my ($retcode) = CHECK_IN_PROGRESS_NO; # return value
  my ($time_stamp) = get_day_time_in_seconds();

  lib_trace( 9176, "Entering '%s'", "check progress");
  if (! -d $TMPDIR)
  {
    mkpath ($TMPDIR, 0777) or warn ("failed to create $TMPDIR: $!"), $retcode = 1;
    if ($retcode eq 1)
    {

        lib_trace( 9178, "Return code = %s", "CHECK_IN_PROGRESS_NO");
        lib_trace( 9177, "Return from '%s'",  "check progress");
        return CHECK_IN_PROGRESS_NO;
    }
  }

  lib_trace( 9182, "Variable '%s' has value '%s'", "TMPDIR", "$TMPDIR");
  $pname = build_check_filename($TMPDIR, $fname);
  lib_trace( 9182, "Variable '%s' has value '%s'", "pname", "$pname");
  if (-e $pname)
  {
    # A check for this $pname is already in progress.
    my ($time_stamp);
    my ($time_limit) = $ENV{_ORA_CHECK_TIMEOUT};

    # If the $pname creation timestamp is greater than the check timeout value,
    # we return CHECK_IN_PROGRESS_TIMEOUT.
    open FILE, "<$pname"
          or warn ("failed to open $pname: $!"),
                  $retcode = CHECK_IN_PROGRESS_YES;
    if ($retcode ne CHECK_IN_PROGRESS_NO)
    {
      # We could not open the file to read the time stamp. We're root
      # and we can't open a file that we created.... hmmm.
      # Well, there is a small race between the exist check and the open.
      # Remove the file (if it still exists). It will be created on next check.
      unlink $pname;
      lib_trace( 9178, "Return code = %s", "$retcode");
      lib_trace( 9177, "Return from '%s'",  "check progress");
      return $retcode;
    }

    $time_stamp = <FILE>;
    if(!defined($time_stamp))
    {
      # Apparently the file got damaged. delete the file and return
      # CHECK_IN_PROGRESS_YES. The file will be recreated on the next check.
      unlink $pname;
      lib_trace( 9178, "Return code = %s", "CHECK_IN_PROGRESS_YES");
      lib_trace( 9177, "Return from '%s'",  "check progress");
      return CHECK_IN_PROGRESS_YES;
    }
    chomp($time_stamp);
    close(FILE);

    if (!defined($time_limit))
    {
      # We could not get the _ORA_SCRIPT_TIMEOUT from the environment.
      # use the default falue from ./has/crs/template/registry.acfs.type.
      $time_limit = 300;
    }

    if (time_limit_exceeded($time_stamp, $time_limit))
    {
      lib_trace( 9178, "Return code = %s", "CHECK_IN_PROGRESS_TIMEOUT");
      $retcode = CHECK_IN_PROGRESS_TIMEOUT;
    }
    else
    {
      lib_trace( 9178, "Return code = %s", "CHECK_IN_PROGRESS_YES");
      $retcode = CHECK_IN_PROGRESS_YES;
    }
  }
  else
  {
    # Marking check in progress.
    open FILE, ">$pname" or warn ("failed to create $pname: $!"), $retcode = 1;
    if ($retcode eq 0)
    {
      printf FILE "%05s\n", $time_stamp;
      close FILE;
    }
    lib_trace( 9178, "Return code = %s", "CHECK_IN_PROGRESS_NO");
    $retcode = CHECK_IN_PROGRESS_NO;
  }
  lib_trace( 9177, "Return from '%s'",  "check progress");
  return $retcode;
} # end lib_check_in_progress

# lib_end_check_in_progress
#
# returns 0 (success) or 1 (failed to remove existing tmp file)
#
# This is also called from start() when no temp file exists (should exist)
# to guarantee a "clean slate".
#
sub lib_end_check_in_progress
{
  my ($fname) = @_;               # temp file name
  my ($pname);                    # full path name for temp file name
  my ($retcode) = 0;              # return value
  lib_trace( 9176, "Entering '%s'", "lib end check progress");

  $pname = build_check_filename($TMPDIR, $fname);
  lib_trace( 9182, "Variable '%s' has value '%s'", "pname", "$pname");
  if (-e $pname)
  {
    unlink $pname or warn ("failed to remove $pname: $!"), $retcode = 1;
  }
  lib_trace( 9178, "Return code = %s", "$retcode");
  lib_trace( 9177, "Return from '%s'",  "lib end check progress");
  return $retcode;
} # end lib_end_check_in_progress

# lib_control_devices_accessible
#
# call into control_devices_accessible
#
sub lib_control_devices_accessible
{
  return lib_osds_control_devices_accessible();
} # end lib_control_devices_accessible

# lib_get_asm_admin_name
#
# Get the group name of the ASM administrator
# NOTE: not called from Windows
# This is not really OSD code - but it's not (yet) needed on Windows
# and is not installed there.
#
sub lib_get_asm_admin_name
{
  lib_trace( 9176, "Entering '%s'", "ga admin name");
  if (defined($CACHED_ASMADMIN))
  {
    lib_trace( 9178, "Return code = %s", "CACHED_ASMADMIN");
    lib_trace( 9177, "Return from '%s'",  "ga admin name");
    return $CACHED_ASMADMIN;
  }

  # In dev env get the ASM group from the install config file because
  # osdbagrp doesn't return the primary group for test user* on farm machines
  if ( defined($ENV{ADE_VIEW_ROOT}) )
  {
    my $paramgrp = getParam("ORA_ASM_GROUP");

    if ((!$paramgrp eq "") &&
        (lib_osds_validate_asmadmin_group($paramgrp) == USM_SUCCESS))
    {
      $CACHED_ASMADMIN = $paramgrp;
      lib_trace( 9178, "Return code = %s", "$paramgrp");
      lib_trace( 9177, "Return from '%s'",  "ga admin name");
      return $paramgrp;
    }
  }

  my ($asmadmin) = 'dba';

  # AFD 9508 message differs from ACFS
  my ($err_str_9508) = "ACFS installation aborted (component %s).";
  if ($USM_CURRENT_PROD eq USM_PROD_AFD)
  {
    $err_str_9508 = "AFD installation aborted (component %s).";
  }

  # get the current system ASM admin group name
  if ((defined($ORACLE_HOME)) && (-e "$ORACLE_HOME/bin/osdbagrp"))
  {
    open (ASMADMIN, "$ORACLE_HOME/bin/osdbagrp -a |");
    $asmadmin = <ASMADMIN>;
    close (ASMADMIN);
    if ((!defined($asmadmin)) || ($asmadmin eq ""))
    {
      if( defined($ADE_VIEW_ROOT)){
        # We 're in a view, solve this cleanly.
        # This code should run in all platforms.
        $asmadmin = getgrgid((getpwuid( $<))[3]);
        if( (!defined( $asmadmin)) || ( $asmadmin eq "")){
          lib_error_print( 10610, "Failed to get current user information.");
          lib_trace( 9178, "Return code = %s", "USM_FAIL");
          lib_trace( 9177, "Return from '%s'",  "ga admin name");
          exit USM_FAIL;
        }
      }else{
        lib_error_print(9115, "The command '%s' returned an unexpected value.",
                                             "$ORACLE_HOME/bin/osdbagrp -a");
        lib_error_print(9508, "$err_str_9508", $COMMAND);
        # This is unrecoverable - fail. Unfortunately, there's no graceful way
        # of failing without major redesign - and this is a VERY rare event.
        lib_trace( 9178, "Return code = %s", "USM_FAIL");
        lib_trace( 9177, "Return from '%s'",  "ga admin name");
        exit USM_FAIL;
      }
    }
  }

  if (lib_osds_validate_asmadmin_group($asmadmin) == USM_FAIL)
  {
    lib_error_print(9190, "User group '%s' does not exist.", $asmadmin);
    lib_error_print(9508, "$err_str_9508", $COMMAND);
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    lib_trace( 9177, "Return from '%s'",  "ga admin name");
    exit USM_FAIL;
  }

  $CACHED_ASMADMIN = $asmadmin;
  lib_trace( 9178, "Return code = %s", "$CACHED_ASMADMIN");
  lib_trace( 9177, "Return from '%s'",  "ga admin name");
  return $CACHED_ASMADMIN;
} # end lib_get_asm_admin_name

# lib_get_advm_mounts
#
# call into lib_osds_get_advm_mounts
#
sub lib_get_advm_mounts
{
  return lib_osds_get_advm_mounts();
} # end lib_get_advm_mounts

# lib_get_asm_user
#
# call into lib_osds_get_asm_user
#
sub lib_get_asm_user
{
  return lib_osds_get_asm_user();
} # end lib_get_asm_user

# lib_get_drive_info
#
# call into lib_osds_get_drive_info
#
sub lib_get_drive_info
{
  return lib_osds_get_drive_info(@_);
} # end lib_get_drive_info

# lib_load_usm_drivers
#
# Load the drivers if not already loaded. Silently ignore if a driver is loaded
#
# We do this in two phases because we found that on Solaris, sometimes the
# oracleacfs driver got loaded when the advm driver got loaded by devfsadm(1M).
# Then the next time through the loop, lib_osds_check_driver_loaded(oracleacfs)
# would not get called. This prevented /dev/ofsctl was from being created.
#
sub lib_load_usm_drivers
{
  my ($asm_storage_mode) = @_;
  my ($driver);
  my (@loaded);
  my ($idx);

  lib_trace( 9176, "Entering '%s'", "ld usm drvs");
  # determine which drivers are already loaded (if any).
  foreach $idx (OKS_IDX, AVD_IDX, OFS_IDX)
  {
    $driver = $DRIVER_COMPONENTS[$idx];
    $loaded[$idx] = 0;
    if (lib_osds_check_driver_loaded($driver))
    {
      $loaded[$idx] = 1;
    }
  }

  # Load the not already loaded drivers.
  # The order is important - OKS must be first.
  foreach $idx (OKS_IDX, AVD_IDX, OFS_IDX)
  {
    if (!$loaded[$idx])
    {
      my ($return_val);
      $driver = $DRIVER_COMPONENTS[$idx];

      lib_inform_print(9154, "Loading '%s' driver.", $driver);
      # We need to load the ACFS driver with the correct asm_storage_mode
      $return_val = lib_osds_load_driver($driver, $COMMAND,
                                         undef, undef, undef, undef,
                                         $asm_storage_mode);

      if ($return_val == USM_FAIL)
      {
        lib_error_print(9109, "%s driver failed to load.", $driver);
        lib_trace( 9178, "Return code = %s", "USM_FAIL");
        lib_trace( 9177, "Return from '%s'",  "ld usm drvs");
        return USM_FAIL;
      }
    }
  }

  lib_trace( 9177, "Return from '%s'",  "ld usm drvs");
  lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
  return USM_SUCCESS;
} # end lib_load_usm_drivers

# lib_mount
#
# call into lib_osds_mount
#
sub lib_mount
{
  my ($device, $mount_point, $options) = @_;

  # The following nomounts file can be used to prevent
  # automatic resources from mounting file systems
  # that may need to be fsck'd - resulting in a panic.
  lib_trace( 9176, "Entering '%s'", "lmount");

  my $nomounts = "" ;
  if (defined($ENV{'TEMP'}) && (-f "$ENV{'TEMP'}/oracle_nomounts" ))
  {
    $nomounts = "$ENV{'TEMP'}/oracle_nomounts";
  }
  elsif (defined($ENV{'TMP'}) && (-f "$ENV{'TMP'}/oracle_nomounts" ))
  {
    $nomounts = "$ENV{'TMP'}/oracle_nomounts";
  }
  elsif (-f "/tmp/oracle_nomounts" )
  {
    $nomounts = "/tmp/oracle_nomounts";
  }

  if ( $nomounts ne "" )
  {
    lib_inform_print(9151,
           "Ignoring request to mount due to existence of \"oracle_nomounts\" file: %s",
           $nomounts);
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    lib_trace( 9177, "Return from '%s'",  "lmount");
    return USM_FAIL;
  }

  lib_trace( 9177, "Return from '%s'",  "lmount");
  return lib_osds_mount($device, $mount_point, $options);
} # end lib_mount

# lib_mountpoint_descriptors
#
# call into lib_osds_mountpoint_descriptors
#
sub lib_mountpoint_descriptors
{
  my ($mount_point, $action) =  @_;
  return lib_osds_mountpoint_descriptors($mount_point, $action);
} # end lib_mountpoint_descriptors

# lib_recover_stale_mounts
#
# call acfsutil info fs and look for mountpoints marked Offline.
# Attempt to unmount the mount point.
#
# An acfsutil info fs -o mountpoints,isavailable entry looks like this:
# /mnt
# 1
#
sub lib_recover_stale_mounts
{
  my ($recover_specific_mountpoint) = @_;    # set by usm_singlefs_mount only
  my ($offline) = 0;
  my ($recovered_list) = "";
  my ($line) = "";
  my ($device);
  my ($mountpoint);
  my ($ret_val);
  my ($acfsutil_info_fs) =
                "$ACFSUTIL info fs " . OPT_CHR . "o mountpoints,isavailable";

  my ($switch) = 0;

  lib_trace( 9176, "Entering '%s'", "lrec stale mnts");
  # TODO: test the failure case.
  # this used to have a 2>&1 here.  Windows in CRS env does not seem to
  # like this sort of redirection, so it got booted.
  #
  # Do we need to check the error stream for -03036?  Or can we just
  # assume that there are no file systems if there is no output?
  # There doesn't seem to be any checks for other errors.
  open(INFO , "$acfsutil_info_fs $REDIRECT  |") or die "acfsutil info fs failed: $!";
  while ($line = <INFO>)
  {
    chomp($line);

    if ($line =~ /ACFS-03036/)
    {
      # no mounted file systems
      last;
    }

    if ($line =~/^\s*acfsutil info fs: (ACFS|CLSU)-\d{5}/)
    {
      # any ACFS-# error message
      lib_error_print(9150,
              "Unexpected output from 'acfsutil info fs': '%s'.", $line);
      next;
    }

    if ($switch == 0)
    {
      $mountpoint = $line;
      $switch = 1;
      next;
    }
    else
    {
      $switch = 0;
      if ($line eq 1)
      {
        #online
        next;
      }
    }

    $device = lib_osds_device_from_mountpoint($mountpoint);
    if (!defined($device))
    {
      lib_error_print(9122,
            "ADVM device not determined from mount point '%s'.", $mountpoint);
      lib_trace( 9178, "Return code = %s", "USM_FAIL");
      lib_trace( 9177, "Return from '%s'",  "lrec stale mnts");

      return USM_FAIL;
    }

    # usm_mount wants to recover all stale mounts (if any) and will
    # not pass an argument. usm_singlefs_mount wants to recover only
    # the mount point it is interested in (so as not to confuse
    # usm_mount and its state file).
    if (defined($recover_specific_mountpoint))
    {
      if ($recover_specific_mountpoint ne $mountpoint)
      {
        # looking for a specific mountpoint and this isn't it.
        next;
      }
    }
    else
    {
      #
      #  Recover any stale mount points in the registry.
      #
      my $cmd_out = "";
      my $acfsutil_registry = "$ACFSUTIL registry " . OPT_CHR . "l $mountpoint";
      open(REGISTRY, "$acfsutil_registry $REDIRECT |") or do
      {
        lib_error_print(9999, "executing $acfsutil_registry failed: $!");
        next;
      };
      $cmd_out = <REGISTRY>;
      close(REGISTRY);
      if ( ! defined ( $cmd_out ) )
      {
        next;
      }
      if ($cmd_out =~ /ACFS-03135/)
      {
        # called from acfsregistrymount and mount point isn't in the registry so
        # so we don't want to recover it.
        next;
      }
      if ($cmd_out =~ /ACFS-/)
      {
        # Unexpected error from acfsutil
        lib_error_print(9999,
           "Unexpected error from $acfsutil_registry. err=$cmd_out");
        next;
      }
      my $mountpointQM = quotemeta ( $mountpoint ); # for Windows
      if ( $cmd_out !~ /Mount Point\s+:\s+$mountpointQM\s+:/i )
      {
        # We probably shouldn't get here.  Our check for ACFS-03135
        # should have caught this condition.  At any rate we don't see
        # the mount point in the acfsutil registry output so it isn't
        # registered (or there's some other problem).
        lib_error_print(9999,
           "Unexpected output from $acfsutil_registry. err=$cmd_out");
        next;
      }
    }

    lib_inform_print(9139,
          "Attempting recovery of offline mount point '%s'",
          $mountpoint);

    $ret_val = lib_osds_unmount($mountpoint);

    if ($ret_val == 0)
    {
      # The unmount succeeded! Remove the mount point from the temp file
      # so it will simply be treated as a new mount in check().
      lib_inform_print(9110, "Offline mount point '%s' was dismounted for recovery.",
                                                             $mountpoint);
      $recovered_list .= "$device ";
    }
    else
    {
      # The unmount failed.
      # Find and report the open references on the mountpoint
      my ($refs) = lib_osds_mountpoint_descriptors($mountpoint, 0);
      lib_error_print (9112,
       "The following process IDs have open references on mount point '%s':", $mountpoint);
      lib_error_print(9999, $refs);  # message 9999 is not formatted
      lib_error_print(9113, "These processes will now be terminated.");

      # terminate any open descriptors
      $ret_val = lib_osds_mountpoint_descriptors($mountpoint, 1);
      lib_error_print(9114, "completed");

      if ($ret_val == USM_SUCCESS)
      {
        # OK try the unmount again
        $ret_val = lib_osds_unmount($mountpoint);
      }

      if ($ret_val == USM_SUCCESS)
      {
        # The unmount succeeded! Remove the mount point from the temp file
        # so it will simply be treated as a new mount in check().
        lib_inform_print(9110, "Offline mount point '%s' was dismounted for recovery.",
                                                             $mountpoint);
        $recovered_list .= "$device ";
      }
      else
      {
        # should never get here......... but......
        lib_error_print (9116,
                   "Offline mount point '%s' was not recovered.", $mountpoint);
        lib_error_print(9117, "Manual intervention is required.");
      }
    }
  }
  close (INFO);
  lib_trace( 9178, "Return code = %s", "$recovered_list");
  lib_trace( 9177, "Return from '%s'",  "lrec stale mnts");

  return $recovered_list;

} # end lib_recover_stale mounts

# lib_run_as_user
#
# call into lib_osds_run_as_user
#
sub lib_run_as_user
{
  my ($user_name, $cmd) = @_;
  return lib_osds_run_as_user($user_name, $cmd);
} # end lib_run_as_user

# lib_unmount
#
# call into lib_osds_unmount
#
sub lib_unmount
{
  my ($mount_point) = @_;
  return lib_osds_unmount($mount_point);
} # end lib_unmount

# lib_unload_usm_drivers
#
# Unload the USM drivers. Return error if any driver fails to unload.
#
sub lib_unload_usm_drivers
{
  # Optional argument: location of new install files.  Utilities from new
  # install files may be used to unload drivers if old utilities cannot be
  # found
  my ($install_files_loc, $sub_command) = @_;
  my ($driver);
  my ($return_val) = USM_SUCCESS;

  # First verify that the ACFS and ADVM drivers can be unloaded.
  # We'll wait upto 10 seconds before giving up.
  # The advantage of doing this up front is that if a driver can't be unloaded,
  # none of them will be unloaded - leaving the system in a normal state.
  #
  # Unfortunately, some of this code is duplicated in the following loop but
  # changing that would make it more complicated (IMHO) and it's not so bad
  # because the 'check loaded' data is cached and so is speedy the second time.
  if ((($COMMAND eq "acfsroot") && ($sub_command =~ "install")) ||
      (($COMMAND eq "acfsload") && ($sub_command eq "stop")))
  {
    my $retry_count = 0;
    foreach $driver ($DRIVER_COMPONENTS[OFS_IDX], $DRIVER_COMPONENTS[AVD_IDX])
    {
      if (lib_osds_check_driver_loaded($driver))
      {
        while (lib_osds_check_driver_inuse($driver))
        {
          if ($retry_count >= 10)
          {
            $return_val = USM_FAIL;
            lib_error_print(9118, "Driver %s in use - cannot unload.", $driver);
            goto out;
          }
          sleep(1);
          $retry_count++;
        }
      }
    }
  }

  lib_trace( 9176, "Entering '%s'", "uld usm drvs");
  foreach $driver ($DRIVER_COMPONENTS[OFS_IDX],
                   $DRIVER_COMPONENTS[AVD_IDX], $DRIVER_COMPONENTS[OKS_IDX])
  {
    # nothing to do if the driver is not loaded
    if (lib_osds_check_driver_loaded($driver))
    {
      # test to see that the driver is not being used
      if (lib_osds_check_driver_inuse($driver))
      {

        # If this is 'acfsroot install', we pretend to succeed.
        # This way the new drivers get installed but we exit with
        # USM_REBOOT_RECOMMENDED. After the reboot, the new drivers are running.
        if (($COMMAND eq "acfsroot") && ($sub_command eq "install"))
        {
          $return_val = USM_SUCCESS;
        }
        else
        {
          $return_val = USM_FAIL;
          lib_error_print (9118, "Driver %s in use - cannot unload.", $driver);
          last;
        }
      }

      $return_val = lib_osds_unload_driver($driver, $install_files_loc);
      if ($return_val != USM_SUCCESS)
      {
        lib_error_print(9119, "Driver %s failed to unload.", $driver);
        $return_val = USM_REBOOT_RECOMMENDED;
        last;
      }
    }
  }
  if( $return_val == USM_SUCCESS){
      lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
  }elsif( $return_val == USM_FAIL){
      lib_trace( 9178, "Return code = %s", "USM_FAIL");
  }else{
      lib_trace( 9178, "Return code = %s", "$return_val");
  }
  lib_trace( 9177, "Return from '%s'",  "uld usm drvs");
  return $return_val;
} # end lib_unload_usm_drivers

# lib_usm_supported
#
# call into lib_osds_usm_supported
#
sub lib_usm_supported
{
  if (lib_check_kernel(@_) &&
      lib_check_config())
  {
    return 1;
  }
  return 0;
} # end lib_usm_supported

# lib_usm_supported
#
# call into lib_osds_usm_supported
#
sub lib_verify_usm_devices
{
  return lib_osds_verify_usm_devices();
} # end lib_verify_usm_devices

# lib_inform_print
# If $silent is set, messages are not displayed.
# Prints to alert log.
#
sub lib_inform_print
{
  my (@arg_array) = @_;
  common_print(PRINT_INFORM, PRINT_ALERTLOG, @arg_array);

  return USM_SUCCESS;
}

# Doesn't print to alert logs
sub lib_inform_print_noalert
{
  my (@arg_array) = @_;
  common_print(PRINT_INFORM, PRINT_NOALERTLOG, @arg_array);

  return USM_SUCCESS;
}

# lib_verbose_print
# If $verbose is set, messages will be displayed.
# Prints to alert log.
#
sub lib_verbose_print
{
  my (@arg_array) = @_;
  common_print(PRINT_VERBOSE, PRINT_ALERTLOG, @arg_array);

  return USM_SUCCESS;
}

# Doesn't print to alert log.
sub lib_verbose_print_noalert
{
  my (@arg_array) = @_;
  common_print(PRINT_VERBOSE, PRINT_NOALERTLOG, @arg_array);

  return USM_SUCCESS;
}

# Prints to alert log.
sub lib_error_print
{
  my (@arg_array) = @_;
  common_print(PRINT_ERROR, PRINT_ALERTLOG, @arg_array);

  return USM_SUCCESS;
}

# Doesn't print to alert log.
sub lib_error_print_noalert
{
  my (@arg_array) = @_;
  common_print(PRINT_ERROR, PRINT_NOALERTLOG, @arg_array);

  return USM_SUCCESS;
}

# lib_create_mount_point
#
# call into lib_osds_create_mount_point
#
sub lib_create_mount_point
{
  my $mount_point = shift;
  return lib_osds_create_mount_point($mount_point);
} # end lib_create_mount_point

# lib_device_from_mountpoint
#
# call into lib_osds_device_from_mountpoint
#
sub lib_device_from_mountpoint
{
  my ($mount_point) = @_;
  return lib_osds_device_from_mountpoint($mount_point);
} # end lib_device_from_mountpoint

# lib_is_mounted
#
# call into lib_osds_is_mounted
#
sub lib_is_mounted
{
  my ($mount_point) = @_;
  return lib_osds_is_mounted($mount_point);
} # end lib_is_mounted

#
# Check if a file system is offline or otherwise
# unavailable. (0 , not available, 1, available, -1, other error)
#
sub lib_is_mount_available
{
    my ($mount_point) = @_;         # mount point to test
    my ($avail) = 0;                # assume not available
    my ($cmd_out);                  # Capture output of acfsutil command.

    #
    #  On windows performing acfsutil against a drive letter
    #  specification which includes a trailing backslash (e.g. "p:\")
    #  when the filesystem is stale will yield a bunch of errors rather
    #  than returning the availability state.  Strip the trailing
    #  backslash if any. This code is harmless on non-Windows.
    #
    lib_trace( 9176, "Entering '%s'", "lis mnt avail");
    $mount_point = substr ($mount_point,0,2)
       if ( length($mount_point) == 3 && substr($mount_point,1,2) eq ":\\" );

    # ACFSUTIL defined in lib_osds_usm.pm
    my $cmd = "$ACFSUTIL info fs " . OPT_CHR . "o isavailable $mount_point ";
    $cmd_out= `$cmd`;
    if (!defined($cmd_out))
    {
      $cmd_out="<No Error Text Returned>";
    }
    lib_trace( 9179, "Command executed: '%s', output = '%s'", "$cmd", "$cmd_out");
    if ($? == 0)
    {
      # Execution successful, cmd_out will hold 0 or 1.
      if ($cmd_out != 1 )
      {
          $avail = 0;
      }
      else
      {   #mount is available.
          $avail = 1;
      }
    }
    else
    {
      # We had an error running acfsutil.
      # Probable error: Not an acfs file system
      # Probable error #2: Mount point no longer exists.
      lib_error_print(9138,
            "command '%s' completed with an error: %s",
            $cmd, $cmd_out);

      $avail=-1;
    }
    lib_trace( 9178, "Return code = %s", "$avail");
    lib_trace( 9177, "Return from '%s'",  "lis mnt avail");
    return $avail;
}

###########################################
######## Local only static routines #######
###########################################

# common_print
#
# common print routine shared by lib_inform_print() and lib_error_print
#
sub common_print
{
  my ($message_type) = shift(@_);         # PRINT_ERROR, PRINT_INFORM
  my ($alertlog_print) = shift(@_);       # PRINT_NOALERTLOG, PRINT_ALERTLOG
  my ($message_id) = shift(@_);
  my ($message) = shift(@_);
  my (@message_args) = @_;
  my ($debug) = $ENV{'ACFS_DEBUG'};
  my ($myclsecho);

  if (defined($debug))
  {
    my (@args) = @message_args;
    my ($msg) = $message;
    open DBG, ">>/tmp/acfs_debug" or warn "/tmp/acfs_debug: $!";
    while (@args)
    {
      my ($arg) = shift(@args);
      $msg =~ s/\%s/$arg/;
    }
    print DBG "$COMMAND: $msg\n";
    close DBG;
  }

  if ($SILENT && ($message_type != PRINT_ERROR))
  {
    # do not print if the message is not an error and the -s option is used.
    return USM_SUCCESS;
  }

  if (!$VERBOSE && ($message_type == PRINT_VERBOSE))
  {
    # do not print verbose message, if -v is not used
    return USM_SUCCESS;
  }

  if ((! -e $CLSECHO) || ($SILENT))
  {
    common_print_noclsecho($message_id, $message, @message_args);
    return;
  }

  # clsecho uses '-l' option to print message to alert.log
  # Based on caller's intent, call clsecho accordingly.
  # if OKA product, use appropriate message file
  if ($USM_CURRENT_PROD eq USM_PROD_OKA)
  {
    if ($alertlog_print == PRINT_ALERTLOG)
    {
      $myclsecho = "$CLSECHO_OKA -l";
    }
    else
    {
      $myclsecho = "$CLSECHO_OKA";
    }
  }

  # Print error to console if wrapper clsecho is
  # not present or SILENT flag is set.
  # Bug 24682019: In Clone scenarios, clsecho may be present
  # but with incorrect ORACLE_HOME. In such cases, OUI will
  # invoke AFD commands with silent option. If silent flag
  # is set, print to console directly instead of using clsecho.
  #
  elsif ($USM_CURRENT_PROD eq USM_PROD_AFD)
  {
    if ($alertlog_print == PRINT_ALERTLOG)
    {
      $myclsecho = "$CLSECHO_AFD -l";
    }
    else
    {
      $myclsecho = "$CLSECHO_AFD";
    }
  }
  # Bug 23320181: Printing error to the console in case of OLFS instead of
  # clsecho as it requires various environment variables to be set. This is
  # because OLFS is installed when GI stack is not up, so files, like clsecho,
  # which need instantiation are not ready yet.
  elsif ($USM_CURRENT_PROD eq USM_PROD_OLFS)
  {
    common_print_noclsecho($message_id, $message, @message_args);
    return;
  }
  else
  {
    if ($alertlog_print == PRINT_ALERTLOG)
    {
      $myclsecho = "$CLSECHO_ACFS -l";
    }
    else
    {
      $myclsecho = "$CLSECHO_ACFS";
    }
  }

  # special case: message 9999 is not formatted
  # The message may be a list of PIDs, for instance, or an error message
  # from another command that may already have been I18N'ed.
  if ($message_id == 9999)
  {
# TODO - disable until bug 9664524 gets fixed.
undef $CRS;
# end TODO
    if (($message_type == PRINT_ERROR) && (defined($CRS)))
    {
      $message = "CRS_ERROR:" . $message;
    }

    # We strip any back ticks from the message.
    # A single back tick will generate errors:
    #   sh: -c: line 0: unexpected EOF while looking for matching ``'
    #   sh: -c: line 1: syntax error: unexpected end of file
    # Multiple (even mumber) back ticks will generate errors:
    #   sh: <cmd>: command not found
    $message =~ s/`//g;

    system("$myclsecho \"$message\"");
    return;
  }

  if (defined($ADE_VIEW_ROOT))
  {
    # If we are in a development environment, we compare the message
    # in the program to the message in acfsus.msg and flag a mis-match.
    read_or_verify_message($message_id, $message, MSG_VERIFY);
  }

  my ($arg_list) = "";

  # process message arguments
  while (@message_args)
  {
    my ($arg) = shift(@message_args);
    # do something with $arg
    if (defined $arg && $arg ne '') {
      $arg_list .= "\"$arg\" ";
    }
  }

  # Create the clsecho options string
  my ($echo_string) = "-m $message_id ";

  # Set the severity level (-c option)
  if ($message_type == PRINT_ERROR)
  {
# TODO - disable until bug 9664524 gets fixed.
undef $CRS;
# end TODO
    if (defined($CRS))
    {
      # Force errors to go to the terminal, not just the logs.
      # Normally, the messages would just go to the logs, but when AGFW
      # sees the "CRS_ERROR:" "decoration string", it strips that off and
      # sends the remaining string to the terminal and the logs. See
      # ./has/src/crs/agentfw/framework/clsAgfwScript.cpp.
      #
      # See has/include/clsem.h for "decoration string" guidelines. For example,
      # if the string, anywhere, contains 'f', it will be converted into the
      # "one digit fractional secs." - what you see may not be what you get.
      $echo_string .= "-c err -d 'CRS_ERROR: ' ";
    }
    else
    {
      # We're called interactively.
      $echo_string .= "-c err ";
    }
  }
  else
  {
    # lib_inform_print()
    $echo_string .= "-c info ";
  }

  if ($alertlog_print == PRINT_ALERTLOG)
  {
    # timestamp user message
    $echo_string .= "-t ";
    # write to log and console, with timestamps in log but not on console.
    $echo_string .= "-z ";
  }

  # finally append the message values arg_list
  $echo_string .= $arg_list;
  # Ignore any other argument if any.
  $echo_string .= " --";
  # Send the message

  # log the error
  if ($message_type == PRINT_ERROR)
  {
    # acfsutil command line option switch.
    my ($optc);
    $optc = '-';
    $optc = '/' if ($Config{osname} =~ /Win/);

    my (@array) = split / /, $arg_list;
    my ($text) = read_or_verify_message($message_id, undef, MSG_READ);
    my ($arg);

    foreach $arg (@array)
    {
      # Replace any '%s' with the actual argument.
      $arg =~ s/"//g;
      $text =~ s/%s/$arg/;
    }
  }

  system ("$myclsecho $echo_string");

} # end common_print

# common_print_noclsecho
sub common_print_noclsecho
{
  my $message_id = shift(@_);
  my $message = shift(@_);
  my @message_args = @_;
  my $arg;

  my $index = 1; #Number of parameter to set in the message
  foreach $arg (@message_args)
  {
    # Replace any '%s' with the actual argument.
    # Well, %s is the most common but not the only one kind of parameter
    # We can have '%(1)s', '%1s', '%s' or even it could be not string '%d'.
    $arg =~ s/"//g;
    $message =~ s/%\({0,1}$index{0,1}\){0,1}\w/$arg/;
    $index++;
  }
  if ($USM_CURRENT_PROD eq USM_PROD_OKA)
  {
    print "OKA-$message_id: $message\n";
  }
  elsif ($USM_CURRENT_PROD eq USM_PROD_AFD)
  {
    print "AFD-$message_id: $message\n";
  }
  elsif ($USM_CURRENT_PROD eq USM_PROD_OLFS)
  {
    print "OLFS-$message_id: $message\n";
  }
  else
  {
    print "ACFS-$message_id: $message\n";
  }
} # end common_print_noclsecho

# verify_message
#
# If $which == MSG_VERIFY:
#   Verify that the message in the print statement matches the message catalog.
#   Called only when ADE_VIEW_ROOT is set in the environment
#
# if $which == MSG_READ:
#   Return the message text to the caller.
#   Called to log the error to the ACFS command log.
#
sub read_or_verify_message
{
  my ($message_id, $message, $which) = @_;

  if ($USM_CURRENT_PROD eq USM_PROD_OKA)
  {
      # verify that the message matches the (okaus.msg) catalog
      open CATALOG, "<$ORACLE_HOME/usm/mesg/okaus.msg"
                                         or die "can't open msg file: $!";
  }
  elsif ($USM_CURRENT_PROD eq USM_PROD_AFD)
  {
      # verify that the message matches the (afdus.msg) catalog
      open CATALOG, "<$ORACLE_HOME/usm/mesg/afdus.msg"
                                         or die "can't open msg file: $!";
  }
  else
  {
      # verify that the message matches the (acfsus.msg) catalog
      open CATALOG, "<$ORACLE_HOME/usm/mesg/acfsus.msg"
                                         or die "can't open msg file: $!";
  }

  my ($line);
  while ($line = <CATALOG>)
  {
    my ($len) = length $message_id;

    # Convert the incoming msg id to the acfsus.msg 5 character format - if
    # needed. If the msg id is 5 chars (or more, [future]), no work is needed.
    if ($len < 5)
    {
      $message_id = sprintf("%05s", $message_id);
    }

    if ($line =~ /^$message_id/)
    {
      # the "split" separates the message in the file from what
      # preceeds it (e.g., 1234, 0, ")
      my (@acfsus_msg) = split(/"/, $line);
      chomp($acfsus_msg[1]);
      # lose the trailing quote
      $acfsus_msg[1] =~ s/"$//;

      if ($which == MSG_READ)
      {
        return $acfsus_msg[1];
      }

      if ($acfsus_msg[1] ne $message)
      {
        print "message $message_id format mismatch:\n";
        if ($USM_CURRENT_PROD eq USM_PROD_OKA)
        {
            print "okaus.msg:\t>$acfsus_msg[1]<\n";
        }
        elsif ($USM_CURRENT_PROD eq USM_PROD_AFD)
        {
            print "afdus.msg:\t>$acfsus_msg[1]<\n";
        }
        else
        {
            print "acfsus.msg:\t>$acfsus_msg[1]<\n";
        }
        print "$COMMAND:\t>$message<\n";
      }
      last;
    }
  }
  close (CATALOG);
} # end read_or_verify_message

#
# used for "sql alter diskgroup....
#
sub asm_do_stmt
{
  my ($dbh, $qry) = @_;
  my ($sth);
  my ($rv) = USM_SUCCESS;

  lib_trace( 9176, "Entering '%s'", "ado stmt");
  lib_trace( 9183, "Query = '%s'", $qry);
  $rv = $dbh->do($qry);
  warn "$DBI::errstr\n" unless defined ($rv);

  if (!defined ($rv))
  {
    $rv = USM_FAIL;
  }

   if( $rv == USM_SUCCESS){
      lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
  }elsif( $rv == USM_FAIL){
      lib_trace( 9178, "Return code = %s", "USM_FAIL");
  }else{
      lib_trace( 9178, "Return code = %s", "$rv");
  }
  lib_trace( 9177, "Return from '%s'", "ado stmt");
  return ($rv);
}

#
# used for sql select
#
sub asm_select_stmt
{
  my ($dbh, $qry) = @_;
  my ($sth);
  my ($rv);

  lib_trace( 9176, "Entering '%s'", "asel stmt");
  lib_trace( 9183, "Query = '%s'", $qry);

  eval { $sth = $dbh->prepare($qry); };
  if (!defined ($sth))
  { lib_trace( 10, "USM_FAIL: sth not defined");
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    lib_trace( 9177, "Return from '%s'",  "asel stmt");
    return USM_FAIL;
  }

  eval { $rv = $sth->execute(); };
  warn "$DBI::errstr\n" unless defined ($rv);

  if (!defined($rv))
  {
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    lib_trace( 9177, "Return from '%s'",  "asel stmt");
    return USM_FAIL;
  }
  lib_trace( 9177, "Return from '%s'",  "asel stmt");
  return ($sth);
}

#
# Fetch the next row on the table
#
sub asm_fetch_row
{
  my $sth = shift;
  my $row;
  return undef unless(defined $sth);
  eval { $row = $sth->fetchrow_hashref; };
  if ( $@ )
  {
     # We can't talk to the data base. Maybe ASM died.
     undef $row;
  }
  return $row;
}


# build_check_filename
#
# Return the name of the check_in_progress file name -
# Input:
#   $tmp_dir - typically /tmp or \temp.
#   $name of the file - this could include directories.
#
# Remove any semblance of directory structure in $name. So, on Unix, a
# name of /one/two/three will return /tmp/_one_two_three_check.
#
sub build_check_filename
{
  my ($tmp_dir, $name) = @_;

  lib_trace( 9176, "Entering '%s'", "bldchk fname");
  $name =~ s/\//_/g;
  $name =~ s/\\/_/g;
  my ($full_file_name) = catfile($tmp_dir, $name . "_check");

  lib_trace( 9178, "Return code = %s", "$full_file_name");
  lib_trace( 9177, "Return from '%s'",  "bldchk fname");
  return $full_file_name;
} # end build_check_filename

# time stamp ops

use constant SECONDS_PER_DAY => 86400;

# get_day_time_in_seconds
#
# Return number of seconds since local midnight.
#
sub get_day_time_in_seconds
{
  my ($sec, $min, $hour) = localtime(time);
  my ($seconds) = ($hour * 3600) + ($min * 60) + $sec;

  return $seconds;
} # end get_day_time_in_seconds

# time_limit_exceeded
#
# The main reason for a separate function is to handle time wrapping.
#
sub time_limit_exceeded
{
  my ($time_stamp, $time_limit) = @_;
  my ($current_time) = get_day_time_in_seconds();
  my ($time_diff);

  if ($current_time>= $time_stamp)
  {
    $time_diff= $current_time - $time_stamp;
  }
  else
  {
    # the timer has wrapped
    $time_diff= (SECONDS_PER_DAY - $time_stamp) + $current_time;
  }

  if ($time_diff< $time_limit)
  {
    # time limit not exceeded
    return 0;
  }

  return 1;
} # end time_limit_exceeded

sub trim($)
{
  my $string=shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string;
}

#
# ACFS resource utility functions
#

# Add the USM drivers resource.
sub add_usm_drivers_resource
{
  my $crsctl      = File::Spec->catfile($ORACLE_HOME, "bin", "crsctl");
  my $asmgrp = getParam("ORA_ASM_GROUP");
  chomp $asmgrp;
  my $owner = "root";
  my $CRSDUSER = getParam("ORACLE_OWNER");
  chomp $CRSDUSER;
  my $ret1 = 0;
  my $ret2 = 0;
  my $drivers_exist = 0;
  lib_trace( 9176, "Entering '%s'", "adusm drvsres");

  if ($OSNAME eq "Windows_NT" || $OSNAME eq "MSWin32")
  {
    if( $ADE_VIEW_ROOT eq "")
    {
        #A shiphome should be using this values for owner and asmgrp. Example:
        #owner:NT AUTHORITY\SYSTEM:rwx,pgrp:Administrators:r-x,other::r--,user:
        #<DOMAIN>\<USER>:r-x
        $asmgrp = "Administrators";
        $owner = "NT AUTHORITY\\SYSTEM";
    }
    else
    {
        #in the other hand, a farm job should have an ACL like the one below:
        #owner:<DOMAIN>\<USER>:rw-,pgrp::rw-,other::r--,user:<DOMAIN>\<USER>:r-x
        #So the next values are the correct ones.
        $asmgrp = "";
        $owner = $CRSDUSER;
    }
  }

  if ((($CRSDUSER eq "") || ($asmgrp eq "")) && !($OSNAME eq "Windows_NT" || $OSNAME eq "MSWin32"))
  {
    # getParam failed.
    lib_error_print(9375, "Adding ADVM/ACFS drivers resource failed.");
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    lib_trace( 9177, "Return from '%s'",  "adusm drvsres");
    return USM_FAIL;
  }


  $ret1 = system($crsctl, "add", "resource", "ora.drivers.acfs", "-attr", "ACL='owner:$owner:rwx,pgrp:$asmgrp:r-x,other::r--,user:$CRSDUSER:r-x'", "-type", "ora.drivers.acfs.type","-init");

  lib_trace( 9179, "Command executed: '%s', output = '%s'", "$crsctl", "$ret1");

  # When adding the usm drivers resource, we also add the ACTIONS
  # attribute. Furthermore, since we are adding a resource,
  # we first need to make sure the ADD command we did in the previous step
  # was done correctly.

  # If the drivers exist, then the add command did run successfully
  $drivers_exist = usm_resource_exists("drivers");
  # We will set actions if and only if the command was successfully executed

  if (($drivers_exist == USM_SUCCESS) && ($ret1 == 0))
  {
    $ret2 = lib_set_crsctl_actions($crsctl,$CRSDUSER,$asmgrp);
  }

  if (($ret1 != 0) || ($ret2 != 0))
  {
    lib_error_print(9375, "Adding ADVM/ACFS drivers resource failed.");
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    lib_trace( 9177, "Return from '%s'",  "adusm drvsres");
    return USM_FAIL;
  }
  else
  {
    lib_inform_print(9376, "Adding ADVM/ACFS drivers resource succeeded.");
    lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
    lib_trace( 9177, "Return from '%s'",  "adusm drvsres");
    return USM_SUCCESS;
  }
}

# Delete the USM drivers resource.
sub delete_usm_drivers_resource
{
  my $crsctl      = File::Spec->catfile($ORACLE_HOME, "bin", "crsctl");
  my @cmd = ($crsctl, "delete", "resource", "ora.drivers.acfs", "-f", "-init");
  my $ret = system(@cmd);

  lib_trace( 9176, "Entering '%s'", "deusm drvsres");
  lib_trace( 9179, "Command executed: '%s', output = '%s'", "@cmd", "$ret");
  if ($ret != 0)
  {
    lib_error_print(9377, "Deleting ADVM/ACFS drivers resource failed.");
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    lib_trace( 9177, "Return from '%s'",  "deusm drvsres");
    return USM_FAIL;
  }
  else
  {
    lib_inform_print(9378, "Deleting ADVM/ACFS drivers resource succeeded.");
    lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
    lib_trace( 9177, "Return from '%s'",  "deusm drvsres");
    return USM_SUCCESS;
  }
}

# Start the USM drivers resource.
sub start_usm_drivers_resource
{
  my $crsctl      = File::Spec->catfile($ORACLE_HOME, "bin", "crsctl");
  my @cmd = ($crsctl, "start", "resource", "ora.drivers.acfs", "-init");
  my $ret = system(@cmd);
  lib_trace( 9176, "Entering '%s'", "stusm drvsres");
  lib_trace( 9179, "Command executed: '%s', output = '%s'", "@cmd", "$ret");
  if ($ret != 0)
  {
    lib_error_print(9379, "Starting ADVM/ACFS drivers resource failed.");
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    lib_trace( 9177, "Return from '%s'",  "stusm drvsres");
    return USM_FAIL;
  }
  else
  {
    lib_inform_print(9380, "Starting ADVM/ACFS drivers resource succeeded.");
    lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
    lib_trace( 9177, "Return from '%s'",  "stusm drvsres");
    return USM_SUCCESS;
  }
}

# usm_resource_exists
#     returns USM_SUCCESS if the specified resource exists.
#     returns USM_FAIL if the specified resource does not exist.
#     returns USM_FAIL if en error is encountered.
#
sub usm_resource_exists
{
  my ($resource) = @_;
  my ($which);
  my ($opt) = "";
  my ($ret) = USM_SUCCESS;

  lib_trace( 9176, "Entering '%s'", "ures exists");
  lib_trace( 9182, "Variable '%s' has value '%s'", "resource", "$resource");
  if ($resource eq "drivers")
  {
    $which = "ora.drivers.acfs";
    $opt = "-init";
  }
  else
  {
    lib_error_print(532, "invalid option: %s", $resource);
    $ret = USM_FAIL;
  }

  if ($ret == USM_SUCCESS)
  {
    open CRSCTL, "$ORACLE_HOME/bin/crsctl stat res $which $opt |";
    if ($?)
    {
      $ret = USM_FAIL;
    }
    else
    {
      while (<CRSCTL>)
      {
        if (/CRS-2613/)
        {
          # "Could not find resource '%s'."
          $ret = USM_FAIL;
          last;
        }
      }
      close CRSCTL;
    }
  }
  if( $ret == USM_SUCCESS){
    lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
  }elsif( $ret == USM_FAIL){
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
  }else{
    lib_trace( 9178, "Return code = %s", "$ret");
  }
  lib_trace( 9177, "Return from '%s'",  "urest exists");
  return $ret;
}

sub modify_usm_drivers_resource
{
  my $crsctl   = File::Spec->catfile($ORACLE_HOME, "bin", "crsctl");
  my $asmgrp   = getParam("ORA_ASM_GROUP");
  my $owner    = "root";
  my $CRSDUSER = getParam("ORACLE_OWNER");
  chomp $CRSDUSER;
  chomp $asmgrp;
  my @cmd;
  my @cmd_out;
  my $ret;
  my $ret1 = 0;
  my $ret2 = 0;

  lib_trace( 9176, "Entering '%s'", "modu drvrs res");
  lib_trace( 9182, "Variable '%s' has value '%s'", "CRSDUSER", "$CRSDUSER");
  lib_trace( 9182, "Variable '%s' has value '%s'", "asmgrp", "$asmgrp");

  #if running in Windows
  if ($OSNAME eq "Windows_NT" || $OSNAME eq "MSWin32")
  {
    if( $ADE_VIEW_ROOT eq "")
    {
      #A shiphome should be using this values for owner and asmgrp. Example:
      #owner:NT AUTHORITY\SYSTEM:rwx,pgrp:Administrators:r-x,other::r--,
      #user:<DOMAIN>\<USER>:r-x
      $asmgrp = "Administrators";
      $owner = "NT AUTHORITY\\SYSTEM";
    }
    else
    {
      #in the other hand, a farm job should have an ACL like the one below:
      #owner:<DOMAIN>\<USER>:rw-,pgrp::rw-,other::r--,user:<DOMAIN>\
      #<USER>:r-x
      #So the next values are the correct ones.
      $asmgrp = "";
          $owner = $CRSDUSER;
      }
  }
  else
  { #running in a no-windows environment
      if (($CRSDUSER eq "") || ($asmgrp eq ""))
      {
          # getParam failed.
          lib_error_print(9381,
                      "Modification of ADVM/ACFS drivers resource failed.");
          lib_trace( 9178, "Return code = %s", "USM_FAIL");
          lib_trace( 9177, "Return from '%s'",  "modu drvrs res");
          return USM_FAIL;
      }
  }

  @cmd = ($crsctl, "modify", "resource", "ora.drivers.acfs", "-attr",
       "ACL='owner:$owner:r-x,pgrp:$asmgrp:r-x,user:$CRSDUSER:r-x,other::r--'",
       "-init");
  $ret = system(@cmd);
  lib_trace( 9179, "Command executed: '%s', output = '%s'", "@cmd", "$ret");
  $ret1 = ($ret) ? 1 : $ret1;

  # We modify the actions attribute of the ACFS driver and run
  # acfsutil cluster credential -s $user:$group.
  $ret2 = lib_set_crsctl_actions($crsctl,$CRSDUSER,$asmgrp);

  if (($ret1 != 0) || ($ret2 != 0))
  {
    lib_error_print(9381,
                  "Modification of ADVM/ACFS drivers resource failed.");
    lib_trace( 9178, "Return code = %s", "USM_FAIL");
    lib_trace( 9177, "Return from '%s'",  "modu drvrs res");
    return USM_FAIL;
  }

  lib_inform_print(9382,
                   "Modification of ADVM/ACFS drivers resource succeeded.");
  lib_trace( 9178, "Return code = %s", "USM_SUCCESS");
  lib_trace( 9177, "Return from '%s'",  "modu drvrs res");
  return USM_SUCCESS;
}

# lib_set_crsctl_actions
#
# This function fills the ACTIONS attribute of ora.drivers.acfs
#
# Params: the crsctl binary, the crsuser and the asmgrp
# Returns: 1 if successful, 0 if not
#
sub lib_set_crsctl_actions
{
  # This function receives the location of the
  # crsctl file, the user and the group
  my ($crsctl,$CRSDUSER,$asmgrp) = @_;
  my $ret;
  my $cmd_ret = 0;
  my $actions_attr;
  my $cmd_out;
  my $acfs_cmd;
  my @cmd;
  lib_trace( 9176, "Entering '%s'", "set crsctl actions");

  # On Windows, the values of the attribute are different
  if (($OSNAME eq "Windows_NT") || ($OSNAME eq "MSWin32"))
  {
    $actions_attr = "ACTIONS='mc_refresh mc_rescan dsc_aggregate repl_proxy'";
  }
  else
  {
    $actions_attr = "ACTIONS='mc_refresh,user:$CRSDUSER mc_rescan,user:$CRSDUSER dsc_aggregate,user:$CRSDUSER repl_proxy,group:$asmgrp'";
  }

  @cmd = ($crsctl,"modify","resource","ora.drivers.acfs","-attr",
          $actions_attr,"-init");
  $ret = system(@cmd);
  lib_trace(9179, "Command executed: '%s', output = '%s'","@cmd","$ret");
  $cmd_ret = ($ret) ? 1 : $cmd_ret;

  # We also run the cluster credential command
  # We will only run this command on MCs or DCs, because the command
  # does not work on standalone clusters
  if (isMemberClass() || isDomainClass())
  {
    # ACFSUTIL defined in lib_osds_usm.pm
    $acfs_cmd = "$ACFSUTIL cluster credential -s $CRSDUSER:$asmgrp";
    $cmd_out= `$acfs_cmd`;
    if (!defined($cmd_out))
    {
      $cmd_out="<No Error Text Returned>";
    }
    if ($? == 0)
    {
      # Execution successful, cmd_out will hold 0 or 1.
      # In this case, there was an error
      lib_trace( 9179, "Command successfully executed: '%s', output = '%s'",
                 "$acfs_cmd", "$cmd_out");
    }
    else
    {
      # We had an error running acfsutil.
      lib_error_print(9138,
                      "command '%s' completed with an error: %s",
                      $acfs_cmd, $cmd_out);
    }
  }

  lib_trace(9178, "Return = %s", "$cmd_ret");
  lib_trace(9177, "Return from '%s'",  "set crsctl actions");

  return $cmd_ret;
}


sub getParam
{
  my $var = $_[0];
  my $paramFhdl;
  my ($paramfile);

  lib_trace( 9176, "Entering '%s'", "getparm");
  if (!defined($ENV{ADE_VIEW_ROOT}))
  {
    $paramfile = File::Spec->catfile
        ($ORACLE_HOME, "crs", "install", "crsconfig_params");
  }
  else
  {
    $paramfile = File::Spec->catfile
        ($ORACLE_HOME, "has_work_global", "crsconfig_params");
    if (! -e $paramfile)
    {
      $paramfile = File::Spec->catfile
          ($ORACLE_HOME, "has_work", "crsconfig_params");
    }
  }

  if (! -e $paramfile)
  {
    # Silence this error message in dev env incase someone runs acfsroot
    # directly without CRS
    if (!defined($ENV{ADE_VIEW_ROOT}))
    {
      lib_error_print(10285, "Pathname '%s' does not exist.", $paramfile);
    }
    lib_trace( 9178, "Return code = %s", "(NULL)");
    lib_trace( 9177, "Return from '%s'", "getparm");
    return "";
  }

  open ( $paramFhdl, "<$paramfile" );
  while ( my $line = <$paramFhdl> )
  {
    chomp $line;
    if ( $line =~ /^\s*$var/i )
    {
      my $val = $line;
      $val =~ s/.*=\s*(.*)\s*/$1/i;
      close ( $paramFhdl );
      $val = "(NULL)" if $val eq '';
      lib_trace( 9178, "Return code = %s", "$val");
      lib_trace( 9177, "Return from '%s'", "getparm");
      return $val;
    }
  }
  close ( $paramFhdl );
  lib_trace( 9178, "Return code = %s", "(NULL)");
  lib_trace( 9177, "Return from '%s'", "getparm");
  return "";
}

sub lib_is_abs_path
{
  return lib_osds_is_abs_path(@_);
}

#
# Subroutine to print a warning header for a command
#
sub lib_print_cmd_header
{
  my ($cmd)= @_;
  $cmd=~ s/"/'/g;
  lib_inform_print (9390,
                 "The command '%s' returned unexpected output that" .
                 " may be important for system configuration:", $cmd);
} # end lib_print_cmd_header

#
#  lib_run_func - Run specified library function
#
#  This function exposes library functions to the command line so that
#  they may be called by programs outside of the usm/src/cmds framework.
#  This function itself is currently exposed from acfsroot.pl and is
#  accessed as follows.
#
#    acfsroot lib_run_func <acfslib::function()> [args ...]
#
#  For example
#
#    acfsroot lib_run_func lib_is_mounted /my_mount
#
#  This function is useful for things like the USM CRS agents which are
#  written in C++ but can benefit from the functions in this Perl
#  library.  When used with UsmUtils::execCmd, execCmdRead, and
#  execCmdClose, the agents have a reasonably seamless interface into
#  the functions in this library.  The first use of this interface (and
#  hence the only current example) is UsmUtils::CheckLoadedDriversMismatch.
#
#  Note that lib_run_func can be made to expose functions in the command
#  libraries (e.e. acfsload.pm) by putting a call out to it (see
#  the call to this function in acfsroot.pl for an example) and
#  prefixing the function name with the library name.  E.g.
#  osds_acfslog::osds_verify_correct_driver_version().
#

sub lib_run_func
{
  my $echoRetVal = 0;
  my $args = shift; # acfsroot passed args as one string
  my @args = split(/ /, $args );
    my $fName = shift(@args);      # name of library function to execute

    lib_trace( 9176, "Entering '%s'", "lrun func");
    lib_trace( 9182, "Variable '%s' has value '%s'", "fName", "$fName");
    if ( $fName eq "libRunFuncEchoRetVal" )
    {
      # Enable callers to get values returned by functions.  E.g.
      # lib_get_asm_admin_name returns a string with containing the asm
      # admin name.  By printing the string out the caller (typically
      # clns*Agent) can slurp it up.
      $echoRetVal = 1;
      $fName = shift(@args);      # name of library function to execute
    }

    my $fP;                 # pointer to function
    my $retVal;

    # Make sure a function name is specified
    if ( ! $fName )
    {
        lib_error_print(9999,
          "ERROR: Internal error: lib_run_func function name not specified");
        lib_trace( 9178, "Return code = %s", "-1");
        lib_trace( 9177, "Return from '%s'", "lrun func");
        return -1;
    }

    # Get a pointer to the function
    $fP = \&$fName;

    # Make sure the function is defined
    if ( ! defined ( &$fP ) )
    {
        lib_error_print(9999,
          "ERROR: Internal error: " .
          "Unknown lib_run_func function: $fName ");
        lib_trace( 9178, "Return code = %s", "-1");
        lib_trace( 9177, "Return from '%s'", "lrun func");
        return -1;
    }

    # Call the function specifying the remaining arguments
    $retVal = $fP->( @args );

    # Print the return value?
    print "libRunFuncRetVal=$retVal\n" if ( $echoRetVal );

    # Don't return the called function's return value here.  Some of
    # the functions we call might return strings and things which
    # wouldn't be well received by our caller who probably wants to
    # exit with an int.
    lib_trace( 9178, "Return code = %s", "0");
    lib_trace( 9177, "Return from '%s'", "lrun func");
    return 0;

}

# This function is used by 'acfsroot patch_verify' to compare patch
# files to installed files.
#
# Please note that this function ignores certain line changes that occur
# during the patching and install process and should not be used for
# general file comparison purposes.
sub md5compare
{
    my ($source,$target) = @_;
    my ($return_code) = USM_SUCCESS;

    my $fh1; #File in source
    if(!open($fh1, $source))
    {
        lib_inform_print (9999,"Can't open source '$source': $!");
        next;
    }
    binmode($fh1);
    my $md51 = Digest::MD5->new;
    while (<$fh1>)
    {
        next if ($_ =~ /^ORA_CRS_HOME=/);
        next if ($_ =~ /^set CRS_HOME=/);
        $md51->add($_);
    }
    close($fh1);
    my $digest1 = $md51->b64digest;

    my $fh2; #File in install
    if(!open($fh2, "$target"))
    {
        lib_inform_print (9999,"Can't open target '$target': $!");
        next;
    }
    binmode($fh2);
    my $md52 = Digest::MD5->new;
    while (<$fh2>)
    {
        next if ($_ =~ /^ORA_CRS_HOME=/);
        next if ($_ =~ /^set CRS_HOME=/);
        $md52->add($_);
    }
    close($fh2);
    my $digest2 = $md52->b64digest;

    if ($digest1 ne $digest2)
    {
        $return_code = USM_FAIL;
    }

    return $return_code;
}

sub lib_are_same_file
{
  my ($source, $target) = @_;
  my $return_code = lib_osds_are_same_file( $source, $target);

  return $return_code;
}

sub lib_is_number
{
  my ($var) = @_;

  return ($var eq $var+0);
}

# lib_get_asm_mode
#
# This is a function for getting the asm_mode using
# the cluster manifest file.
#
# If the caller does not send a valid cluster manifest location,
# or simply makes an empty call (lib_get_asm_mode()),
# the function will fallback to the data found in the $CFG file.
#
# Parameters: [0] - the location to the cluster manifest.
#                   This parameter is optional.
# Returns: asm_mode in lowercase: either far or near
#
sub lib_get_asm_mode
{
  my ($cluster_manifest_loc) = @_;
  my $asm_mode;
  lib_trace( 9176, "Entering '%s'", "get asm mode");
  # If the variable is defined and the file exists, we procceed
  # to use the cluster manifest file to get the asm mode
  if ((defined($cluster_manifest_loc)) &&
      (-e $cluster_manifest_loc))
  {
    my $asmcmd        = File::Spec->catfile($ORACLE_HOME,"bin","asmcmd");
    my $asmcmd_output = `$asmcmd lscc --file $cluster_manifest_loc 2>/dev/null`;
    lib_trace(9999, "$asmcmd lscc --file $cluster_manifest_loc returned = " .
              "$asmcmd_output");
    # Depending on what's specified in the cluster_manifest_loc,
    # we set the asm_mode.
    if ($asmcmd_output =~ /Indirect/)
    {
      $asm_mode = "far";
    }
    # We might not want to setup ACFSR, so we set it to near
    # We understand that this should actually be far,
    # but for now, we don't want to install ACFSR
    else
    {
      $asm_mode = "near";
    }
  }
  else
  {
    $asm_mode = getParam("ASM_CONFIG");
  }

  lib_trace(9178, "Return = %s", "$asm_mode");
  lib_trace(9177, "Return from '%s'",  "get asm mode");

  return $asm_mode;
}

# lib_get_asm_cluster_mode
#
# This is a helper function for manually getting the asm_cluster_mode
# so that we do not always rely on crsconfig_params
#
# Parameters: None
# Returns: asm_cluster_mode in uppercase: either CLIENT or REMOTE
#
sub lib_get_asm_cluster_mode
{
  # We get the hostname through Net::Domain::hostname()
  # https://perldoc.perl.org/Net/Domain.html
  my $host = Net::Domain::hostname();
  # Now that we have the hostname, we need to try to get the profile.xml
  my $profile_loc = File::Spec->catfile($ORACLE_HOME, "gpnp",
                                        "$host","profiles","peer",
                                        "profile.xml");
  my $asm_cluster_mode;
  lib_trace( 9176, "Entering '%s'", "get asm cluster mode");
  # If we don't find profile.xml, we fallback to what's found
  # in the crsconfig_params table
  unless (-e $profile_loc)
  {
    if (getParam("ASM_CONFIG") eq "far")
    {
      $asm_cluster_mode = "CLIENT";
    }
    else
    {
      $asm_cluster_mode = "REMOTE";
    }
  }
  # profile.xml does exist, so we use gpnptool to get the asm_cluster_mode
  else
  {
    # In an upgrade, we cannot depend on crsconfig_params,
    # so we are going to use gpnptool to get the asm_storage_mode
    # that is set under $ORACLE_HOME/gpnp/<hostname>/profiles/peer/profile.xml
    my $gpnptool = File::Spec->catfile($ORACLE_HOME, "bin", "gpnptool");
    my $gpnp_output = `$gpnptool getpval -asm_m -p=$profile_loc -o-`;
    if($gpnp_output =~ /remote/)
    {
      $asm_cluster_mode = "REMOTE";
    }
    else
    {
      $asm_cluster_mode = "CLIENT";
    }
  }
  lib_trace(9178, "Return = %s", "$asm_cluster_mode");
  lib_trace(9177, "Return from '%s'",  "get asm cluster mode");
  return $asm_cluster_mode;

}

# lib_is_local_container
#
# call into lib_osds_is_local_container
#
sub lib_is_local_container
{
  if ($configuration{islocal})
  {
    if ($configuration{islocal} eq "yes")
    {
      return 1;
    }
    else
    {
      return 0;
    }
  }
  my $result = lib_osds_is_local_container();
  if ($result)
  {
    $configuration{islocal} = "yes";
  }
  else
  {
    $configuration{islocal} = "no";
  }
  return $result;
}

# isODA
# Check for the existence of /opt/oracle/extapi/64/oak/liboak.*.so to determine
# if this is an ODA.
# In case the Jorge of the future needs to update this, the 'current' version
# can be found in has/install/crsconfig/crsutils.pm
#
sub isODA
{
  my @OAKLIB = glob(catfile("/opt","oracle","extapi","64","oak","liboak.*.so"));
  if (@OAKLIB)
  {
    return 1;
  }
  else
  {
    return 0;
  }
}


# The OPC dom0 is identified by checking for the existence
# of the /etc/nimbula_version file.
# In case the Jorge of the future needs to update this, the 'current' version
# can be found in has/install/crsconfig/crsutils.pm
sub isOPCDom0
{
  my $file =  catfile("/etc", "nimbula_version");
  if ( -e $file)
  {
    return 1;
  }
  else
  {
    return 0;
  }
}

sub isDomainClass
{
  my $class = getParam("CLUSTER_CLASS");
  $class = uc $class;
  if ($class eq "" || $class ne "DOMAINSERVICES")
  {
    return 0;
  }
  else
  {
    return 1;
  }
}

sub isMemberClass
{
  my $class = getParam("CLUSTER_CLASS");
  $class = uc $class;
  if ($class eq "" || $class ne "MEMBER")
  {
    return 0;
  }
  else
  {
    return 1;
  }
}

# The crsutils version of this function checks $CFG->params{'ODA_CLUSTER_TYPE'}
# I don't see that variable in crsconfig_params.sbs but I am going to assume
# it will be there in an ODA setup as the OPC variant is there.
sub isODADomu
{
    my $oda_type = getParam("ODA_CLUSTER_TYPE");
    if ($oda_type eq "" || $oda_type ne "dom-u")
    {
        return 0;
    }
    else
    {
        return 1;
    }
}

# Check OPC_CLUSTER_TYPE
sub isOPCDomu
{

    my $opc_type = getParam("OPC_CLUSTER_TYPE");
    if ($opc_type eq "" || $opc_type ne "dom-u")
    {
        return 0;
    }
    else
    {
        return 1;
    }
}


sub lib_acfs_remote_supported
{
  return osds_acfsr_supported(@_);
}
sub lib_acfs_remote_installed
{
  return osds_acfsr_installed(@_);
}
sub lib_acfs_remote_loaded
{
  return osds_acfsr_loaded(@_);
}

#Uncompress all products' driver files in the passed in path
#(e.g. USM/AFD/OLFS/OKA etc.)
sub lib_uncompress_all_driver_files
{
  return lib_osds_uncompress_driver_files(@_);
}

# lib_chmod
#
# Chmod wrapper for perl scripts
# Print a warning when command fails, let caller handle failures
#
# IN
#   permissions  - Permissions to set on file.
#   Target       - Target to change permissions on
#   Message type - Eg. "error" prints an error message
#                  all other defaults to print a warning message
#
# OUT
#   0 - Success
#   x - Errno returned by chmod 
# 
sub lib_chmod
{
  my ($permission, $target, $error) = @_;
  my $result = 0;
  $result = system ("chmod $permission $target");
  if ($result != 0)
  {
    if (defined $error)
    {
      if ($error eq "error")
      {
        lib_error_print(9347, "Unable to set permission bits (%s) on: '%s'.",
                         $permission, $target);
        return $result;
      }
    }
    # else print Warning
    lib_inform_print(9347, "Unable to set permission bits (%s) on: '%s'.",
                     $permission, $target);
  }
  return $result;
}

# There are 3 different ways of getting ORACLE_HOME:
# 1) From the environment.  This may be set by rootcrs or the user.
# 2) From the current location of the command.
# 3) From the crsconfig_params file.

# deinstall tree - Oracle provides a package of software
#     that contains all the tools necessary to remove the
#     Oracle software - this is called the deinstall.
#     In the event that you remove the Grid Home from
#     your system, this is the standalone deinstall,
#     although it currently doesn't work.  Our deinstall
#     is part of this throught the deinstall mapfiles.

# There are 5 different uses of the env ORACLE_HOME:
# 1) From the deinstall tree - if the Grid Home that is being removed
#    is gone, it will point to non-existent Grid Home.
# 2) From the deinstall tree, pointing to the Grid Home to remove.
# 3) From the rootcrs.pl during install.
# 4) From the rootcrs.pl during deinstall, but not from the deinstall tree.
# 5) And the final one, manually during our patching procedures.

# In all cases, we don't fully trust the passed in ORACLE_HOME, as the
# user may have incorrectly set it.  We also don't really want to force
# the user to set it, except in certain situations.

# So, we rely on a heuristic, which should catch all cases:
# 1) Find out where we are running from.  In most cases, acfsroot.pl
#    will run from ORACLE_HOME/lib.  (The only case this isn't true for
#    is an ACFS only patch or a command line manual install.)
# 2) Find out what the passed in ORACLE_HOME is.
# 3) See if either discovered or passed in ORACLE_HOME has a crsconfig_params
#    file.
# 4) Get ORACLE_HOME from the params file.
# 5) Use the param file ORACLE_HOME for comparison if it exists, or the env
#    if it doesn't.
# 6) Convert both the passed in  or params ORACLE_HOME (if it exists) and the
#    discovered "ORACLE_HOME" to an absolute path, which will
#    correctly dereference all symlinks in the path.  Compare these
#    two values.  If they match, then use the passed in\params ORACLE_HOME,
#    and assume that it is correct (most times it will be coming from
#    rootcrs).  This will cover most normal installs, and will
#    catch symlinks.
# 7) If they do not match, then use the discovered value.  This is
#    because during deinstall, one of two things can happen:
#    a) We are running from the deinstall tree, and the ORACLE_HOME
#       that is passed in is not valid.  We want to use our tools out
#       of the deinstall tree.
#    b) We are running from the deinstall tree, and the ORACLE_HOME
#       that is passed in is valid, but it doesn't matter to us,
#       we still use our tools out of the deinstall tree.
#    And during install, one of 3 things can happen:
#    a) We are running from rootcrs, and the value matches.
#    b) We are running from the command line during a manual patch\install
#       and the user has the incorrect ORACLE_HOME specified.  In
#       this case, assume we are running from the GridHome. (However,
#       this case will be covered by getting it from the params file.)

# Bug 11833948 was a bug where the OH was a symlink, yet we used the
# real path of the directory.  This resulted in not being able to contact
# the ASM instance for some reason.  Changing the OH to the symlinked
# path made things work again.

sub lib_get_oracle_home
{
  my ($dir) = $0;                   # $0 is built in acfstoolsdriver.{sh,bat}

  my $discovered_ORACLE_HOME;       # the ORACLE_HOME from bin location.
  my $param_ORACLE_HOME;            # the ORACLE_HOME in the param file.
  my $env_ORACLE_HOME;              # the ORACLE_HOME in the env.
  my $compare_ORACLE_HOME;          # the final choice we are comparing against.
  my $paramfile  = "";              # The location of the parameter file.

  lib_trace( 9176, "Entering '%s'", "get ora home");
  if ((defined($ENV{SRCHOME})) && ($ENV{SRCHOME} ne ""))
  {
    # We're in a development environment, we'll use that $ORACLE_HOME.
    $_ORACLE_HOME = $ENV{ORACLE_HOME};
    lib_trace( 9182, "Variable '%s' has value '%s'", "ORACLE_HOME",
                     "$_ORACLE_HOME");
    return;
  }

  # We're in a production environment.

  # This file lives in $ORACLE_HOME/lib - drop the trailing /lib
  $dir =~ s/\/lib$//;

  # This is where we are running from.
  $discovered_ORACLE_HOME = $dir;

  # Remove any trailing '\n's.
  chomp($discovered_ORACLE_HOME);

  # Now the env location, for safety.
  if (defined($ENV{ORACLE_HOME}))
  {
    $env_ORACLE_HOME = $ENV{ORACLE_HOME};
    chomp($env_ORACLE_HOME);
  }

  # Now we try to get the information from the params file,
  # just in case it matches somewhere else.
  # We use this param file in a few places now... should we
  # have a function to access it and get info?

  #  Most times we are running out of the grid home, or a place with
  # a crsconfig_params.
  $paramfile = $discovered_ORACLE_HOME . "crs/install/crsconfig_params";

  if ( ! -e $paramfile )
  {
    # Try the location of the env ORACLE_HOME for kicks.
    $paramfile = $env_ORACLE_HOME . "/crs/install/crsconfig_params";
  }
  if ( -e $paramfile )
  {
    open PARAMS, $paramfile;

    while (<PARAMS>)
    {
       if (m/^ORACLE_HOME/)
       {
          my @LINE = split /=/;
          $param_ORACLE_HOME = $LINE[$#LINE];
          # Remove any trailing '\n's
          chomp($param_ORACLE_HOME);
          last;
       }
    }

    close (PARAMS);
  }

  # Now, compare the env and the param file.  If they are different, use
  # the param file (assuming it is not null).
  # If they are the same, use the param file.
  # If we couldn't get to the param file, use the env location.
  if (defined($param_ORACLE_HOME) )
  {
    $compare_ORACLE_HOME = $param_ORACLE_HOME;
    lib_verbose_print(9500, "Location of Oracle Home is '%s' " .
                      "as determined from the internal configuration data",
                      $compare_ORACLE_HOME);
  }
  else  #param is not defined.
  {
    if (defined($env_ORACLE_HOME))
    {
      $compare_ORACLE_HOME = $env_ORACLE_HOME;
      lib_verbose_print(9501, "Location of Oracle Home is '%s' " .
                        "as determined from the ORACLE_HOME " .
                        "environment variable",
                        $compare_ORACLE_HOME);
    }
  }

  # Now, compare the abs_path of all dirs found and use the one we trust.
  if ((lib_is_abs_path($compare_ORACLE_HOME)) eq
      (lib_is_abs_path($discovered_ORACLE_HOME)))
  {
    # This will take into account symlinks.
    $ENV{ORACLE_HOME} = $compare_ORACLE_HOME;
  }
  else
  {
    # They differed (after abs_path), so assume the user
    # had something wrong somewhere, and use what we know
    # to be true.
    # Or the user is running deinstall, where ORACLE_HOME can point
    # to some invalid location not consistent with where we are
    # running out of.
    #  This is okay - the system location of our files won't
    #   change, and that's where we want to remove things from.
    #  OUI can handle cleaning up the ORACLE_HOME, wherever it is.
    $ENV{ORACLE_HOME} = $discovered_ORACLE_HOME;
    lib_verbose_print(9502, "Location of Oracle Home is '%s' " .
                      "as determined from the location of the Oracle " .
                      "library files",
                      $discovered_ORACLE_HOME);
  }
  $_ORACLE_HOME = $ENV{ORACLE_HOME};
  # Since $ORACLE_HOME is widely used throughout the code,
  # we assign it to this newly $_ORACLE_HOME variable
  $ORACLE_HOME = $_ORACLE_HOME;
  lib_trace(9182,"Variable '%s' has value '%s'", "ORACLE_HOME", "$_ORACLE_HOME");
  lib_trace(9177,"Return from '%s'", "get ora home");
}

# During a driver load oracledrivers.conf file will be created with
# the version of the driver
#
# Eg:  [<Driver>]
#      <Driver>InstalledVersion = XXYY
#      <Driver>AvailableVersion = XXYY
#      <Driver>InstalledRelease = XXYY
#      <Driver>AvailableRelease = XXYY
#      <Driver>InstalledBugList = XXYY,YYXX
#      <Driver>AvailableBugList = XXYY,YYXX
#      <Driver>InstalledBugHash = XXYY
#      <Driver>AvailableBugHash = XXYY
#
# NOTE: This file will be cleaned up on GI uninstall

sub lib_oracle_drivers_conf
{
  my $command = shift;  # Install, Uninstall, ACFS-9201(for not supported)
  my $driver;
  my $confpath = "/etc/"; # Sol, AIX
  my $ref      = lib_get_drivers_version();
  my %drvdata;
  my $fhandle;
  my $prevdata = "";
  my @drvlist = ("oka","afd","olfs","acfs");
  my $drvls;

  if (!$command)
  {
    # If we have $command empty or undef
    return USM_FAIL;
  }
  if ($command =~ "9201" && (!lib_am_root()))
  {
    # Acfsdriverstate does not always run as root we dont
    # want to fail when not necesary
    return USM_SUCCESS;
  }

  if (!defined $ref)
  {
    if ($command eq "install")
    {
      lib_error_print(9550,"    An error occurred while retrieving the kernel" .
                      " and command versions.");
      return USM_FAIL;
    }
  }
  else
  {
    # This option is only used during install
    %drvdata = %{$ref};
  }

  if ($USM_CURRENT_PROD eq USM_PROD_OKA)
  {
    $driver = "oka";
    @drvlist = ("afd","olfs","acfs");
  }
  elsif ($USM_CURRENT_PROD eq USM_PROD_AFD)
  {
    $driver = "afd";
    @drvlist = ("oka","olfs","acfs");
  }
  elsif ($USM_CURRENT_PROD eq USM_PROD_OLFS)
  {
    $driver = "olfs";
    @drvlist = ("oka","afd","acfs");
  }
  else
  {
    $driver = "acfs";
    @drvlist = ("oka","afd","olfs");
  }

  # Get configuration file path
  if ($Config{osname} =~ /Win/)
  {
    $confpath = "C:\\WINDOWS\\system32\\drivers\\";
  }
  elsif ($Config{osname} =~ /lin/)
  {
    $confpath .= "sysconfig/";
  }
  # else /etc

  if (!-d $confpath)
  {
    lib_inform_print(9295, "failed to open file %s",$confpath);
    return USM_FAIL;
  }

  # Include output to /etc/sysconfig/oracledrivers.conf
  $confpath .= "oracledrivers.conf";
  $driver = uc ($driver); #uppercase

  if (-e $confpath)
  {
    open ($fhandle,"<",$confpath) or do
       {

         lib_error_print(9295,"failed to open file %s",$confpath);
         return USM_FAIL;
       };

    # Remove $driver data and re-write.
    foreach (<$fhandle>)
    {
      next if ($_ =~ /$driver/ || $_ =~ /^\s*$/);
      foreach $drvls (@drvlist)
      {
        # Save only other oracle drivers data
        # This will make sure other trash data is removed
        $drvls = uc($drvls);
        chomp($_);
        $prevdata .= $_ . "\n" if ($_ =~ /^$drvls/ || $_ eq "[${drvls}]");
      }
    }
    close ($fhandle);
  }

  open ($fhandle,">",$confpath) or do
       {
         lib_error_print(9295,"failed to open file %s",$confpath);
         return USM_FAIL;
       };
  lib_inform_print (9294,"updating file %s",$confpath);

  # Write back the rest of the file data that does not require to be
  # deleted
  print $fhandle "$prevdata";

  if ($command eq "uninstall")
  {
    # This is the action triggered by *root uninstall
    # We just want to delete the driver data being uninstalled
    close ($fhandle);
    unlink ($confpath) if (-z $confpath);
    return USM_SUCCESS;
  }
  elsif ($command =~ "9201")
  {
    # During grid install acfsdriverstate is run as root
    # Thats the moment we write to the file.
    # All non-root calls wont be able to write
    # Triggered by driverstate supported. Write NOT SUPPORTED to file
    print $fhandle ("${command}\n");
    close ($fhandle);
    return USM_SUCCESS;
  }

  if (%drvdata)
  {
    print $fhandle ("[${driver}]\n");
    print $fhandle($driver."InstalledBuildNo = $drvdata{Installed}{BuildNo}\n");
    print $fhandle($driver."AvailableBuildNo = $drvdata{Available}{BuildNo}\n");
    print $fhandle($driver."InstalledVersion = $drvdata{Installed}{Version}".
                   " ($drvdata{Installed}{VSNFULL})\n");
    print $fhandle($driver."AvailableVersion = $drvdata{Available}{Version}".
                   " ($drvdata{Available}{VSNFULL})\n");
    print $fhandle($driver."InstalledBugList = $drvdata{Installed}{BugList}\n");
    print $fhandle($driver."AvailableBugList = $drvdata{Available}{BugList}\n");
    print $fhandle($driver."InstalledBugHash = $drvdata{Installed}{BugHash}\n");
    print $fhandle($driver."AvailableBugHash = $drvdata{Available}{BugHash}\n");
    print $fhandle($driver."InstalledKModule = $drvdata{Installed}{KERNVERS}\n");
    print $fhandle($driver."AvailableKModule = $drvdata{Available}{KERNVERS}\n");
    print $fhandle($driver."OS_KernelVersion = $drvdata{OS}{KERNVERS}\n");
  }
  close ($fhandle);

  return USM_SUCCESS;
}

# lib_get_drivers_version
#
# Get the currently installed and the oracle_home version
# Return:
#    Failure = Undefined
#    Success = Hash of driver data
#
# Hash example
#

sub lib_get_drivers_version
{
  my %drvdata;           # (Version,Release,BugList,BugHash,KERNELVERS)
  my @array;
  my $kernelvers;
  my $oskvers;
  my @drvpath;           # (/lib/modules,ORACLE_HOME/install...)
  my $prod;              # Product Eg: oks, afd, etc.
  my $fhandle;
  my $grepstr  = "";
  my $findstr  = "";
  my $driver   = "";     # Driver to parse
  my $type     = "Installed";

  if ($USM_CURRENT_PROD eq USM_PROD_OKA)
  {
    $prod = "oracka";
  }
  elsif ($USM_CURRENT_PROD eq USM_PROD_AFD)
  {
    $prod = "oracleafd";
  }
  elsif ($USM_CURRENT_PROD eq USM_PROD_OLFS)
  {
    $prod = "oracleolfs";
  }
  else
  {
    $prod = "oracleoks";
  }

  # OSD handling
  if ($Config{osname} =~ /Win/)
  {
    return (lib_osds_get_drivers_version);
  }
  elsif ($Config{osname} =~ /aix/)
  {
    $kernelvers = `oslevel -s`;
    $oskvers = $kernelvers;
    chomp($kernelvers);
    $driver  = $prod.".ext ";
    $drvpath[0]= "/usr/lib/drivers/".$driver;
    $drvpath[1] = lib_osds_get_home_driver_path($_ORACLE_HOME."/usm".
                "/install", lib_osds_get_os_type(undef), `uname -p`);
  }
  elsif ($Config{osname} =~ /sol/)
  {
    my ($kver) = `uname -s`;
    chomp($kver);
    $oskvers = `uname -r`;
    $kernelvers = $kver . " " . $oskvers;
    chomp($kernelvers);
    $driver  = $prod;
    open($fhandle, "find /usr/kernel/drv/`isainfo -k`/ | grep $driver |");
    $drvpath[0]= <$fhandle>;
    close($fhandle);
    $drvpath[1] = lib_osds_get_home_driver_path ($_ORACLE_HOME."/usm".
                  "/install", `uname -r`, `isainfo -k`);
  }
  else
  {
    $oskvers = `uname -r`;
    $driver = $prod.".ko";
    open($fhandle, "find /lib/modules/ -type f | grep $driver |");
    $drvpath[0] = <$fhandle>;
    close($fhandle);
    $drvpath[1] = lib_osds_get_home_driver_path ("${_ORACLE_HOME}/usm/install",
                  lib_osds_get_os_type(undef), `uname -i`, $oskvers, undef);
  }
  # Uncompress oracle_home driver files
  lib_uncompress_all_driver_files($drvpath[1]);
  $drvpath[1] .= "/$driver";
  chomp ($drvpath[1]);

  if (defined $kernelvers)
  {
    $drvdata{$type}{"KERNVERS"} = $kernelvers;
    $drvdata{"Available"}{"KERNVERS"} = $kernelvers;
  }
  if (defined $oskvers)
  {
    $drvdata{"OS"}{"KERNVERS"} = $oskvers;
  }

  return undef if (! defined $drvpath[0] || ! defined $drvpath[1] ||
                   ! defined $driver);

  foreach $driver (@drvpath)
  {
    open ($fhandle, "strings $driver |");
    foreach (<$fhandle>)
    {
      if ($_ =~ /vermagic/ && $Config{osname} =~ /lin/)
      {
        # vermagic=2.6.18-8.el5 SMP mod_unload 686 REGPARM 4KSTACKS gcc-4.1
        $drvdata{$type}{"KERNVERS"} = (split(/ /, $_))[0];
        $drvdata{$type}{"KERNVERS"} =~ s/vermagic=//;
      }
      elsif ($_ =~ /USM BUILD LABEL: (\S+)/)
      {
        # The usm_label_info[] global contains:
        # usm_ade_label_info_make_header.pl: USM BUILD LABEL: USM_MAIN_LINUX.X64
        # We don't want to export to the user the label info so we strip
        # that from the driver_version, leaving only the date.
        # so, USM_MAIN_LINUX_090112 becomes 090112.
        @array = split (/_/, $1);
        $drvdata{$type}{"BuildNo"} = $array[3];
      }
      elsif ($_ =~ /TXN BUGS:/)
      {
	# usm_ade_label_info_make_header.pl: TXN BUGS: 1345543,14579183
	$drvdata{$type}{"BugList"} = (split(": ",$_))[-1];
	chomp ($drvdata{$type}{"BugList"});
        if ($drvdata{$type}{"BugList"} =~ /BUGS/)
	{
          $drvdata{$type}{"BugList"} = "NoTransactionInformation";
	}
      }
      elsif ($_ =~ /TXN BUGS HASH:/)
      {
	# usm_ade_label_info_make_header.pl: TXN BUGS HASH: 1345579183
	$drvdata{$type}{"BugHash"}  = (split(": ",$_))[-1];
	chomp ($drvdata{$type}{"BugHash"});
      }
      elsif ($_ =~ /USM VERSION:/)
      {
	#usm_ade_label_info_make_header.pl: USM VERSION: 18.0.0.0.0
	$drvdata{$type}{"Version"}  = (split(": ",$_))[-1];
	chomp ($drvdata{$type}{"Version"});
      }
      elsif ($_ =~ /USM VERSION FULL:/)
      {
	#usm_ade_label_info_make_header.pl: USM VERSION FULL: 18.1.0.0.0
	$drvdata{$type}{"VSNFULL"}  = (split(": ",$_))[-1];
	chomp ($drvdata{$type}{"VSNFULL"});
      }

      # got all of our info?
      if (defined($drvdata{$type}{"BuildNo"})  &&
          defined($drvdata{$type}{"Version"})  &&
          defined($drvdata{$type}{"BugList"})  &&
          defined($drvdata{$type}{"BugHash"})  &&
          defined($drvdata{$type}{"KERNVERS"}) &&
          defined($drvdata{$type}{"VSNFULL"}))
      {
	last; # Go to next driver
      }
    }
    close($fhandle);
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
sub lib_check_config()
{
  if (lib_is_local_container())
  {
    lib_inform_print_noalert(9559, "Running in a local container: %s", "yes");
    return 0;
  }
  if (!lib_osds_check_config())
  {
    return 0;
  }
  return 1;
}

# Check if machine supports ACFS/ADVM drivers
# return true or false
sub lib_check_kernel()
{
   if (!lib_osds_usm_supported() ||
       !lib_osds_check_kernel())
  {
    return 0;
  }
  return 1;
}


1;
