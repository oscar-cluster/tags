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
use OSCAR::Package;   # For list_pkg()
use OSCAR::Logger;    # For oscar_log_section()
use OSCAR::Selector;
use XML::Simple;      # Read/write the .selection config files
use Tk::Pane; 

my($top);       # The Toplevel widget for the package configuration window
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
  # Configuration window.  Therefore, when we exit, unmap the window.  If
  # there is no parent, then it IS a MainWindow, so destroy the window.
  $root->Parent ? $root->UnmapWindow : $root->destroy;

  # If there are any children, make sure they are unmapped.
  my (@kids) = $root->children;
  foreach my $kid (@kids)
    {
      $kid->UnmapWindow;
    }

  # Write out a message to the OSCAR log
  oscar_log_subsection("Step 2: Completed successfully");
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
          $tempframe = $pane->Frame()->pack(-side => 'top',
                                            -fill => 'x');
          # Then add the config buttons and package names
          # First the Config button
          $tempframe->Button(
            -text => 'Config',
            #-state => ((-s "$oscarbasedir/packages/$package/configurator.html") ?
            #          'active' : 'disabled'),
            -command => [ \&OSCAR::Configbox::configurePackage,
                          $root,
                          "$oscarbasedir/packages/$package",
                        ],
            )->pack(-side => 'left');

          # Finally, the package name label
          $tempframe->Label(
            -text => $packagexml->{$package}{name},
            )->pack(-side => 'left');
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
  my($parent) = @_;

  # Check to see if our toplevel configurator window has been created yet.
  if (!$top)
    { # Create the toplevel window just once
      if ($parent)
        {
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
  oscar_log_section("Running step 2 of the OSCAR wizard");
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
