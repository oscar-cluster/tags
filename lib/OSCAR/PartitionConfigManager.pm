package OSCAR::PartitionConfigManager;

#
# Copyright (c) 2007 Oak Ridge National Laboratory.
#                    Geoffroy R. Vallee <valleegr@ornl.gov>
#                    All rights reserved.
#
# This file is part of the OSCAR software package.  For license
# information, see the COPYING file in the top level directory of the
# OSCAR source distribution.
#

#
# $Id$
#

use strict;
use warnings;
use Carp;
use AppConfig;

##########################################################
# A bunch of variable filled up when creating the object #
##########################################################
our $distro;
our $dist_version;
our $arch;
our @opkgs;

sub new {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $self = { 
        config_file => "", 
        @_,
    };
    bless ($self, $class);
    return $self;
}

sub load_config ($) {
    my $self = shift;
    my $config_file = $self->{config_file};

    require AppConfig;

    if (!defined($config_file) || ! -f $config_file) {
        print "ERROR: the configuration file does not exist ($config_file)\n";
        return -1;
    }

    use vars qw($config);
    $config = AppConfig->new(
        'DISTRO'            => { ARGCOUNT => 1 },
        'DISTRO_VERSION'    => { ARGCOUNT => 1 },
        'ARCH'              => { ARGCOUNT => 1 },
        'OPKGS'             => { ARGCOUNT => 1 },
        );
    $config->file ($config_file);

    # Load configuration values
    $distro            = $config->get('DISTRO');
    $dist_version      = $config->get('DISTRO_VERSION');
    $arch              = $config->get('ARCH');
    @opkgs             = split (" ", $config->get('OPKGS'));
}

sub print_config ($) {
    my $self = shift;

    load_config ($self);
    print "Partition Configuration:\n";
    print "\tDistro: $distro\n";
    print "\tDistro version: $dist_version\n";
    print "\tArch: $arch\n";
    print "\tOPKGS: @opkgs\n";
}

sub get_config ($) {
    my $self = shift;

    load_config($self);
    my %cfg = ( 
                'distro'            => $distro,
                'distro_version'    => $dist_version,
                'arch'              => $arch,
                'opkgs'             => \@opkgs,
              );
    return \%cfg;
}

sub set_config ($$) {
    my ($self, $cfg) = @_;

    print "Creating config file ".$self->{config_file}."\n";
    print "$cfg->{'distro'}, $cfg->{'distro_version'}, $cfg->{'arch'}\n";
    open (MYFILE, ">$self->{config_file}");
    print MYFILE "distro\t\t = $cfg->{'distro'}\n";
    print MYFILE "distro_version\t\t = ".$cfg->{'distro_version'}."\n";
    print MYFILE "arch\t\t = $cfg->{'arch'}\n";
    print MYFILE "opkgs\t\t = ";
    my $opkgs = $cfg->{'opkgs'};
    OSCAR::Utils::print_array (@$opkgs);
    for (my $i=0; $i < scalar (@$opkgs); $i++) {
        if ($i != 0) {
            print MYFILE "\t\t\t$$opkgs[$i]";
        } else {
            print MYFILE "\t$$opkgs[$i]";
        }
        print MYFILE " \\ \n" if ($i != scalar (@$opkgs) - 1);
    }
    close (MYFILE);
}

1;

__END__
