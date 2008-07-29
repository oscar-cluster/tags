package OSCAR::ConfigManager;

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
# The file is the implementation of the ConfigManager class. This class allows
# the creation of object that represents the content of the OSCAR configuration
# file
#

#
# TODO: the current implementation only grabs few information from the 
# configuration file and therefore we do not have a generic API to access each
# different values. That could be improved in order to avoid an uncontroled
# growing the list of functions in the API.
#

#
# $Id$
#

use strict;
use warnings;
use Carp;

##########################################################
# A bunch of variable filled up with creating the object #
##########################################################
# Specify where Packman is
our $packman_path;
# Specify where rapt is
our $rapt_path;
# Specify where rapt is
our $yume_path;
# Specify where the prereqs are
our $prereqs_path;
# Specify the network interface used by OSCAR
our $nioscar;
# Specify where the OSCAR scripts are
our $oscarbinaries_path;
# Specify the db type (flat files or real db)
our $db_type;
# Specify the prereq management mode.
our $prereq_mode;
# Specify where the OPKGs are.
our $opkgs_path;
# Specify where ODA flat config file are (i.e., when not using ODA w/ a real db
our $oda_files_path;

sub new {
    my $invocant = shift;
    my $class = ref($invocant) || $invocant;
    my $self = { 
        config_file => "/etc/oscar/oscar.conf", 
        @_,
    };
    bless ($self, $class);
    load_oscar_config ($self);
    return $self;
}

sub load_oscar_config ($) {
    my $self = shift;
    my $config_file = $self->{config_file};

    require AppConfig;

    if (!defined($config_file) || ! -f $config_file) {
        print "ERROR: the configuration file does not exist ($config_file)\n";
        return -1;
    }

    use vars qw($config);
    $config = AppConfig->new(
        'OSCAR_NETWORK_INTERFACE'   => { ARGCOUNT => 1 },
        'OSCAR_SCRIPTS_PATH'        => { ARGCOUNT => 1 },
        'PREREQS_PATH'              => { ARGCOUNT => 1 },
        'RAPT_PATH'                 => { ARGCOUNT => 1 },
        'YUME_PATH'                 => { ARGCOUNT => 1 },
        'ODA_TYPE'                  => { ARGCOUNT => 1 },
        'PREREQ_MODE'               => { ARGCOUNT => 1 },
        'OPKGS_PATH'                => { ARGCOUNT => 1 },
        'PATH_ODA_CONFIG_FILES'     => { ARGCOUNT => 1 },
        );
    $config->file ($config_file);

    # Load configuration values
    $rapt_path          = $config->get('RAPT_PATH');
    $yume_path          = $config->get('YUME_PATH');
    $prereqs_path       = $config->get('PREREQS_PATH');
    $packman_path       = $config->get('PREREQS_PATH') . "/packman";
    $nioscar            = $config->get('OSCAR_NETWORK_INTERFACE');
    $oscarbinaries_path = $config->get('OSCAR_SCRIPTS_PATH');
    $db_type            = $config->get('ODA_TYPE');
    $prereq_mode        = $config->get('PREREQ_MODE');
    $oda_files_path     = $config->get('PATH_ODA_CONFIG_FILES');
}

sub get_config () {
    my $self = shift;
    my %cfg = (
                'rapt_path'         => $rapt_path,
                'yume_path'         => $yume_path,
                'prereqs_path'      => $prereqs_path,
                'packman_path'      => $packman_path,
                'nioscar'           => $nioscar,
                'binaries_path'     => $oscarbinaries_path,
                'db_type'           => $db_type,
                'prereq_mode'       => $prereq_mode,
                'oda_files_path'    => $oda_files_path,
              );
    return \%cfg;
}

################################################################################
#                            ODA RELATED FUNCTIONS                             #
# The following functions are used when using ODA in flat text file mode. It   #
# allows one to find the path of the different configuration files, i.e.,      #
# configuration files for clusters, partitions, and compute nodes.             #
################################################################################

sub get_cluster_config_file_path ($) {
    my ($self, $cluster) = @_;
    if (defined ($cluster) && $cluster ne "") {
        return "$oda_files_path/$cluster";
    } else {
        carp "ERROR: Invalid cluster name ($cluster)\n";
        return undef;
    }
}

sub get_partition_config_file_path ($$) {
    my ($self, $cluster, $partition) = @_;

    # Some sanity checking
    if (!defined ($partition) || $partition eq "") {
        carp "ERROR: Invalid partition name ($partition)\n";
        return undef;
    }

    my $path = $self->get_cluster_config_file_path ($cluster);
    if (defined ($path)) {
        return "$path/$partition";
    } else {
        return undef;
    }
}

sub get_node_config_file_path ($$$) {
    my ($self, $cluster, $partition, $node) = @_;

    # Some sanity checking
    if (!defined ($node) || $node eq "") {
        carp "ERROR: Invalid node name ($node)\n";
        return undef;
    }

    my $path = $self->get_partition_config_file_path ($cluster, $partition);
    if (defined ($path)) {
        return "$path/$node";
    } else {
        return undef;
    }
}

################################################################################
#                          END OF ODA RELATED FUNCTIONS                        #
################################################################################

1;

__END__