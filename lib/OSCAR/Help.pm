package OSCAR::Help;

#   $Id: Help.pm,v 1.3 2002/02/17 04:44:54 sdague Exp $

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

#   Copyright 2001-2002 International Business Machines
#                       Sean Dague <japh@us.ibm.com>

use strict;
use vars qw(%Help $VERSION @EXPORT);
use base qw(Exporter);

@EXPORT = qw(open_help);

$VERSION = sprintf("%d.%02d", q$Revision: 1.3 $ =~ /(\d+)\.(\d+)/);

# Help messages for the OSCAR GUI.

sub open_help {
    my ($window, $section) = @_;
    my $helpwin = $window->Toplevel();
    $helpwin->title("Help");
    my $helpp = $helpwin->Scrolled("ROText",-scrollbars=>"e",-wrap=>"word",
                                 -width=>40,-height=>15);
    $helpp->grid(-sticky=>"nsew");
    my $cl_b = $helpwin->Button(-text=>"Close",
                                -command=> sub {$helpwin->destroy},-pady=>"8");
    $helpwin->bind("<Escape>",sub {$cl_b->invoke()});
    $cl_b->grid(-sticky=>"nsew",-ipady=>"4");
    $helpp->delete("1.0","end");
    $helpp->insert("end",$Help{$section});
}

%Help = (
         build_image => "This button will launch a panel which will let you define and build your OSCAR client image.  The defaults specified should work for most situations.",
         addclients => "This button will launch a panel which lets you define what clients are going to be installed with OSCAR.",
         netboot => "This button will launch the MAC Address Collection Tool which will enable you to assign specific MAC addresses to clients for installation.  Please follow the instructions on the MAC Address Collection Panel",
         post_install => "Pressing this button will run a series of post installation scripts which will complete your OSCAR installation.",
         test_install => "Pressing this button will set up the test scripts so that you can test to see if your OSCAR installation is working.",
        );
1;
