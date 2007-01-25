package OSCAR::MAC;

# Copyright (c) 2004 	The Board of Trustees of the University of Illinois.
#                     	All rights reserved.
#			Jason Brechin <brechin@ncsa.uiuc.edu>
# Copyright (C) 2006 Bernard Li <bli@bcgsc.ca>
#                    All rights reserved.
# Copyright (C) 2006 Oak Ridge National Laboratory
#                    Geoffroy Vallee <valleegr@ornl.gov>
#                    All rights reserved.

#   $Id$

#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; either version 2 of the License, or
#   (at your option) any later version.
 
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
 
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

use strict;
use lib "$ENV{OSCAR_HOME}/lib";
use File::Copy;
use SIS::Adapter;
use SIS::Client;
use SIS::DB;
use SIS::Image;
use OSCAR::Network;

use Carp;
use OSCAR::Logger;
use OSCAR::Database;
use OSCAR::OCA::OS_Detect;
use vars qw($VERSION @EXPORT);
#use base qw(Exporter);
require Exporter;

$VERSION = sprintf("r%d", q$Revision$ =~ /(\d+)/);

# %MAC = (
#                   'macaddr' => {client => 'clientname', order => 'order collected'}
#                 );
#                 client will be client name or undef for unassigned
#                 order will be a number

our %MAC = (); # mac will be -1 for unknown, machine name for known

our @SERVERMACS;     # a variable which stores a regex of the server mac addreses
my $ORDER = 1;      # global count variable
our $COLLECT = 0;    # are we collecting or not?
our $PINGPID = undef; # process id of the ping fork we make
our $step_number;    # which step number of the oscar process we are in

our $startcoll = "Start Collecting MACs";
our $stopcoll = "Stop Collecting MACs";

our $kernel;
our $ramdisk;
our $install_mode;
our $uyok = 0; # UYOK not enabled by default

our @install_mode_options = qw(systemimager-rsync
                              systemimager-multicast 
                              systemimager-bt);

@EXPORT = qw (  save_to_file
                load_from_file
                start_mac_collect
                stop_mac_collect
                sortclients
                populate_MACS
                start_ping
                end_ping
                set_servermacs
                add_mac_to_hash
                run_cmd
                generate_uyok
                __setup_dhcpd
                __end_collect_mac
                __load_macs
                __build_autoinstall_cd
                __enable_install_mode
                __run_setup_pxe
                %MAC
                $COLLECT
                @SERVERMACS
                @install_mode_options
                $step_number
                $startcoll
                $stopcoll
                $install_mode
             );

# Subroutines below here...

our $os = OSCAR::OCA::OS_Detect::open();
sub sortclients;

sub __setup_dhcpd {
    my $interface = shift;
    our $window;
    our $install_mode;
    our $os;

    oscar_log_subsection("Step $step_number: cleaning hostfile");
    clean_hostsfile() or (carp "Couldn't clean hosts file!",
                          return undef);
    
    my $dhcpd_configfile = "/etc/dhcpd.conf";
    # Under Debian the dhcpd config file is in /etc/dhcp3
    $dhcpd_configfile = "/etc/dhcp3/dhcpd.conf" if -x "/etc/dhcp3";
    carp "About to run setup_dhcpd";
    if(-e $dhcpd_configfile) {
        copy($dhcpd_configfile, $dhcpd_configfile.".oscarbak") or (carp "Couldn't backup dhcpd.conf file", return undef);
    }
    my ($ip, $broadcast, $netmask) = interface2ip($interface);
    my $cmd = "mkdhcpconf -o $dhcpd_configfile --interface=$interface --gateway=$ip";

    if ($install_mode eq "systemimager-multicast"){
       $cmd = $cmd . " --multicast=yes";
    }

    oscar_log_subsection("Step $step_number: Running command: $cmd");
    !system($cmd) or (carp "Couldn't mkdhcpconf", return undef);
    oscar_log_subsection("Step $step_number: Successfully ran command");

    my $dhcpd_leases = "/var/lib/dhcp/dhcpd.leases";

    # Fedora Core 5's dhcpd.leases file is located in a slightly different
    # directory
    if ( ($os->{'distro'} eq "fedora") && ($os->{'distro_version'} == "5") ) {
        $dhcpd_leases = "/var/lib/dhcpd/dhcpd.leases";
    }

    if(!-e "$dhcpd_leases") {
        open(OUT,">$dhcpd_leases") or (carp "Couldn't create dhcpd.leases files", return undef);
        close(OUT);
    }

    # Need to setup /etc/sysconfig/dhcpd on SUSE Linux prior to restarting dhcpd
    if ($os->{'distro'} eq "suse") {
        my $dhcpd_file = "/etc/sysconfig/dhcpd";
        run_cmd("/bin/mv -f $dhcpd_file $dhcpd_file.oscarbak");

        $cmd = "sed -e 's/^DHCPD_INTERFACE=\".*\"/DHCPD_INTERFACE=\"$interface\"/g' $dhcpd_file.oscarbak > $dhcpd_file";     
        if (system($cmd)) {
            carp("Failed to update $dhcpd_file");
            return 1;
        }
    }

    my $dhcpd = "dhcpd";
    # Under Debian the init script for dhcp is "dhcp3-server"
    $dhcpd = "dhcp3-server" if -x "/etc/init.d/dhcp3-server";
    oscar_log_subsection("Step $step_number: Restarting dhcpd service");
    !system("/etc/init.d/$dhcpd restart") or (carp "Couldn't restart $dhcpd", 
                                         return undef);
    oscar_log_subsection("Step $step_number: Successfully restarted dhcpd service");
    return 1;
}

sub clean_hostsfile {
    my $file = "/var/lib/systemimager/scripts/hosts";
    copy($file, "$file.bak") or (carp "Couldn't backup rsyncable hosts file!",
                                 and return undef);
    open(IN,"<$file.bak") or (carp "Couldn't open $file.bak for reading!",
                                 and return undef);
    open(OUT,">$file") or (carp "Couldn't open $file for writing!",
                                 and return undef);
    while(<IN>) {
        if(/^\#/) {
            print OUT $_;
        }elsif(/^([\d+\.]+).*\s([^\s\.]+)\s/) {
            print OUT "$1     $2\n";
        }
    }
    close(OUT);
    close(IN);
}
 
# Use Schwartzian transform to sort clients by node names alphabetically and numerically.
# Names w/o numeric suffix precede those with numeric suffix.
sub sortclients(@) {
	return map { $_->[0] }
	       sort { $a->[1] cmp $b->[1] || ($a->[2]||-1) <=> ($b->[2]||-1) }
	       map { [$_, $_->name =~ /^([\D]+)([\d]*)$/] }
	       @_;
}

# populates existing MAC entries into the global hash

sub populate_MACS {
    my @clients = sortclients list_client();
    %MAC = ();
    foreach my $client (@clients) {
        my $adapter = list_adapter(client=>$client->name,devname=>"eth0");
        if ($adapter->mac) {
                add_mac_to_hash($adapter->mac, $client->name);
        }
    }
}

# Ok, here is the problem.  This whole thing works great on a network with
# a bunch of traffic.  It sucks on a quiet one.  So when we start up the
# tcpdump command we also fork a broadcast ping to generate more
# traffic on the network.

sub start_ping {
    my $interface = shift;
    end_ping();
    my ($ip, $broad, $nm) = interface2ip($interface);
    my $pid = fork();

    if($pid) {
        $PINGPID = $pid;
    } else {
        oscar_log_subsection("Step $step_number: Launching background ping");
        open(STDOUT,">/dev/null");
        my $cmd = "ping -b $broad";
        exec("$cmd") or die("Failed to exec: $cmd");
        exit 0;
    }
}

sub end_ping {
    if($PINGPID) {
        print "Attempting to kill $PINGPID\n";
        kill 15, $PINGPID;
        $PINGPID = undef;
        wait();
        oscar_log_subsection("Step $step_number: Background ping stopped");
    }
}

sub __end_collect_mac {
    system("killall tcpdump");
}

sub save_to_file {
    my $file = shift;

    open(OUT,">$file") or croak "Couldn't open file: $file for writing";
    print OUT "# Saved OSCAR MAC Addresses; ", scalar localtime, "\n";
    foreach my $mac (sort {$MAC{$a}->{order} <=> $MAC{$b}->{order}} keys %MAC) {
        my $client = $MAC{$mac}->{client};
        print OUT $mac, "\t# $client\n";
    }
    close(OUT);
    return 1;
}

sub load_from_file {
    my $file = shift;
    open(IN,"<$file") or croak "Couldn't open file: $file for reading";
    while(<IN>) {
        if(/^\s*\#/) {
            next;
        }
        if(/^\s*([a-fA-F0-9\:]{11,17})/) {
            my $mac = $1;
            add_mac_to_hash($mac);
        }
    }
    close(IN);
    return 1;
}

# Subroutine that takes MAC address string as input and pass it to the add_mac_to_hash
# subroutine if string is validated to be a sane MAC address
# TODO: - merge with load_from_file subroutine as there seems to be code duplication
#       - better MAC address validation
sub __load_macs {
    my $string = shift;

    my @macs = split("\n", $string);
    foreach my $mac (@macs) {
        my @elements = split(":", $mac);
        my $num_elements = @elements;
        if ( ($mac =~ /^\s*([a-fA-F0-9\:])/) && (length($mac) == 17) && ($num_elements > 1) ) {
            add_mac_to_hash($mac);
        }
    }
    return 1;
}

sub set_servermacs {
    open(CMD, "/sbin/ifconfig|");
    my @hostmacs = map {/HWaddr\s+([[:xdigit:]:]+)\s+/} grep /HWaddr/, <CMD>;
    close CMD;
    foreach (@hostmacs) {
       $_ = uc mactransform( $_ );
    }
    return @hostmacs;
}

sub add_mac_to_hash {
    my ($m, $client) = @_;
    my $mac = uc mactransform( $m );
    # if the mac is 00:00:00:00:00:00, it isn't real
    if($mac =~ /^[0\:]+$/) {
        return 0;
    }
    # If the MAC is the server's, then get out of here
    if ( grep {$mac eq $_} @SERVERMACS ) {
        return 0;
    }
    # if it already has an order, then we already know about it
    if($MAC{$mac}->{order}) {
        return 0;
    }
    # else, add the mac address with a null client
    $MAC{$mac} = {
                  client => $client,
                  order => $ORDER,
                 };
    $ORDER++;
    return 1;
}

# mac transform does a join map split trick to ensure that each octet is 2 characters

sub mactransform {
    my $mac = shift;
    my $return = uc join ':', (map {(length($_) == 1) ? "0$_" : "$_"} split (':',$mac));
    return $return;
}

# A simple subrountine for running a command
sub run_cmd {
    my $cmd = shift;
    !system($cmd) or croak("Failed to run $cmd");
}

# Build AutoInstall CD
sub __build_autoinstall_cd {
    my $ip = shift;
    our $uyok;
    our $kernel;
    our $ramdisk;
    our $install_mode;

    if ($uyok) {
      generate_uyok();
    }

    my $append = "MONITOR_SERVER=$ip MONITOR_CONSOLE=yes";
    $append = "$append ramdisk_size=80000" if $uyok;
    if ($install_mode eq "systemimager-bt") {
      $append = "$append BITTORRENT=y";
    }

    my $cmd = "si_mkautoinstallcd --append \"$append\" --out-file /tmp/oscar_bootcd.iso --flavor standard";
    $cmd = "$cmd --kernel $kernel --initrd $ramdisk" if $uyok;

    oscar_log_subsection("Step $step_number: Building AutoInstall CD: $cmd");
    !system($cmd) or croak("Failed to run $cmd");
    oscar_log_subsection("Step $step_number: Successfully built AutoInstall CD");
    print "You can now burn your ISO image to a CDROM with a command such as:\n'cdrecord -v speed=2 dev=1,0,0 /tmp/oscar_bootcd.iso'.\n\n" if ($ENV{OSCAR_UI} eq "cli");
}

# Run SystemImager's si_prepareclient on the headnode to generate the UYOK
# boot kernel and ramdisk (initrd.img).  These will be stored in
# /etc/systemimager/boot
sub generate_uyok {
    our $kernel;
    our $ramdisk;

    $kernel = "/etc/systemimager/boot/kernel";
    $ramdisk = "/etc/systemimager/boot/initrd.img";

    oscar_log_subsection("Step $step_number: Running si_prepareclient on headnode to generate UYOK kernel and ramdisk");
    my $cmd = "si_prepareclient --server $ENV{HOSTNAME} --no-rsyncd --yes";
    $cmd = "$cmd --quiet" unless $ENV{OSCAR_VERBOSE};

    !system("$cmd") or croak("Failed to run: $cmd");
    oscar_log_subsection("Step $step_number: Successfully enabled UYOK");
}

# Configure system to use selected installation mode
# GV: This is a nasty function that really need to be cleaned-up:
#     GUI code is mixed with library code, and we definitively need
#     to write sub-functions...
# BL: The GUI code has been moved to GUI_MAC::enable_install_mode
sub __enable_install_mode {
    our $install_mode;

    our $os;
    my $cmd;
    my $interface = get_headnode_iface();

    my $os_detect = OSCAR::OCA::OS_Detect::open();
    my $binary_format = $os_detect->{'pkg'};

    if ($install_mode eq "systemimager-rsync") {
        # Stop systemimager-server-flamethrowerd
        run_cmd("/etc/init.d/systemimager-server-flamethrowerd stop");

        # Remove systemimager-server-flamethrowerd from chkconfig
        if ($binary_format ne "deb") {
            run_cmd("chkconfig systemimager-server-flamethrowerd off");
        } else {
            run_cmd("update-rc.d -f systemimager-server-flamethrowerd remove");
        }

        # Stop systemimager-server-bittorrent
        run_cmd("/etc/init.d/systemimager-server-bittorrent stop");

        # Remove systemimager-server bittorrent from chkconfig
        if ($binary_format ne "deb") {
            run_cmd("chkconfig systemimager-server-bittorrent off");
        } else {
            run_cmd("update-rc.d -f systemimager-server-bittorrent remove");
        }

        # Restart systemimager-server-rsyncd
        run_cmd("/etc/init.d/systemimager-server-rsyncd restart");

        # Enable systemimager-server-rsyncd
        if ($binary_format ne "deb") {
            run_cmd("chkconfig systemimager-server-rsyncd on");
        } else {
            run_cmd("update-rc.d -f systemimager-server-rsyncd start 20 2 .");
        }
    } elsif ($install_mode eq "systemimager-multicast") {
        # Stop systemimager-server-bittorrent
        run_cmd("/etc/init.d/systemimager-server-bittorrent stop");

        # Remove systemimager-server-bittorrent from chkconfig
        if ($binary_format ne "deb") {
            run_cmd("chkconfig systemimager-server-bittorrent off");
        } else {
            run_cmd("update-rc.d -f systemimager-server-bittorrent remove");
        }

        # Restart systemimager-server-rsyncd (needed by netbootmond and also for calculating image size in si_monitortk)
        run_cmd("/etc/init.d/systemimager-server-rsyncd restart");

        # Backup original flamethrower.conf
        run_cmd("/bin/mv -f /etc/systemimager/flamethrower.conf /etc/systemimager/flamethrower.conf.bak");

        $cmd = "sed -e 's/START_FLAMETHROWER_DAEMON = no/START_FLAMETHROWER_DAEMON = yes/' -e 's/INTERFACE = eth[0-9][0-9]*/INTERFACE = $interface/' /etc/systemimager/flamethrower.conf.bak > /etc/systemimager/flamethrower.conf";
        if( system( $cmd ) ) {
            carp("Failed to update /etc/systemimager/flamethrower.conf");
            return 0;
        }

        # add entry for boot-<arch>-standard module
        my $march = $os->{'arch'};
        $march =~ s/i.86/i386/;
        $cmd = "/usr/lib/systemimager/perl/confedit --file /etc/systemimager/flamethrower.conf --entry boot-$march-standard --data \" DIR=/usr/share/systemimager/boot/$march/standard/\"";
        if( system( $cmd ) ) {
            carp("Couldn't run command $cmd");
            return 1;
        }

        oscar_log_subsection("Step $step_number: Updated /etc/systemimager/flamethrower.conf");

        # Restart systemimager-server-flamethrowerd
        run_cmd("/etc/init.d/systemimager-server-flamethrowerd restart");

        # Add systemimager-server-flamethrowerd to chkconfig
        if ($binary_format ne "deb") {
            run_cmd("chkconfig systemimager-server-flamethrowerd on");
        } else {
            run_cmd("update-rc.d -f systemimager-server-flamethrowerd start 20 2 .");
        }
    } elsif ($install_mode eq "systemimager-bt") {
        # Stop systemimager-server-flamethrowerd
        run_cmd("/etc/init.d/systemimager-server-flamethrowerd stop");

        # Remove systemimager-server-flamethrower from chkconfig
        if ($binary_format ne "deb") {
            run_cmd("chkconfig systemimager-server-flamethrowerd off");
        } else {
            run_cmd("update-rc.d -f systemimager-server-flamethrowerd remove");
        }
        # Restart systemimager-server-rsyncd (needed by netbootmond and also for calculating image size in si_monitortk)
        run_cmd("/etc/init.d/systemimager-server-rsyncd restart");

        # Backup original bittorrent.conf
        run_cmd("/bin/mv -f /etc/systemimager/bittorrent.conf /etc/systemimager/bittorrent.conf.bak");

        my @images = list_image();
        my $images_list = join(",", map { $_->name } @images);

        $cmd = "sed -e 's/BT_INTERFACE=eth[0-9][0-9]*/BT_INTERFACE=$interface/' -e 's/BT_IMAGES=.*/BT_IMAGES=$images_list/' -e 's/BT_OVERRIDES=.*/BT_OVERRIDES=$images_list/' /etc/systemimager/bittorrent.conf.bak > /etc/systemimager/bittorrent.conf";
        if( system( $cmd ) ) {
            carp("Failed to update /etc/systemimager/bittorrent.conf");
            return 0;
        }

        oscar_log_subsection("Step $step_number: Updated /etc/systemimager/bittorrent.conf");

        # Restart systemimager-server-bittorrent
        run_cmd("/etc/init.d/systemimager-server-bittorrent restart");

        # Add systemimager-server-bittorrent to chkconfig
        if ($binary_format ne "deb") {
            run_cmd("chkconfig systemimager-server-bittorrent on");
        } else {
            run_cmd("update-rc.d -f systemimager-server-bittorrent start 20 2 .");
        }
    }

    # Store installation mode in ODA
    set_install_mode($install_mode);

    oscar_log_subsection("Step $step_number: Successfully enabled installation mode: $install_mode");

    our $dhcpbtn = 1 if ($ENV{OSCAR_UI} eq "cli");
    return 1;
}

# Execute the setup_pxe script
sub __run_setup_pxe {
    my $uyok = shift;

    my $cmd = "./setup_pxe -v";

    if ($uyok) {
      $cmd = "$cmd --uyok";
      generate_uyok();
    }

    oscar_log_subsection("Step $step_number: Setup network boot: $cmd");
    !system($cmd) or (carp($!), return undef);

    $cmd = "../packages/kernel/scripts/fix_network_boot";
    if ( -x $cmd) {
        oscar_log_subsection("Step $step_number: Finishing network boot: $cmd");
        !system($cmd) or carp "ERROR COMMAND FAILED ($!): $cmd";
        oscar_log_subsection("Step $step_number: Successfully finished network boot");
    }

    oscar_log_subsection("Step $step_number: Successfully setup network boot");
    return 1;
}

# GV: long term we should not need the following functions (when i will have 
# finished to separate the GUI code from the library code
#
# Setup the cli
# 
sub mac_cli {
    # If there is a filename here, it will be used to automate the 
    our $autofile = shift;
    $step_number = shift;
    our ($vars) = @_;
    our $auto; #True if we're going to run automatically
    
    if ($autofile ne " ") {$auto = 1;}

    chdir("$ENV{OSCAR_HOME}/scripts");

    # init this only once as we don't add network cards during this process
    @SERVERMACS = set_servermacs();

    oscar_log_section("Running step $step_number of the OSCAR wizard: Setup networking");

    our $install_mode;
    
    #Retrive the installation mode from ODA
    my $orig_install_mode = get_install_mode();
    
    $install_mode = $orig_install_mode;

    #Start printing the menu
    cli_menu($autofile);

    return 0;
}

#The interface for the cli version of the MAC setup
sub cli_menu {
    my $done = 0;
    my $infile = shift;
    our $auto;
    our $install_mode;
    our $dyndhcp = 1;
    our $uyok = 0;
    our $dhcpbtn = 0;
    our $vars;

    #Open the log file
    my $ppid = getppid();
    if (!$auto) {open(LOG, ">$ENV{OSCAR_HOME}/tmp/mac.$ppid.clilog") || print "Can't open the log for writing.\n";}
    
    #Open the file passed in for the automated version
    if($auto) {open(FILE, "$infile") || die "Can't open the input file\n";}
    
    while (!$done) {
        # For now, default interface is eth0
        my $iface = "eth0";
        populate_MACS();
        my @clients = sortclients list_client();
        print "Current client assignments:\n";
        if (@clients) {
            foreach my $client (@clients) {
                my $nodename = $client->name;
                my $adapter = list_adapter(client=>$nodename, devname=>"$iface");
                my $mac = $adapter->mac || "  :  :  :  :  :  ";
                my $ip = $adapter->ip;
                print "\t$nodename ($iface) [$ip] <$mac>\n";
            }
        } else {
            print "\tNo clients defined.\n";
        }
        print "\n";

        print "1)  Import MACs from file\n" . 
              "2)  Delete MACs\n" .
              "3)  Installation Mode:  $install_mode\n" .
              "4)  Enable Install Mode\n" .
              "5)  Dynamic DHCP update:  " . numtostring($dyndhcp) . "\n" .
              "6)  Configure DHCP Server\n" .  
              "7)  Enable UYOK:  " . numtostring($uyok) . "\n" .
              "8)  Build AutoInstall CD\n" .
              "9)  Setup Network Boot\n" .
              "10) Finish\n" .
              ">  " unless ($auto);
        my $response;
        if (!$auto) {
            print LOG "######################################\n" .
              "#1)  Import MACs from file\n" . 
              "#2)  Delete MACs\n" .
              "#3)  Installation Mode:  $install_mode\n" .
              "#4)  Enable Install Mode\n" .
              "#5)  Dynamic DHCP update:  " . numtostring($dyndhcp) . "\n" .
              "#6)  Configure DHCP Server\n" .  
              "#7)  Enable UYOK:  " . numtostring($uyok) . "\n" .
              "#8)  Build AutoInstall CD\n" .
              "#9)  Setup Network Boot\n" .
              "#10) Finish\n" .
              "######################################\n";
            $response = <STDIN>;
            print LOG $response;
        }
        else {
            $response = <FILE>;
            next if (response_filter($response));
        }

        # If response is "return", loop
        if ($response eq "\n") {
            next;
        }

        chomp $response;
        if($response == 1) {
            my $result = 0;
            while (!$result) {
                if(!$auto) {
                    print "Enter filename:  ";
                    $response = <STDIN>;
                    print LOG $response;
                } else {
                    $response = <FILE>;
                    next if (response_filter($response));
                }
                chomp $response;

                if (!$response) {
                    $result = "You did not specify a filename\n";
                    print $result;
                    next;
                } elsif (!( -e $response)) {
                    $result = "File $response does not exist\n";
                    print $result;
                    next;
                }
                $result = load_from_file($response);
                assign_macs_cli();
            }
        }
        elsif($response == 2) {
            delete_macs_cli();
        }
        elsif($response == 3) {
            $install_mode = cli_installmode();
            oscar_log_subsection("Install mode: $install_mode");
        }
        elsif($response == 4) {
            __enable_install_mode();
        }
        elsif($response == 5) {
            $dyndhcp = ++$dyndhcp%2; #Jump between 1 and 0
        }
        elsif($response == 6) {
            if($dhcpbtn) {
                __setup_dhcpd($$vars{interface});
            }
            else {
                print "Need to Enable Install Mode first\n";
            }
        }
        elsif($response == 7) {
            $uyok = ++$uyok%2; #Jump between 1 and 0
        }
        elsif($response == 8) {
            my ($ip, $broadcast, $netmask) = interface2ip($$vars{interface});
            build_autoinstall_cd($ip);
        }
        elsif($response == 9) {
            __run_setup_pxe($uyok);
        }
        elsif($response == 10) {
            $done = 1;
            oscar_log_subsection("Step $step_number: Completed successfully");
        }
    }

    close LOG;
}

# This will assign the MAC addresses that were read in from a file to the
# clients that have been defined.  This is done sequentially (top to bottom)
# according to the file.
sub assign_macs_cli {
    my @clients = sortclients list_client();
    our $auto;
    
    my $notdone = 1;
    my $response;

    # If MAC is already assigned to a client, remove it from the hash
    foreach my $mac (keys %MAC) {
        if ($MAC{$mac}->{client}) {
            delete $MAC{$mac};
        }   
    }

    if (!%MAC) {
        print "There are no unassigned MACs.\n";
        $notdone = 0;
        return;
    }

    while ($notdone) {
        print "=====MAC Assignment Method=====\n" .
            "1)  Automatically assign MACs\n" .
            "2)  Manually assign MACs\n" .
            ">  " unless ($auto);
        $response = <STDIN> if (!$auto);
        $response = <FILE> if ($auto);
        $notdone = response_filter($response);
    }
    chomp $response;
    my @mac_keys = sort {$MAC{$a}->{order} <=> $MAC{$b}->{order}} keys %MAC;
    my $iface = "eth0";

    if ($response == 1) {
        while (my $mac = shift @mac_keys) {
            foreach my $client (@clients) {
                my $adapter = list_adapter(client=>$client->name,devname=>"$iface");
                # Assign only if client has no assignment
                if (!$adapter->mac && !$MAC{$mac}->{client}) {
                    oscar_log_subsection("Assigning MAC: $mac to client: " . 
                        $client->name);
                    $adapter->mac($mac);
                    set_adapter($adapter);
                    $MAC{$mac}->{client}=$client->name;
                    add_mac_to_hash($mac, $client->name);
                }
            }
        }
    } elsif ($response == 2) {
        my $quit = 0;
        while (!$quit) {
            my $valid = 0;
            my $mac_selection;
            while (!$valid && !$quit) {
                @mac_keys = sort {$MAC{$a}->{order} <=> $MAC{$b}->{order}} keys %MAC;
                print "-----MAC Addresses-----\n" . join("\n",@mac_keys)."\n" .
                "Pick a MAC Address (Type quit to stop assigning)\n>  " unless ($auto);
                $mac_selection = <STDIN> if (!$auto);
                $mac_selection = <FILE> if ($auto);
                next if (response_filter($mac_selection));
                chomp $mac_selection;
                if ($mac_selection eq "quit") {
                    $quit = 1;
                    $valid = 1;
                } else {
                    foreach my $item (@mac_keys) {
                        if ($item eq $mac_selection) {
                            $valid = 1;
                            last;
                        }
                    }
                }
            }
            my $ip_selection;
            $valid = 0;
            while (!$valid && !$quit) {
                print "---------Clients-------\n" . join("\n", map { $_->name } @clients) .
                "\nPick a client (Type quit to stop assigning)\n>  " unless ($auto);
                my $client_selection = <STDIN> if (!$auto);
                $client_selection = <FILE> if ($auto);
                next if (response_filter($client_selection));
                chomp $client_selection;
                if ($client_selection eq "quit") {
                    $quit = 1;
                    $valid = 1;
                } else {
                    foreach my $item (@clients) {
                        if ($item->name eq $client_selection) {
                            $valid = 1;
                            last;
                        }
                    }
                    oscar_log_subsection("Assigning MAC: $mac_selection to client: " . $client_selection);
                    my $adapter = list_adapter(client=>$client_selection,devname=>"eth0");
                    # If client selection has a MAC address assigned, bump it back out to the
                    # global hash
                    if ($adapter->mac) {
                        add_mac_to_hash($adapter->mac);
                    }
                    $adapter->mac($mac_selection);
                    set_adapter($adapter);
                    delete $MAC{$mac_selection};
                }
            }
        }
    }
}

sub delete_macs_cli {
    print "Not implemented yet.\n";
}

sub cli_installmode {
    our $install_mode;
    our $auto;
    
    my $done = 0;
    while(!$done) {
        print "Currently:  $install_mode\n" .
              "Options:  " . join(" ",@install_mode_options) . "\n" .
              "New:  " unless ($auto);
        my $line = <STDIN> if (!$auto);
        $line = <FILE> if ($auto);
        next if (response_filter($line));
        chomp $line;
        foreach my $choice (@install_mode_options) {
            if($choice eq $line) {
                $done = 1;
                return $choice;
            }
        }
    }
}

sub numtostring {
    my $number = shift;
    if ($number == 0) {
        return "false";
    } else {
        return "true";
    }
}

sub response_filter {
    $_ = shift;

#print "LINE (PRECHOMP): $_";

    if ($_) {chomp ($_);}

#print "LINE (POSTCHOMP): $_";

    #Blank line
    if(!$_) {return 1;}

    #Comment
    elsif(/^#/) {return 1;}

    return 0;
}

1;
