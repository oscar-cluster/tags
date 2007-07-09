package OSCAR::Opkg;

# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
#
# (C)opyright Bernard Li <bli@bcgsc.ca>.
#             All Rights Reserved.
#
# (C)opyright Oak Ridge National Laboratory
#             Geoffroy Vallee <valleegr@ornl.gov>
#             All rights reserved
#
# $Id: Opkg.pm 5884 2007-06-08 07:35:50Z valleegr $
#
# OSCAR Package module
#
# This package contains subroutines for common operations related to
# the handling of OSCAR Packages (opkg)

use strict;
use lib "$ENV{OSCAR_HOME}/lib";
use vars qw(@EXPORT);
use base qw(Exporter);
use File::Basename;
use Carp;

@EXPORT = qw(
            get_list_opkg_dirs
            opkg_print
            opkgs_install_server
            );

my $verbose = $ENV{OSCAR_VERBOSE};

# name of OSCAR Package
my $opkg = basename($ENV{OSCAR_PACKAGE_HOME}) if defined ($ENV{OSCAR_PACKAGE_HOME});

# location of OPKGs shipped with OSCAR
my $opkg_dir = $ENV{OSCAR_HOME} . "/packages";

# Prefix print statements with "[package name]" 
sub opkg_print {
	my $string = shift;
	print("[$opkg] $string");
}

###############################################################################
# Get the list of OPKG available in $(OSCAR_HOME)/packages                    #
# Parameter: None.                                                            #
# Return:    Array of OPKG names.                                             #
###############################################################################
sub get_list_opkg_dirs {
    my @opkgs = ();
    die ("ERROR: The OPKG directory does not exist ".
        "($opkg_dir)") if ( ! -d $opkg_dir );

    opendir (DIRHANDLER, "$opkg_dir")
        or die ("ERROR: Impossible to open $opkg_dir");
    foreach my $dir (sort readdir(DIRHANDLER)) {
        if ($dir ne "." && $dir ne ".." && $dir ne ".svn" 
            && $dir ne "package.dtd") {
            push (@opkgs, $dir);
        }
    }
    return @opkgs;
}

###############################################################################
# Install the server part of a given OPKG on the local system                 #
# Parameter: list of OPKGs.                                                   #
# Return:    none.                                                            #
###############################################################################
sub opkg_install_server {
    my ($opkg) = @_;

    if ($opkg eq "") {
        print "ERROR: no OPKG name, OPKG install abort";
        exit 1;
    }

    #
    # Detect OS of master node.
    #
    # Fails HERE if distro is not supported!
    #
    my $os = &OSCAR::PackagePath::distro_detect_or_die();

    #
    # Locate package pools and create the directories if they don't exist, yet.
    #
    my $oscar_pkg_pool = &OSCAR::PackagePath::oscar_repo_url(os=>$os);
    my $distro_pkg_pool = &OSCAR::PackagePath::distro_repo_url(os=>$os);

    # The code below should migrate into a package. It is used in
    # install_prereq in exactly the same way. Maybe to OSCAR::PackageSmart...?
    # [EF]
    eval("require OSCAR::PackMan");
    my $pm = OSCAR::PackageSmart::prepare_pools(($verbose?1:0),
                        $oscar_pkg_pool,$distro_pkg_pool);
    if (!$pm) {
        croak "\nERROR: Could not create PackMan instance!\n";
    }
    my $pkg = "opkg-" . $opkg . "-server";
    my ($err, @out) = $pm->smart_install($pkg);
    if (!$err) {
        print "Error occured during smart_install:\n";
        print join("\n",@out)."\n";
        exit 1;
    }
}

###############################################################################
# Install the server part of a list of OPKGs on the local system              #
# Parameter: list of OPKGs.                                                   #
# Return:    none.                                                            #
###############################################################################
sub opkgs_install_server {
    my (@opkgs) = @_;

    foreach my $opkg (@opkgs) {
        opkg_install_server ($opkg);
    }
}

1;
