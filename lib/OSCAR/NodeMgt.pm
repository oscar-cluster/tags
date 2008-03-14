package OSCAR::NodeMgt;

#
# Copyright (c) 2008 Geoffroy Vallee <valleegr@ornl.gov>
#                    Oak Ridge National Laboratory
#                    All rights reserved.
#
#   $Id$
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
# This package provides a set of function for the management of cluster 
# partitions.
#

use strict;
use lib "$ENV{OSCAR_HOME}/lib";
use OSCAR::ConfigManager;
use OSCAR::Logger;
use vars qw(@EXPORT);
use base qw(Exporter);
use Carp;
use warnings "all";

@EXPORT = qw(
            display_node_config
            get_node_config
            set_node_config
            );

my $verbose = $ENV{OSCAR_VERBOSE};
# Where the configuration files are.
our $basedir = "/etc/oscar/clusters";

################################################################################
# Display the configuration for a given node of a given partition of a given   #
# cluster.                                                                     #
#                                                                              #
# Input: cluster_name, name of the target cluster,                             #
#        partition_name, name of the target partition,                         #
#        node_name, name of the node to look for.                              #
# return: a hash representing the node configuration, undef if error.          #
#         Note that a description of the hask is available in                  #
#         OSCAR::NodeConfigManager.                                            #
################################################################################
sub display_node_config ($$$) {
    my ($cluster_name, $partition_name, $node_name) = @_;
    my $node_config;

    # We get the configuration from the OSCAR configuration file.
    my $oscar_configurator = OSCAR::ConfigManager->new();
    if ( ! defined ($oscar_configurator) ) {
        carp "ERROR: Impossible to get the OSCAR configuration.\n";
        return undef;
    }
    my $config = $oscar_configurator->get_config();

    if ($config->{db_type} eq "file") {
        my $path = $oscar_configurator->get_node_config_file_path (
                    $cluster_name,
                    $partition_name,
                    $node_name);
        if ( !defined ($path) || ! -d $path ) {
            carp "ERROR: Undefined node.\n";
            return undef;
        }
        require OSCAR::NodeConfigManager;
        my $config_file = "$path/$node_name.conf";
        if ( ! -f $config_file ) {
            # if the configuration file does not exist, it means that the node
            # has been added to the partition but not yet defined. This is not
            # an error.
            return undef;
        }
        oscar_log_subsection("Parsing node configuration file: $config_file");
        my $config_obj = OSCAR::NodeConfigManager->new(
            config_file => "$config_file");
        if ( ! defined ($config_obj) ) {
            carp "ERROR: Impossible to create an object in order to handle ".
                 "the node configuration file.\n";
            return undef;
        }
        $node_config = $config_obj->get_config();
        if (!defined ($node_config)) {
            carp "ERROR: Impossible to load the node configuration file\n";
            return undef;
        } else {
            $config_obj->print_config();
            if ($node_config->{'type'} eq "virtual") {
                require OSCAR::VMConfigManager;
                my $vm_config_file = "$path/vm.conf";
                my $vm_config_obj = OSCAR::VMConfigManager->new(
                    config_file => "$vm_config_file");
                if ( ! defined ($config_obj) ) {
                    carp "ERROR: Impossible to create an object in order to ".
                         "handle the node configuration file.\n";
                    return undef;
                }
                $vm_config_obj->print_config();
            }
        }
    } elsif ($config->{db_type} eq "db") {
        carp "Real db are not yet supported\n";
        return undef;
    } else {
        carp "ERROR: Unknow ODA type ($config->{db_type})\n";
        return undef;
    }
    return $node_config;
}

################################################################################
# Get the node configuration for a given node of a given partition of a given  #
# cluster.                                                                     #
#                                                                              #
# Input: cluster_name, name of the target cluster,                             #
#        partition_name, name of the target partition,                         #
#        node_name, name of the node to look for.                              #
# return: a hash representing the node configuration, undef if error.          #
#         Note that a description of the hask is available in                  #
#         OSCAR::NodeConfigManager.                                            #
################################################################################
sub get_node_config ($$$) {
    my ($cluster_name, $partition_name, $node_name) = @_;
    my $node_config;

    # We get the configuration from the OSCAR configuration file.
    my $oscar_configurator = OSCAR::ConfigManager->new();
    if ( ! defined ($oscar_configurator) ) {
        carp "ERROR: Impossible to get the OSCAR configuration.\n";
        return undef;
    }
    my $config = $oscar_configurator->get_config();

    if ($config->{db_type} eq "file") {
        my $path = $oscar_configurator->get_node_config_file_path (
                    $cluster_name,
                    $partition_name,
                    $node_name);
        if ( !defined ($path) || ! -d $path ) {
            carp "ERROR: Undefined node.\n";
            return undef;
        }
        require OSCAR::NodeConfigManager;
        my $config_file = "$path/$node_name.conf";
        if ( ! -f $config_file ) {
            # if the configuration file does not exist, it means that the node
            # has been added to the partition but not yet defined. This is not
            # an error.
            return undef;
        }
        oscar_log_subsection("Parsing node configuration file: $config_file");
        my $config_obj = OSCAR::NodeConfigManager->new(
            config_file => "$config_file");
        if ( ! defined ($config_obj) ) {
            carp "ERROR: Impossible to create an object in order to handle ".
                 "the node configuration file.\n";
            return undef;
        }
        $node_config = $config_obj->get_config();
        if (!defined ($node_config)) {
            carp "ERROR: Impossible to load the node configuration file\n";
            return undef;
        } 
    } elsif ($config->{db_type} eq "db") {
        carp "Real db are not yet supported\n";
        return undef;
    } else {
        carp "ERROR: Unknow ODA type ($config->{db_type})\n";
        return undef;
    }
    return $node_config;
}

################################################################################
# Set the configuration of the node. Note that a node is always part of a      #
# cluster and of a partition.                                                  #
#                                                                              #
# Input: cluster, cluster name the node belong to,                             #
#        partition, partition name the node belong to,                         #
#        node_name, node name,                                                 #
#        node_config, a hash representing the node configuration. To know the  #
#                     format of the hash, please refer to                      #
#                     OSCAR::NodeConfigManager.                                #
# Return: 0 if success, -1 else.                                               #
################################################################################
sub set_node_config ($$$$) {
    my ($cluster, $partition, $node_name, $node_config) = @_;

    if ($verbose) {
        oscar_log_section "Saving node configuration...";
        oscar_log_subsection "Cluster: $cluster";
        oscar_log_subsection "Partition: $partition";
        oscar_log_subsection "Node: $node_name";
    }

    # Few asserts to be everything is fine.
    if (!defined ($cluster) || $cluster eq "" ||
        !defined ($partition) || $partition eq "" ||
        !defined ($node_config) || $node_config eq "") {
        carp "ERROR: missing data, impossible to set node configuration\n";
        return -1;
    }
    # We get the configuration from the OSCAR configuration file.
    my $oscar_configurator = OSCAR::ConfigManager->new();
    if ( ! defined ($oscar_configurator) ) {
        carp "ERROR: Impossible to get the OSCAR configuration\n";
        return -1;
    }
    my $config = $oscar_configurator->get_config();

    if ($config->{db_type} eq "file") {
        my $path = $oscar_configurator->get_node_config_file_path (
                    $cluster,
                    $partition,
                    $node_name);
        if ( ! -d $path ) {
            carp "ERROR: Undefined node\n";
            return -1;
        }
        require OSCAR::NodeConfigManager;
        my $config_file = "$path/$node_name.conf";
        my $config_obj = OSCAR::NodeConfigManager->new(
            config_file => "$config_file");
        if ( ! defined ($config_obj) ) {
            carp "ERROR: Impossible to create an object in order to handle ".
                 "the node configuration file.\n";
            return -1;
        }
        $config_obj->set_config($node_config);
    } elsif ($config->{db_type} eq "db") {
        carp "Real db are not yet supported\n";
        return -1;
    } else {
        carp "ERROR: Unknow ODA type ($config->{db_type})\n";
        return -1;
    }
    return 0;
}

1;
