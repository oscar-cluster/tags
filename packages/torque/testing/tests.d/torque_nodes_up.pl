#!/usr/bin/perl -w
#############################################################################
###
###   This program is free software; you can redistribute it and/or modify
###   it under the terms of the GNU General Public License as published by
###   the Free Software Foundation; either version 2 of the License, or
###   (at your option) any later version.
###
###   This program is distributed in the hope that it will be useful,
###   but WITHOUT ANY WARRANTY; without even the implied warranty of
###   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
###   GNU General Public License for more details.
###
###   You should have received a copy of the GNU General Public License
###   along with this program; if not, write to the Free Software
###   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
###
###   Copyright (c) 2013-2014 CEA - Commissariat a l'Energie Atomique et
###                            aux Energies Alternatives
###                            All rights reserved.
###   Copyright (C) 2013-2014  Olivier LAHAYE <olivier.lahaye@cea.fr>
###                            All rights reserved.
###
### $Id: $
###
###############################################################################

use strict;
use warnings;
use Carp;
use Data::Dumper;
use OSCAR::Package;
use OSCAR::Database;

BEGIN {
    if (defined $ENV{OSCAR_HOME}) {
        unshift @INC, "$ENV{OSCAR_HOME}/lib";
    }
}

my $pbsnodes_bin;
if (-x '/usr/bin/pbsnodes') {
   $pbsnodes_bin='/usr/bin/pbsnodes';
} else {
   $pbsnodes_bin='/opt/pbs/bin/pbsnodes';
}

my %options = ();
my @errors = ();
my @sis_nodes = ();
my @client_nodes = ();

# Prepare to check if head must be counted as a compute node.
my $configvalues = getConfigurationValues('torque');
my $compute_on_head = ($configvalues->{compute_on_head}[0]);

my $rc = 0;

open PBSNODES, "${pbsnodes_bin} |"
    or (carp "ERROR: Could not run: $!", return 255);

# Loop on sis nodes and check that pbs_knows it.
# FIXME: need to handle the $compute_on_head.

my @pbs_nodes = ();
while (my $line = <PBSNODES>) {
    chomp $line;
    next if ($line =~ /^\s*$/);
    # FIXME: need better regexp for hostname match.
    if ( $line =~ /^[a-zA-Z0-9]+$/) {
        push(@pbs_nodes , $line);
    }
}
close PBSNODES;

get_client_nodes(\@client_nodes,\%options,\@errors);
# FIXME: Need to check that the above command succeed. (it can fail if db is down).

foreach my $client_ref (@client_nodes){
    my $node_name = $$client_ref{name};
    push @sis_nodes, $node_name;
}

for my $node (@sis_nodes) {
    next if ($node ~~ @pbs_nodes);
    print("ERROR: $node is not seen by torque server.\n");
    exit 1;
}

exit 0;