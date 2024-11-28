#
#
# afdlib.pm
# 
# Copyright (c) 2007, 2021, Oracle and/or its affiliates. 
#
#
#    NAME
#      afdlib.pm - Common (non platform specific) functions used by
#                  the install/runtime scripts. (for OKA)
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
use acfslib;
package afdlib;
require Exporter;

our @ISA = qw(Exporter);
our @EXPORT = qw(
                 afdlib_control_devices_accessible
                 lib_check_afd_drivers_installed
                 lib_check_any_afd_driver_installed
                 lib_check_afd_drivers_loaded
                 lib_count_afd_drivers_loaded
                 lib_afd_supported
                 lib_asmlib_installed
                 lib_verify_afd_devices
                 lib_load_afd_drivers
                 lib_unload_afd_drivers
                 lib_afd_post_load_setup
                 lib_afd_delete_oracleafd_disks
                 AFD_CONF_PATH
                 AFD_IDX
                );

use DBI;
use acfslib;
use osds_afdlib;
use osds_acfslib;
use File::Spec::Functions;

my ($ADE_VIEW_ROOT) = $ENV{ADE_VIEW_ROOT};
my ($ORACLE_HOME) = $ENV{ORACLE_HOME};
my ($ORA_CRS_HOME) = $ENV{ORA_CRS_HOME};

# set the product global variable to AFD
$acfslib::USM_CURRENT_PROD = USM_PROD_AFD;

use Config;
my ($OSNAME) = $Config{osname};
chomp($OSNAME);

# lib_control_devices_accessible
# 
# call into control_devices_accessible
#
sub afdlib_control_devices_accessible
{
  return lib_osds_afd_control_devices_accessible();
} # end afdlib_control_devices_accessible

#
# lib_check_afd_drivers_installed
#
sub lib_check_afd_drivers_installed
{
  my ($driver);
  my ($num_drivers_installed) = 0;
  my ($chk_driver) = 0;
  foreach $driver ($AFD_DRIVER_COMPONENTS[AFD_IDX])
  {
    if($VERBOSE)
    {
      lib_inform_print(9155, "Checking for existing '%s' driver " .
                 "installation.", 
                 $driver);
    }
    $chk_driver = lib_osds_check_driver_installed($driver);
    if (!defined ($chk_driver))
    {
      ($chk_driver) = 0;
    }

    if ($chk_driver == 1)
    {
      $num_drivers_installed++;
    }
  }
  if ($num_drivers_installed != 1)
  {
    return 0;
  }
  return 1;
} # end lib_check_afd_drivers_installed

# lib_check_any_afd_driver_installed
#
sub lib_check_any_afd_driver_installed
{
  my ($driver);

  foreach $driver ($AFD_DRIVER_COMPONENTS[AFD_IDX])
  {
    if($VERBOSE)
    {
      lib_inform_print(9155, "Checking for existing '%s' driver " .
                 "installation.", 
                 $driver);
    }
    if (lib_osds_check_driver_installed($driver))
    {
      return 1;
    }
  }

  return 0;

} # end lib_check_any_afd_driver_installed

# lib_count_afd_drivers_loaded
#
sub lib_count_afd_drivers_loaded
{
  my ($driver);
  my ($num_drivers_loaded) = 0;

  foreach $driver ($AFD_DRIVER_COMPONENTS[AFD_IDX])
  {
    if (lib_osds_check_driver_loaded($driver))
    {
      $num_drivers_loaded++;
    }
  }

  return $num_drivers_loaded;
} # end lib_count_afd_drivers_loaded

# lib_check_afd_drivers_loaded
#
sub lib_check_afd_drivers_loaded
{
  my ($num_drivers_loaded) = 0;
  my ($return_val);

  $num_drivers_loaded = lib_count_afd_drivers_loaded();

  if ($num_drivers_loaded != 1)
  {
    $return_val = 0;
  }
  else
  {
    $return_val = 1;
  }

  return $return_val;
} # end lib_check_afd_drivers_loaded

# lib_load_afd_drivers
#
# Load the drivers if not already loaded. Silently ignore if a driver is loaded
# 
sub lib_load_afd_drivers
{
  my ($driver);
  my (@loaded);
  my ($idx);

  # determine which drivers are already loaded (if any).
  foreach $idx (AFD_IDX)
  {
    $driver = $AFD_DRIVER_COMPONENTS[$idx];
    $loaded[$idx] = 0;
    if (lib_osds_check_driver_loaded($driver))
    {
      $loaded[$idx] = 1;
    }
  }

  # Load the not already loaded drivers.
  foreach $idx (AFD_IDX)
  {
    if (!$loaded[$idx])
    {
      my ($return_val);
      $driver = $AFD_DRIVER_COMPONENTS[$idx];
      
      lib_inform_print(9154, "Loading '%s' driver.", $driver);
      $return_val = lib_osds_afd_load_driver($driver, $COMMAND);
      if ($return_val == USM_FAIL)
      {
        lib_error_print(9109, "%s driver failed to load.", $driver);
        return USM_FAIL;
      }
    }
  }
 
  return USM_SUCCESS;
} # end lib_load_afd_drivers

# lib_unload_afd_drivers
#
# Unload the AFD drivers. Return error if any driver fails to unload.
#
sub lib_unload_afd_drivers
{
  # Optional argument: location of new install files.  Utilities from new
  # install files may be used to unload drivers if old utilities cannot be
  # found
  my ($install_files_loc, $sub_command) = @_;

  my ($driver);
  my ($return_val) = USM_SUCCESS;

  foreach $driver ($AFD_DRIVER_COMPONENTS[AFD_IDX])
  {
    # nothing to do if the driver is not loaded
    if (lib_osds_check_driver_loaded($driver))
    {
      # test to see that the driver is not being used
      if (lib_osds_check_driver_inuse($driver))
      {
        lib_error_print (9118, "Driver %s in use - cannot unload.", $driver);

        # If this is 'afdroot install', we pretend to succeed.
        # This way the new drivers get installed but we exit with
        # USM_REBOOT_RECOMMENDED. After the reboot, the new drivers are running.
        if (($COMMAND eq "afdroot") && ($sub_command eq "install"))
        {
          $return_val = USM_SUCCESS;
        }
        else
        {
          $return_val = USM_FAIL;
          last;
        }
      }

      $return_val = lib_osds_afd_unload_driver($driver, $install_files_loc);
      if ($return_val != USM_SUCCESS)
      {
        lib_error_print(9119, "Driver %s failed to unload.", $driver);
        $return_val = USM_REBOOT_RECOMMENDED;
        last;
      }
    }
  }

  return $return_val;
} # end lib_unload_afd_drivers

# lib_afd_supported
# 
# call into lib_osds_afd_supported
#
sub lib_afd_supported
{
  return lib_osds_afd_supported();
} # end lib_afd_supported

# lib_asmlib_installed
#
# call into lib_osds_asmlib_installed
#
sub lib_asmlib_installed
{
  return lib_osds_asmlib_installed();
}

# lib_verify_afd_devices
# 
# call into lib_osds_verify_afd_devices
#
sub lib_verify_afd_devices
{
  return lib_osds_afd_verify_devices();
} # end lib_verify_afd_devices

# lib_afd_post_load_setup
# 
# call into lib_osds_afd_post_load_setup
#
sub lib_afd_post_load_setup
{
  return lib_osds_afd_post_load_setup();
} # end lib_afd_post_load_setup

# lib_afd_delete_oracleafd_disks
# 
# call into lib_osds_afd_delete_oracleafd_disks
#
sub lib_afd_delete_oracleafd_disks
{
  return lib_osds_afd_delete_oracleafd_disks();
} # end lib_afd_delete_oracleafd_disks

###########################################
######## Local only static routines #######
###########################################

1;
