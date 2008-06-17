package OSCAR::ConfigFile;

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
# This Perl module is a simple abstraction to handle configuration files,
# extending the AppConfig Perl module (typically adding write operations). The
# goal is typically to be able to easily get and set a given key value in a
# given configuration file.

use strict;
use lib "$ENV{OSCAR_HOME}/lib";
use OSCAR::Logger;
use OSCAR::Utils;
use vars qw(@EXPORT);
use base qw(Exporter);
use Carp;
use AppConfig;
use AppConfig::State;
use warnings "all";

@EXPORT = qw(
            get_value
            set_value
            get_all_values
            );

################################################################################
# Get the value of a given key in a given configuration file. For instance,    #
# get_value ("/etc/yum.conf", "gpgkey") returns the value of the key 'gpgkey'  #
# from the /etc/yum.conf configuration file.                                   #
#                                                                              #
# Input: config_file, full path to the configuration file we want to analyse.  #
#        block, configuration files may be arranged in blocks, in that case,   #
#               if you want to access a given key under a given block, specify #
#               the block name here; otherwise, use undef or ""/               #
#               [main]                                                           #
#                  gpgcheck = 1
#        key, key we want the value from. 
# Return: the key value is the key exists, undef if the key does not exist.    #
################################################################################
sub get_value ($$$) {
    my ($config_file, $block, $key) = @_;

    if (!defined($config_file) || ! -f $config_file) {
        carp "ERROR: the configuration file does not exist ($config_file)\n";
        return undef;
    }

    use vars qw($config);
    $config = AppConfig->new({
            CREATE => '^*',
        },
        $key            => { ARGCOUNT => 1 },
        );
    if (!defined ($config)) {
        carp "ERROR: Impossible to parse configuration file ($config_file)";
        return undef;
    }
    $config->file($config_file);

    if (defined ($block) && $block ne "") {
        $key = $block . "_" .$key;
    }

    return $config->get($key);
}

sub get_block_list ($) {
    my $config_file = @_;

    my $list_blocks = `grep '\\[' $config_file`;
    print "List blocks ($config_file): $list_blocks";    
}

sub set_value ($$$$) {
    my ($config_file, $block, $key, $value) = @_;

    if (!defined($config_file) || ! -f $config_file) {
        carp "ERROR: the configuration file does not exist ($config_file)\n";
        return -1;
    }

    use vars qw($config);
    $config = AppConfig->new({
            CREATE => '^*',
        },
        $key            => { ARGCOUNT => 1 },
        );
    if (!defined ($config)) {
        carp "ERROR: Impossible to parse configuration file ($config_file)";
        return -1;
    }
    $config->file($config_file);

    if (defined ($block) && $block ne "") {
        $key = $block . "_" .$key;
    }

    get_block_list ($config_file);

    $config->set($key, $value);

    return 0;
}

################################################################################
# Get the value of all keys from a given configuration file. This function is  #
# based on the get_value function, therefore it means we do not deal with the  #
# key namespace. In other terms, you have to explicitely expand the key name   #
# if the key is part of a section (see example in the get_value function       #
# description).                                                                #
#                                                                              #
# Input: config_file, full path to the configuration file we want to analyse.  #
# Return: a hash with all keys and values, undef if we cannot parse the        #
#         configuration file. For instance, if the configuration file looks    #
#         like:                                                                #
#           var1 = value1                                                      #
#           var2 = value2                                                      #
#         The hash will look like: ( "var1", "value1", "var2", "value2" ).     #
################################################################################
sub get_all_values ($) {
    my ($config_file) = @_;

    if (!defined($config_file) || ! -f $config_file) {
        print "ERROR: the configuration file does not exist ($config_file)\n";
        return -1;
    }

    use vars qw($config);
    $config = AppConfig->new({
            CREATE => '^*',
        },
        );
    $config->file ($config_file);
    my %vars = $config->varlist("^*");
    while ( my ($key, $value) = each(%vars) ) {
        $vars{$key} = get_value ($config_file, undef, $key);
    }
    return %vars;
}

1;
