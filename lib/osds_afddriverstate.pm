# 
#
# osds_afddriverstate.pm
# 
# Copyright (c) 2013, 2021, Oracle and/or its affiliates. 
#
#    NAME
#      osds_afddriverstate.pm - Windows OSD component of afddriverstate.
#
#    DESCRIPTION
#        Purpose
#            Report if AFD drivers are installed and/or loaded
#        Usage
#            afddriverstate [supported] [installed] [loaded]
#
#    NOTES
#
# 

package osds_afddriverstate;
require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(
                 osds_afd_validate_drivers
                 osds_afd_compatible
                );

use strict;
use Win32;
use File::Spec::Functions;
use acfslib;
use afdlib;
use osds_afdlib;

sub osds_afd_validate_drivers
{
  if (!lib_afd_supported())
  {
    # not supported
    return USM_NOT_SUPPORTED;
  }
  return USM_SUPPORTED;
}

# osds_afd_compatible
#
# Make sure drivers are kabi compatible.
#
sub osds_afd_compatible
{
  my ($result) = USM_SUPPORTED;

  return $result;
} #end osds_afd_compatible

