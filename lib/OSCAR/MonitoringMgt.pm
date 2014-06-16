package OSCAR::MonitoringMgt;

# Copyright (c) 2014 CEA (Commissariat A l'Energie Atomique et aux Energies Alternatives)
#                    Olivier Lahaye <olivier.lahaye@cea.fr>
#                    All rights reserved
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# This package provides a set of functions for the management of Naemon monitoring systems
# (nagios fork)
#

#
# $Id: MonitoringMgt.pm 00000 2014-06-16 18:51:37Z olahaye74 $
#

BEGIN {
    if (defined $ENV{OSCAR_HOME}) {
        unshift @INC, "$ENV{OSCAR_HOME}/lib";
    }
}

use strict;
use OSCAR::Logger;
use OSCAR::LoggerDefs;
use OSCAR::OCA::OS_Settings;
use OSCAR::SystemServicesDefs;
use OSCAR::Utils;
use File::Basename;
use Carp;
use v5.10.1;
use Switch 'Perl5', 'Perl6';
# Avoid smartmatch warnings when using given
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use vars qw(@EXPORT);
use base qw(Exporter);

@EXPORT = qw (
             write_oscar_contacts_cfg
             write_oscar_commands_cfg
             write_oscar_service_cfg
             write_oscar_hosts_cfg
             );

=encoding utf8

=head1 NAME

OSCAR::MonitoringMgt -- Naemon/Nagios configuration file generation

=head1 SYNOPSIS

use OSCAR::MonitoringMgt;

=head1 DESCRIPTION

This module provides a collection of fuctions to write naemon configuration
files.

=head2 Functions

=over 4

=cut
###############################################################################
=item write_oscar_contacts_cfg (%contacts)

Write the contacts.cfg file and the contact groups.

Exported: YES

=cut 
###############################################################################

sub write_oscar_contacts_cfg (%) {
    my %contacts = shift;

    return 0;
}

###############################################################################
=item write_oscar_commands_cfg($command_name, command_line)

Write an oscar command file in the following format:

# '$command_name' command definition
define command {
  command_name                   $command_name
  command_line                   $command_line
}

Exported: YES

=cut
###############################################################################

sub write_oscar_commands_cfg ($$) {
    my ($command_name,$command_line) = @_;

    return 0;
}

###############################################################################
=item write_oscar_service_cfg($service_description,$hostgroup_name,$check_command)

Write an oscar command file in the following format:

# '$service_description' service definition
define service {
  service_description            $service_description
  hostgroup_name                 $hostgroup_name
  use                            local-service
  check_command                  $check_command
}

Exported: YES

=cut
###############################################################################

sub write_oscar_service_cfg ($$$) {
    my ($service_description,$hostgroup_name,$check_command) = @_;

    return 0;
}


###############################################################################
=item write_oscar_hosts_cfg($server,@nodename)

Write an oscar host file in the following format:

define host {
  host_name                      $nodename
  alias                          oscarnode#
  address                        @IP
  use                            linux-server
  notification_period            24x7
}

Exported: YES

=cut
###############################################################################

sub write_oscar_hosts_cfg ($@) {
    my $server = shift;
    my @nodename = @_;

    return 0;
}



=back

=head1 TO DO

 * Effectively write the functions


=head1 AUTHORS
    (c) 2014 Olivier Lahaye C<< <olivier.lahaye@cea.fr> >>
             CEA (Commissariat A l'Energie Atomique et aux Energie Alternatives)
             All rights reserved

=head1 LICENSE
This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=cut

1;

__END__
