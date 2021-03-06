#!/usr/bin/env perl
#
# Copyright (c) 2008 Oak Ridge National Laboratory.
#                    All rights reserved.
#
# This file is part of the OSCAR software package.  For license
# information, see the COPYING file in the top level directory of the
# OSCAR source distribution.
#
# $Id$
#

package OSCAR::OCA::OS_Detect::Ubuntu;

BEGIN {
    if (defined $ENV{OSCAR_HOME}) {
        unshift @INC, "$ENV{OSCAR_HOME}/lib";
    }
}

use strict;
use OSCAR::LSBreleaseParser;

my $DEBUG = 1 if( $ENV{DEBUG_OCA_OS_DETECT} );
my ($deb_ver);

my $detect_pkg  = "base-files"; # Deb pkg containing '/etc/debian_version'
                                # therefore should always be available
                                # and the Version: is always accurate!

my $dpkg_bin = "/usr/bin/dpkg-query"; # Tool to query Deb package Database

# TODO: the following variable should be constants.
my $distro = "ubuntu";
my $compat_distro = "debian";
my $pkg = "deb";
my $detect_package = "base-files";
my $detect_file = "/bin/bash";

my %codenames = (
                '1604'  => "xenial",
                '1510'  => "wily",
                '1504'  => "vivid",
                '1410'  => "utopic",
                '1404'  => "trusty",
                '1310'  => "saucy",
                '1304'  => "raring",
                '1210'  => "quantal",
                '1204'  => "precise",
                '1110'  => "oneiric",
                '1104'  => "natty",
                '1010'  => "maverick",
                '1004'  => "lucid",
                '910'   => "karmic",
                '904'   => "jaunty",
                '810'   => "intrepid",
                '804'   => "hardy",
                '710'   => "gutsy",
                '704'   => "feisty",
                '610'   => "edgy",
                '606'   => "dapper",
                '510'   => "breezy",
                );

my %compat_version_mapping = (
                '1604'  => "8",
                '1510'  => "8",
                '1504'  => "8",
                '1410'  => "8",
                '1404'  => "8",
                '1310'  => "7",
                '1304'  => "7",
                '1210'  => "7",
                '1204'  => "7",
                '1110'  => "7",
                '1104'  => "6",
                '1010'  => "6",
                '1004'  => "6",
                '910'   => "5",
                '904'   => "5",
                '810'   => "4",
                '804'   => "4",
                '710'   => "4",
                '704'   => "4",
                '610'   => "4",
                '606'   => "4",
                '510'   => "4",
                );

#
#  End of all configuration/global variable setup
# 
#---------------------------------------------------------------------



# This routine is cheap and called very rarely, so don't care for
# unnecessary buffering. Simply recalculate $id each time this is
# called.
sub detect_dir {
    my ($root) = @_;
    my $release_string;
    my ($d, $v, $a);

    # There is a trick with Ubuntu systems: they have a non-valid 
    # /etc/debian_version and the ubuntu release data is actually in
    # /etc/lsb-release. So if we get data from this file and if it specifies
    # the system is an Ubuntu system we quit.
    my $distro_id = OSCAR::LSBreleaseParser::parse_lsbrelease("/");
    if (defined ($distro_id) && $distro_id ne "") {
        require OSCAR::PackagePath;
        ($d, $v, $a) = OSCAR::PackagePath::decompose_distro_id ($distro_id);
        if ($d ne "ubuntu") {
            return undef;
        }
    } else {
        return undef;
    }

    my $distro_version = undef;
    my $distro_update = undef;
    if ($v =~ /(\d+)\.(\d+)/) {
        $distro_version = "$1$2";
        $distro_update = undef;
    }
    if (!defined $distro_version) { # || !defined $distro_update) {
        return undef;
    }

    # this hash contains all info necessary for identifying the OS
    my $id = {
        os => "linux",
        chroot => $root,
    };

    # determine architecture
    my $arch = main::OSCAR::OCA::OS_Detect::detect_arch_file($root, $detect_file);
    $id->{arch} = $arch;

    # Limit support to only x86 and x86_64 machines
    if ($arch !~ /^x86_64$|^i686$|^i586$|^i386$/ ) {
        print "OCA::OS_Detect::Debian-";
        print "DEBUG: Failed Architecture support - ($arch)\n\n" if( $DEBUG );
        return undef;
    }

    $id->{distro} = $d;
    $id->{distro_version} = $distro_version;
    $id->{distro_update} = $distro_update;
    $id->{compat_distro} = $compat_distro;
    $id->{compat_distrover} = $compat_version_mapping{$distro_version};
    $id->{pkg} = $pkg;   
    $id->{codename} = $codenames{$distro_version};

    # determine services management subsystem (systemd, initscripts, manual)
    $id->{service_mgt} = "manual";

    # Make final string
    $id->{ident} = "$id->{os}-$id->{arch}-$id->{distro}-$id->{distro_version}";
    $id->{ident} .= $id->{distro_update} if defined $id->{distro_update};
    return $id;
}


# EF: simply copied the function from RedHat.pm, this is why we have common
# routines in OS_Detect, in order to avoid code replication
sub detect_pool {
    my ($pool) = @_;

    my $id = main::OSCAR::OCA::OS_Detect::detect_pool_rpm($pool,
                              $detect_package,
                              $distro,
                              $compat_distro);

    return $id;
}

# EF: simply copied the function from RedHat.pm
sub detect_fake {
    my ($fake) = @_;

    return undef if (!defined $fake);

    # From the parameter, we detect the distro codename and add it in the
    # description of the OS
    my $l_version = $fake->{'distro_version'};
    $fake->{'codename'} = $codenames{$l_version};

    my $id = main::OSCAR::OCA::OS_Detect::detect_fake_common($fake,
                                 $distro,
                                 $compat_distro,
                                 $compat_version_mapping{$l_version},
                                 $pkg);
    return $id;
}

sub detect_oscar_pool ($) {
    my $pool = shift;
    my $ret = main::OSCAR::OCA::OS_Detect::detect_oscar_pool_common($pool,
        $compat_distro);

    if ($ret) {
        # The component can use the OSCAR pool
        my $id = {
            os => "linux",
        };
        $id->{distro} = $distro;
        $id->{pkg} = $pkg;
        return $id;
    } else {
        return undef;
    }
}


# If we got here, we're happy
1;
