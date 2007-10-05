package OSCAR::ImageMgt;

#
# Copyright (c) 2007 Geoffroy Vallee <valleegr@ornl.gov>
#                    Oak Ridge National Laboratory
#                    All rights reserved.
#
#   $Id: ImageMgt.pm 4833 2006-05-24 08:22:59Z bli $
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
# This package provides a set of function for OSCAR image management. This has
# initialy be done to avoid code duplication between the CLI and the GUI.
#

use strict;
use lib "$ENV{OSCAR_HOME}/lib","/usr/lib/systeminstaller";
use lib "/usr/lib/systeminstaller","/usr/lib/systemimager/perl";
use OSCAR::Logger;
use OSCAR::PackagePath;
use OSCAR::Database;
use OSCAR::Utils qw (
                    is_element_in_array
                    print_array 
                    );
use SystemImager::Server;
use OSCAR::Opkg qw ( create_list_selected_opkgs );
use SystemInstaller::Tk::Common;
use Data::Dumper;
use vars qw(@EXPORT);
use base qw(Exporter);
use Carp;

@EXPORT = qw(
            delete_image
            do_setimage
            do_post_binary_package_install
            do_oda_post_install
            get_image_default_settings
            get_list_corrupted_images
            );

################################################################################
# Set the image in the Database.                                               #
# Parameter: img, image name.                                                  #
#            options, hash with option values.                                 #
# Return   : None.                                                             #
################################################################################
sub do_setimage {
    my ($img, %options) = @_;
    my @errors = ();

    my $master_os = OSCAR::PackagePath::distro_detect_or_die("/");
    my $arch = $master_os->{arch};

    # Get the image path (typically /var/lib/systemimager/images/<imagename>)
    my $config = SystemInstaller::Tk::Common::init_si_config();
    my $imaged = $config->default_image_dir;
    croak "default_image_dir not defined\n" unless $imaged;
    croak "$imaged: not a directory\n" unless -d $imaged;
    croak "$imaged: not accessible\n" unless -x $imaged;
    my $imagepath = $imaged."/".$img;
    croak "$imagepath: not a directory\n" unless -d $imagepath;
    croak "$imagepath: not accessible\n" unless -x $imagepath;

    #
    # Image info lines should be deleted once systeminstaller
    # talks directly to ODA
    #
    my %image_info = ( "name"        => $img,
               #
               # EF: OS_Detect detects images now, use that!
               #
               # "distro"=>"$distroname-$distroversion",
              "architecture" => $arch,
              "path"         => $imagepath);

    OSCAR::Database::set_images(\%image_info, \%options, \@errors);
}

################################################################################
# Simple wrapper around post_rpm_install; make sure we call correctly the      #
# script.                                                                      #
# Input: img, image name.                                                      #
#        interface, network interface id used by OSCAR.                        #
# Return: none.                                                                #
################################################################################
sub do_post_binary_package_install{
    my $img = shift;
    my $interface = shift;
    my $cwd = `pwd`;
    chdir "$ENV{OSCAR_HOME}/scripts/";
    my $cmd = "$ENV{OSCAR_HOME}/scripts/post_rpm_install $img $interface";

    !system($cmd) or (carp($!), return undef);
    oscar_log_subsection("Successfully ran: $cmd");

    chdir "$cwd";
}

################################################################################
# Simple wrapper around post_rpm_install; make sure we call correctly the      #
# script.                                                                      #
# Input: vars, hash with variable values.                                      #
#        options, hash with option values.                                     #
# Return: none.                                                                #
################################################################################
sub do_oda_post_install {
    my (%vars, %options) = @_;
    my @errors = ();
    my $img = $vars{imgname};

    # Have installed Client binary packages and did not croak, so mark
    # packages. <pkg>installed # true. (best effort for now)

    oscar_log_subsection("Marking installed bit in ODA for client binary ".
                         "packages");

    my @opkgs = list_selected_packages("all");
    foreach my $opkg_ref (@opkgs)
    {
        my $opkg = $$opkg_ref{package};
        oscar_log_subsection("Set package: $opkg");
        OSCAR::Database::set_image_packages($img,$opkg,\%options,\@errors);
    }
    oscar_log_subsection("Done marking installed bits in ODA");

    #/var/log/lastlog could be huge in some horked setup packages...
    croak "Image name not defined\n" unless $img;
    my $lastlog = "/var/log/lastlog";
    oscar_log_subsection("Truncating ".$img.":".$lastlog);

    my $config = init_si_config();
    my $imaged = $config->default_image_dir;
    my $imagepath = $imaged."/".$img;
    my $imagelog = $imagepath.$lastlog;
    truncate $imagelog, 0 if -s $imagelog;
    oscar_log_subsection("Truncated ".$img.":".$lastlog);

    oscar_log_subsection("Image build successfully");
}

###############################################################################
# Get the fstab stuff based on the architecture and the type of disk          #
# Input: arch, target architecture.                                           #
#        disk_type, target disk type (e.g. IDE, SCSI).                        #
# Return: file path the fstab stuff.                                          #
###############################################################################
sub get_disk_file {
    my ($arch, $disk_type) = @_;

    my $diskfile = "$ENV{OSCAR_HOME}/oscarsamples/$disk_type";
    #ia64 needs special disk file because of /boot/efi
    $diskfile .= ".$arch" if $arch eq "ia64";
    $diskfile .= ".disk";

    return $diskfile;
}

################################################################################
# Get the default settings for the creation of new images.                     #
# !!WARNNING!! We do not set postinstall and title. The distro is also by      #
# default the local distro.                                                    #
# Input: none.                                                                 #
# Output: default settings (via a hash).                                       #
# TODO: fix the problem with the distro parameter.                             #
################################################################################
sub get_image_default_settings {
    my $oscarsamples_dir = "$ENV{OSCAR_HOME}/oscarsamples";
    my @df_lines = `df /`;
    my $disk_type = "ide";
    $disk_type = "scsi" if (grep(/\/dev\/sd/,(@df_lines)));

    #Get the distro list
    my $master_os = OSCAR::PackagePath::distro_detect_or_die("/");
    my $arch = $master_os->{arch};

    my $distro = $master_os->{compat_distro};
    my $distro_ver = $master_os->{compat_distrover};

    my $distro_pool = OSCAR::PackagePath::distro_repo_url("/");
    $distro_pool =~ s/\ /,/g;
    my $oscar_pool = OSCAR::PackagePath::oscar_repo_url("/");

    oscar_log_subsection("Identified distro of clients: $distro $distro_ver");
    oscar_log_subsection("Distro repo: $distro_pool");
    oscar_log_subsection("OSCAR repo: $oscar_pool");

    my $pkglist = "$oscarsamples_dir/$distro-$distro_ver-$arch.rpmlist";
    oscar_log_subsection("Using binary list: $pkglist");

    # Get a list of client RPMs that we want to install.
    # Make a new file containing the names of all the RPMs to install

    my $outfile = "/tmp/oscar-install-rpmlist.$$";
    create_list_selected_opkgs ($outfile);
    my @errors;
    my $save_text = $outfile;
    my $extraflags = "--filename=$outfile";
    # WARNING!! We deactivate the OPKG management via SystemInstaller
    $extraflags = "";
    if (exists $ENV{OSCAR_VERBOSE}) {$extraflags .= " --verbose";}

    my $diskfile = get_disk_file($arch, $disk_type);

    my $config = init_si_config();

    # Default settings
    my %vars = (
           imgpath => "/var/lib/systemimager/images",
           imgname => "oscarimage",
           arch => $arch,
           pkgfile => $pkglist,
           pkgpath => "$oscar_pool,$distro_pool",
           diskfile => $diskfile,
           ipmeth => "static",
           piaction => "reboot",
           distro => "$distro",
           extraflags => $extraflags
           );

    return %vars;
}

################################################################################
# Delete an existing image.                                                    #
# Input: imgname, image name.                                                  #
# Output: none.                                                                #
# TODO: We need to update the OSCAR database when deleting an image.           #
################################################################################
sub delete_image {
    my $imgname = shift;

    my $config = init_si_config();
    my $rsyncd_conf = $config->rsyncd_conf();
    my $rsync_stub_dir = $config->rsync_stub_dir();

    system("mksiimage -D --name $imgname");
    SystemImager::Server->remove_image_stub($rsync_stub_dir, $imgname);
    SystemImager::Server->gen_rsyncd_conf($rsync_stub_dir, $rsyncd_conf);
}

################################################################################
# Get the list of corrupted images. An image is concidered corrupted when info #
# from the OSCAR database, the SIS database and the file system are not        #
# synchronized.                                                                #
# Input: None.                                                                 #
# Output: an array of hash; each element of the array (hash) has the following #
#         format ( 'name' => <image_name>,                                     #
#                  'oda' => "ok"|"missing",                                    #
#                  'sis' => "ok"|"missing",                                    #
#                  'fs' => "ok"|"missing" ).                                   #
################################################################################
sub get_list_corrupted_images {
    my $sis_cmd = "/usr/bin/si_lsimage";
    my @sis_images = `$sis_cmd`;
    my @result;

    #We do some cleaning...
    # We remove the three useless lines of the result
    for (my $i=0; $i<3; $i++) {
        shift (@sis_images);
    }
    # We also remove the last line which is an empty line
    pop (@sis_images);
    # Then we remove the return code at the end of each array element
    # We also remove the 2 spaces before each element
    foreach my $i (@sis_images) {
        chomp $i;
        $i = substr ($i, 2, length ($i));
    }

    # The array is now clean, we can print it
    print "List of images in the SIS database: ";
    print_array (@sis_images);

    my @tables = ("Images");
    my @oda_images = ();
    my @res = ();
    my $cmd = "SELECT Images.name FROM Images";
    if ( OSCAR::Database::single_dec_locked( $cmd,
                                             "READ",
                                             \@tables,
                                             \@res,
                                             undef) ) {
    # The ODA query returns a hash which is very unconvenient
    # We transform the hash into a simple array
    foreach my $elt (@res) {
        # It seems that we always have an empty entry, is it normal?
        if ($elt->{name} ne "") {
            push (@oda_images, $elt->{name});
        }
    }
    print "List of images in ODA: ";
    print_array (@oda_images);
    } else {
        die ("ERROR: Cannot query ODA\n");
    }

    # We get the list of images from the file system
    my $sis_image_dir = "/var/lib/systemimager/images";
    my @fs_images = ();
    die ("ERROR: The image directory does not exist ".
         "($sis_image_dir)") if ( ! -d $sis_image_dir );
    opendir (DIRHANDLER, "$sis_image_dir")
        or die ("ERROR: Impossible to open $sis_image_dir");
    foreach my $dir (sort readdir(DIRHANDLER)) {
        if ($dir ne "."
            && $dir ne ".."
            && $dir ne "ACHTUNG"
            && $dir ne "DO_NOT_TOUCH_THESE_DIRECTORIES"
            && $dir ne "CUIDADO"
            && $dir ne "README") {
            push (@fs_images, $dir);
        }
    }
    print "List of images in file system: ";
    print_array (@fs_images);

    # We now compare the lists of images
    foreach my $image_name (@sis_images) {
        my %entry = ('name' => $image_name,
                     'sis' => "ok",
                     'oda' => "ok",
                     'fs' => "ok");
        if (!is_element_in_array($image_name, @oda_images)) {
            $entry{'oda'} = "missing";
        }
        if (!is_element_in_array($image_name, @fs_images)) {
            $entry{'fs'} = "missing";
        }
        push (@result, \%entry);
    }

    foreach my $image_name (@oda_images) {
        my %entry = ('name' => $image_name,
                     'sis' => "ok",
                     'oda' => "ok",
                     'fs' => "ok");
        if (!is_element_in_array($image_name, @sis_images)) {
            $entry{'sis'} = "missing";
        }
        if (!is_element_in_array($image_name, @fs_images)) {
            $entry{'fs'} = "missing";
        }
        push (@result, \%entry);
    }

    foreach my $image_name (@fs_images) {
        my %entry = ('name' => $image_name,
                     'sis' => "ok",
                     'oda' => "ok",
                     'fs' => "ok");
        if (!is_element_in_array($image_name, @sis_images)) {
            $entry{'sis'} = "missing";
        }
        if (!is_element_in_array($image_name, @oda_images)) {
            $entry{'oda'} = "missing";
        }
        push (@result, \%entry);
    }

    return (@result);
}