#!/usr/bin/env perl
#
# Copyright (c) 2005 The Trustees of Indiana University.  
#                    All rights reserved.
# Copyright (c) 2005 Bernard Li <bli@bcgsc.ca>
#                    All rights reserved.
# 
# This file is part of the OSCAR software package.  For license
# information, see the COPYING file in the top level directory of the
# OSCAR source distribution.
#
# $HEADER$
#

package OCA::OS_Detect::Fedora;

use strict;
use POSIX;
use Config;

# This is the logic that determines whether this component can be
# loaded or not -- i.e., whether we're on a Fedora machine or not.

# Check uname

my ($sysname, $nodename, $release, $version, $machine) = POSIX::uname();

# We only support Linux -- if we're not Linux, then quit

return 0 if ("Linux" ne $sysname);

my $redhat_release;
my $fc_release;

# If /etc/redhat-release exists, continue, otherwise, quit.

if (-e "/etc/redhat-release") {
	$redhat_release = `cat /etc/redhat-release`;
} else {
	return 0;
}

# We only support Fedora Core 2 and 3, otherwise quit.

if ($redhat_release =~ 'Stentz') {
	$fc_release = 4;
} elsif ($redhat_release =~ 'Heidelberg') {
	$fc_release = 3;
} elsif ($redhat_release =~ 'Tettnang') {
	$fc_release = 2;
} else {
	return 0;
}

# First set of data

our $id = {
    os => "linux",
    arch => $machine,
    os_release => $release,
    linux_distro => "fedora",
    linux_distro_version => $fc_release
};

# Make final string

$id->{ident} = "$id->{os}-$id->{arch}-$id->{os_release}-$id->{linux_distro}-$id->{linux_distro_version}";

# Once all this has been setup, whenever someone invokes the "query"
# method on this component, we just return the pre-setup data.

sub query {
    our $id;
    return $id;
}

# If we got here, we're happy

1;
