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
#   Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307 USA
#
# Copyright (c) 2002 National Center for Supercomputing Applications (NCSA)
#                    All rights reserved.
#
# Written by Terrence G. Fleury (tfleury@ncsa.uiuc.edu)
#
# Copyright (c) 2002 The Trustees of Indiana University.  
#                    All rights reserved.
# 
# This file is part of the OSCAR software package.  For license
# information, see the COPYING file in the top level directory of the
# OSCAR source distribution.
#
# $Id: Configurator.pm,v 1.13 2002/11/14 01:32:40 tfleury Exp $
# 
##############################################################
#  MOVE THE STUFF BELOW TO THE TOP OF THE PERL SOURCE FILE!  #
##############################################################
package OSCAR::Configurator;

use strict;
use vars qw(@EXPORT);
use base qw(Exporter);
our @EXPORT = qw(populateConfiguratorList displayPackageConfigurator);

use lib "$ENV{OSCAR_HOME}/lib";
use Carp;
use OSCAR::Configbox; # For the configuration HTML form display
use OSCAR::Package;   # For list_pkg() and run_pkg_script()
use OSCAR::Logger;    # For oscar_log_section()
use OSCAR::Selector;
use XML::Simple;      # Read/write the .selection config files
use Tk::Pane; 

my($top);             # The Toplevel widget for the package configuration window
my $stepnum;          # Step number in the OSCAR wizard
##############################################################
#  MOVE THE STUFF ABOVE TO THE TOP OF THE PERL SOURCE FILE!  #
##############################################################

# Sample SpecTcl main program for testing GUI

use Tk;
require Tk::Menu;
#my($top) = MainWindow->new();
#$top->title("Configurator test");


# interface generated by SpecTcl (Perl enabled) version 1.2 
# from Configurator.ui
# For use with Tk402.002, using the grid geometry manager

sub Configurator_ui {
	our($root) = @_;

	# widget creation 

	our($configFrame) = $root->Frame (
	);
	my($label_1) = $root->Label (
		-font => '-*-Helvetica-Bold-R-Normal-*-*-140-*-*-*-*-*-*',
		-text => 'OSCAR Package Configuration',
	);
	my($doneButton) = $root->Button (
		-default => 'active',
		-text => 'Done',
	);

	# widget commands

	$doneButton->configure(
		-command => \&OSCAR::Configurator::doneButtonPressed
	);

	# Geometry management

	$configFrame->grid(
		-in => $root,
		-column => '1',
		-row => '2',
		-sticky => 'nesw'
	);
	$label_1->grid(
		-in => $root,
		-column => '1',
		-row => '1',
		-sticky => 'ew'
	);
	$doneButton->grid(
		-in => $root,
		-column => '1',
		-row => '3',
		-sticky => 'ew'
	);

	# Resize behavior management

	# container $root (rows)
	$root->gridRowconfigure(1, -weight  => 0, -minsize  => 30);
	$root->gridRowconfigure(2, -weight  => 1, -minsize  => 200);
	$root->gridRowconfigure(3, -weight  => 0, -minsize  => 30);

	# container $root (columns)
	$root->gridColumnconfigure(1, -weight => 1, -minsize => 147);

	# additional interface code

our($packagexml);             # Holds the XML configs for each package
our($oscarbasedir);           # Where the program is called from
our($pane);                   # The pane holding the scrolling selection list

#########################################################################
#  Called when the "Done" button is pressed.                            #
#########################################################################
sub doneButtonPressed
{
  # If the $root window has a Parent, then it isn't a MainWindow, which
  # means that another MainWindow is managing the OSCAR Package
  # Configuration window.  Therefore, when we exit, we need to make the
  # parent window unbusy.
  $root->Parent->Unbusy() if ($root->Parent);

  # If there are any children, make sure they are destroyed.
  my (@kids) = $root->children;
  foreach my $kid (@kids)
    {
      $kid->destroy;
    }

  # Then, destroy the root window.
  $root->destroy;

  # Undefine a bunch of Tk widgeet variables for re-creation later.
  undef $root;
  undef $top;
  undef $pane;

  # Call the post-configure API script in each selected package
  my @packages = list_install_pkg();
  foreach my $pkg (@packages) {
      if (!run_pkg_script($pkg, "post_configure", 1, "")) {
	  carp("Post-configure script for package \"$pkg\" failed");
      }
  }

  # Write out a message to the OSCAR log
  oscar_log_subsection("Step $stepnum: Completed successfully");
}

#########################################################################
#  Subroutine name : getSelectedPackages                                #
#  Parameters: None                                                     #
#  Returns   : Nothing                                                  #
#  This subroutine reads in the list of packages that have been         #
#  selected for installation (using the .selection.config file located  #
#  under the OSCAR installation directory) and then sets a "selected"   #
#  flag in the $packagexml hash for each package.  It then removes      #
#  any packages from $packagexml which have not been selected for       #
#  installation and configuration.  In effect, we allow configuration   #
#  of a package only if that package has been selected for installation #
#  and if that package has a configurator.html file.                    #
#########################################################################
sub getSelectedPackages
{
  my($package);
  my(@packages) = list_install_pkg();

  # Set a "selected" field for all packages selected for installation
  foreach $package (@packages)
    {
      $packagexml->{$package}{selected} = 1;
    }

  foreach $package (keys %{ $packagexml } )
    {
      # Skip any packages which aren't selected to be installed
      delete $packagexml->{$package} if 
        ((defined $packagexml->{$package}) && 
          (!$packagexml->{$package}{selected}));

      # Skip any packages which don't have a configurator.html file
      delete $packagexml->{$package} unless
        (-s "$oscarbasedir/packages/$package/configurator.html");
    }
}

#########################################################################
#  Subroutine : populateConfiguratorList                                #
#  Parameters : None                                                    #
#  Returns    : Nothing                                                 #
#  This subroutine is the main function for the "Oscar Package          #
#  Configurator".  It fills in the main window with a scrolling list of #
#  OSCAR packages allowing the user to enable/disable each package,     #
#  view helpful information about the package (if any), and configure   #
#  the package (if enabled).  It creates a scrolling pane and populates #
#  it with the list of package directories found under the main OSCAR   #
#  directory.                                                           #
#########################################################################
sub populateConfiguratorList
{
  my($tempframe);

  # Set up the base directory where this script is being run
  $oscarbasedir = '.';
  $oscarbasedir = $ENV{OSCAR_HOME} if ($ENV{OSCAR_HOME});
  # Read in all packages' config.xml files
  $packagexml = deepcopy(pkg_config_xml());
  getSelectedPackages();

  $pane->destroy if ($pane);
  # First, put a "Pane" widget in the center frame
  $pane = $configFrame->Scrolled('Pane', -scrollbars => 'osoe');
  $pane->pack(-expand => '1', -fill => 'both');

  # Now, start adding OSCAR package stuff to the pane
  if (scalar(keys %{ $packagexml } ) == 0)
    {
      $pane->Label(-text => "No OSCAR packages to configure.")->pack;
    }
  else
    { # Create a temp Frame widgit for each package row
      foreach my $package (sort keys %{ $packagexml } )
        {
          # Create a frame and save it in a hash based on pkgdir name
          $tempframe->{$package} = $pane->Frame();

          # Then add the config buttons and package name labels.
          # First,the Config button...
          $tempframe->{$package}->Button(
            -text => 'Config',
            -command => [ \&OSCAR::Configbox::configurePackage,
                          $root,
                          "$oscarbasedir/packages/$package",
                        ],
            )->pack(-side => 'left');

          # Then, the package name label.
          $tempframe->{$package}->Label(
            -text => $packagexml->{$package}{name},
            )->pack(-side => 'left');
        }

      # Now that we have created all of the temporary frames (each
      # containing a config button and text label), add them to the
      # scrolled pane in order of their "fancy" names rather than their
      # package directory names.  To do this, create a reverse mapping from
      # fancy names to directory names, sort on the fancy names, and use
      # that as a hash key into the tempframe hash.
      my(%map);
      foreach my $package (sort keys %{ $packagexml } )
        {
          $map{$packagexml->{$package}{name}} = $package;
        }
      foreach my $pkgname (sort { lc($a) cmp lc($b) } keys %map)
        {
          $tempframe->{$map{$pkgname}}->pack(-side => 'top',
                                             -fill => 'x',
                                            );
        }
    }
}

#########################################################################
#  Subroutine : displayPackageConfigurator                              #
#  Parameter  : The parent widget which manages the configurator window #
#  Returns    : Nothing                                                 #
#########################################################################
sub displayPackageConfigurator # ($parent)
{
  my $parent = shift;
  $stepnum = shift;

  oscar_log_section("Running step $stepnum of the OSCAR wizard: Configure selected OSCAR packages");

  # Call the pre-configure API script in each selected package
  my @packages = list_install_pkg();
  foreach my $pkg (@packages) 
    {
      carp('Pre-configure script for package "' . $pkg . '" failed') if 
        (!run_pkg_script($pkg, "pre_configure", 1, ""));
    }

  # Check to see if our toplevel configurator window has been created yet.
  if (!$top)
    { # Create the toplevel window just once
      if ($parent)
        {
          # Make the parent window busy
          $parent->Busy(-recurse => 1);
          $top = $parent->Toplevel(-title => 'Oscar Package Configuration',
                                   -width => '260',
                                   -height => '260',
                                  );
        }
      else
        { # If no parent, then create a MainWindow at the top.
          $top = MainWindow->new();
          $top->title("Oscar Package Configuration");
        }
      OSCAR::Configurator::Configurator_ui $top;  # Call specPerl window creator
    }

  # Then create the scrollable package listing and place it in the grid.
  populateConfiguratorList();

  $root->MapWindow;   # Put the window on the screen.
}

############################################
#  Set up the contents of the main window  #
############################################

#displayPackageConfigurator($top);


	# end additional interface code
}
#Configurator_ui $top;
#Tk::MainLoop;

1;
