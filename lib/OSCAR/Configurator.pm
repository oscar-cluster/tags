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
# $Id: Configurator.pm,v 1.29 2003/11/14 00:38:22 tfleury Exp $
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
use OSCAR::Package;   # For list_installable_packages() and run_pkg_script()
use OSCAR::Logger;    # For oscar_log_section()
#use OSCAR::Selector;
use XML::Simple;      # Read/write the .selection config files
use Tk::Pane; 
no warnings qw(closure);

our $destroyed = 0;
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
        $destroyed = 1;
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

our(%configurable_packages);  # Holds the selected configurable packages info
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
  undef $destroyed;
  $root->UnmapWindow if ($root);
  $root->Parent->Unbusy() if
    ((defined($root)) && (defined($root->Parent)));

  # Destroy the Configbox if one was created.
  OSCAR::Configbox::exitWithoutSaving;

  # If there are any children, make sure they are destroyed.
  my (@kids) = $root->children;
  foreach my $kid (@kids)
    {
      $kid->destroy;
    }

  # Then, destroy the root window.
  $root->destroy if (defined($root));

  # Undefine a bunch of Tk widgeet variables for re-creation later.
  undef $root;
  undef $top;
  undef $pane;

  # Call the post-configure API script in each selected package
  my $packages_ref = getSelectedConfigurablePackages();
  foreach my $pkg (sort keys %$packages_ref) 
    {
      carp("Post-configure script for package \"$pkg\" failed") if 
        (!run_pkg_script($pkg, "post_configure", 1, ""));
    }

  # Write out a message to the OSCAR log
  oscar_log_subsection("Step $stepnum: Completed successfully");
}

#########################################################################
#  Subroutine name : getSelectedConfigurablePackages                    #
#  Parameters: None                                                     #
#  Returns   : a reference to a hash with the keys being the short      #
#              package name and the values being the long package name  #
#  This subroutine reads in the list of package names from the database #
#  that have been selected for installation (via the Selector OR via    #
#  the Updater) and returns them in a hash ref.  Note that if you       #
#  just want the packages that have configurator.html files, you will   #
#  need to post-process the hash.                                       #
#########################################################################
sub getSelectedConfigurablePackages
{
  # Read all records from the database table <packages> that are marked
  # as being installable and as being selected, saving the long package
  # name in the <package> field for each package (we could do this with
  # a shortcut but this code is about to be replaced and want a special
  # output format).
  my @resultref;
  my %packages;

  # START LOCKING FOR NEST
  my @tables = ("oscar", "packages", "packages_sets", "package_sets_included_packages", "oda_shortcuts");
  my @error_list = ();
  my %options = ();
  locking("WRITE", \%options, \@tables, \@error_list);
  OSCAR::Database::dec_already_locked(
    "packages_in_selected_package_set packages.package", \@resultref, 1);

  # Transform the list into a hash; keys=short pkg name, values=long pkg name
  foreach my $pkg (@resultref) 
    {
      my ($pname, $ppackage) = split(' ', "$pkg", 2);
      $packages{$pname} = $ppackage;
    }

  # Add in any packages which "should_be_installed"
  my @pkginstall = ();
  OSCAR::Database::dec_already_locked(
    "packages_that_should_be_installed", \@pkginstall);
  foreach my $package (@pkginstall)
    { # Get the long name and add the short name/long name to the hash
      my @longname = ();
      OSCAR::Database::dec_already_locked(
        "read_records packages name=$package package",\@longname);
      $packages{$package} = ((defined $longname[0]) ? $longname[0] : $package);
    }
  # UNLOCKING FOR NEST
  unlock(\%options, \@error_list);

  return \%packages;
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
  my($packagedir);

  # Set up the base directory where this script is being run
  $oscarbasedir = '.';
  $oscarbasedir = $ENV{OSCAR_HOME} if ($ENV{OSCAR_HOME});

  # Get the list of selected, configurable packages
  my $packages_ref = getSelectedConfigurablePackages();

  # Skip any packages which don't have a configurator.html file
  foreach my $package ( sort keys %$packages_ref ) 
    {
      my $found = 0;
      foreach my $dir (@OSCAR::Package::PKG_SOURCE_LOCATIONS) 
        {
          (($found = 1) and last) if (-s "$dir/$package/configurator.html");
        }
      delete $packages_ref->{$package} if (!$found);
    }

  $pane->destroy if ($pane);
  # First, put a "Pane" widget in the center frame
  $pane = $configFrame->Scrolled('Pane', -scrollbars => 'osoe');
  $pane->pack(-expand => '1', -fill => 'both');

  # Now, start adding OSCAR package stuff to the pane
  if ( ! %$packages_ref )
    {
      $pane->Label(-text => "No OSCAR packages to configure.")->pack;
    }
  else
    { # Create a temp Frame widgit for each package row
      foreach my $package (sort keys %$packages_ref )
        {
          # Create a frame and save it in a hash based on pkgdir name
          $tempframe->{$package} = $pane->Frame();

          # Figure out where the package directory is located on the disk.
          $packagedir =  "$oscarbasedir/packages/$package";  # Fallback
          foreach my $dir (@OSCAR::Package::PKG_SOURCE_LOCATIONS)
            {
              (($packagedir = "$dir/$package") and last) if
                (-d "$dir/$package");
            }

          # Then add the config buttons and package name labels.
          # First,the Config button...
          $tempframe->{$package}->Button(
            -text => 'Config...',
            -command => [ \&OSCAR::Configbox::configurePackage,
                          $root,
                          $packagedir,
                        ],
            )->pack(-side => 'left');

          # Then, the package name label.
          $tempframe->{$package}->Label(
            -text => $$packages_ref{$package},
            )->pack(-side => 'left');
        }

      # Now that we have created all of the temporary frames (each
      # containing a config button and text label), add them to the
      # scrolled pane in order of their "fancy" names rather than their
      # package directory names.  To do this, create a reverse mapping from
      # fancy names to directory names, sort on the fancy names, and use
      # that as a hash key into the tempframe hash.
      my(%map);
      foreach my $package (sort keys %$packages_ref )
        {
          $map{$$packages_ref{$package}} = $package;
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
#  Parameters : (1) Parent widget which manages the configurator window #
#               (2) The step number of the oscar_wizard                 #
#  Returns    : Reference to the newly created window                   #
#########################################################################
sub displayPackageConfigurator # ($parent)
{
  my $parent = shift;
  $stepnum = shift;

  oscar_log_section("Running step $stepnum of the OSCAR wizard: Configure selected OSCAR packages");

  # Call the pre-configure API script in each selected package and,
  # for the install/uninstall stuff, any packages which "should_be_installed"
  my $packages_ref = getSelectedConfigurablePackages();
  foreach my $pkg (sort keys %$packages_ref) 
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
          $top->bind('<Destroy>', sub {
            if ( defined($destroyed)) {
              undef $destroyed;
              doneButtonPressed();
              return;
            }
                                      } );
        }
      else
        { # If no parent, then create a MainWindow at the top.
          $top = MainWindow->new();
          $top->title("Oscar Package Configuration");
          $top->bind('<Destroy>', sub { 
      if (defined($destroyed)) {
        undef $destroyed;
        doneButtonPressed();
        return;
      }
                    } );
        }
      OSCAR::Configurator::Configurator_ui $top;  # Call specPerl window creator
    }

  # Then create the scrollable package listing and place it in the grid.
  populateConfiguratorList();

  $root->MapWindow;   # Put the window on the screen.
  
  return $root;       # Return pointer to new window to calling function
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
