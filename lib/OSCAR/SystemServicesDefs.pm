package OSCAR::SystemServicesDefs;

# $Id$
#
# Copyright (c) 2008-2009 Geoffroy Vallee <valleegr@ornl.gov>
#                         Oak Ridge National Laboratory.
#                         All rights reserved.

use strict;
use base qw(Exporter);

# TODO: we do not deal with the case where a service is not disabled/enabled
# for all 2, 3, 4, and 5 runlevels.
use constant SERVICE_DISABLED => 0;
use constant SERVICE_ENABLED  => 1;

# List of supported services
use constant DHCP           => 'dhcp';
use constant EXIM           => 'exim';
use constant GANGLIA_GMOND  => 'gmond';
use constant GANGLIA_GMETAD => 'gmetad';
use constant HTTP           => 'http';
use constant JOBARCHIVE     => 'jobarchive';
use constant JOBMONITOR     => 'jobmonitor';
use constant MAUI           => 'maui';
use constant MYSQL          => 'mysql';
use constant NFS            => 'nfs';
use constant NTP            => 'ntp';
use constant POSTFIX        => 'postfix';
use constant POSTGRESQL     => 'postgresql';
use constant RPC            => 'rpc';
use constant TFTP           => 'tftp';
use constant SENDMAIL       => 'sendmail';
use constant SI_MONITOR     => 'monitor';
use constant SI_RSYNC       => 'rsync';
use constant SI_FLAMETHROWER => 'flamethrower';
use constant SI_BITTORRENT  => 'bittorrent';
use constant SSH            => 'ssh';
use constant SYSLOG         => 'syslog';
use constant XINETD         => 'xinetd';

# List of actions related to system services
use constant START      => 0;
use constant STOP       => 1;
use constant RESTART    => 2;
use constant STATUS     => 3;
use constant RELOAD     => 4;

# List of service status
use constant STARTED    => 0;
use constant STOPPED    => 1;

my @ISA = qw(Exporter);

our @EXPORT = qw(
                SERVICE_DISABLED
                SERVICE_ENABLED
                SSH
                DHCP
                EXIM
                GANGLIA_GMOND
                GANGLIA_GMETAD
                HTTP
                JOBARCHIVE
                JOBMONITOR
                MAUI
                MYSQL
                NFS
                NTP
                POSTGRESQL
                POSTFIX
                RPC
                SI_MONITOR
                SI_RSYNC
                SI_FLAMETHROWER
                SI_BITTORRENT
                START
                STOP
                SYSLOG
                TFTP
                RESTART
                RELOAD
                SENDMAIL
                STATUS
                STARTED
                STOPPED
                XINETD
                );

1;
