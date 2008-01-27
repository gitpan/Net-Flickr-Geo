# $Id: Build.PL,v 1.4 2008/01/27 19:14:37 asc Exp $

use strict;
use Module::Build;

my $build = Module::Build->new(module_name => 'Net::Flickr::Geo',
			       # dist_author
			       # dist_abstract
			       dist_version_from => 'lib/Net/Flickr/Geo.pm',
			       license           => 'perl',
			       requires => {
                                            'Config::Simple'  => '0',
                                            'Net::Flickr::API'     => '>= 1.67',
                                            'Flickr::Upload' => '1.25',
                                            'LWP::UserAgent'        => '0',
                                            'LWP::Simple'        => '0',
                                            'HTTP::Request' => 0,
                                            'URI' => 0,
                                            'Geo::Coordinates::DecimalDegrees'   => '0',
                                            'MIME::Base64'      => '0',
                                            'Image::Size' => 0,
                                            'GD' => '>= 2.35',
                                            'Imager' => '>= 0.62',
			       },
			       build_requires => {
				   'Test::Simple'              => '>= 0.47',
			       },
			       create_readme      => 1,
			       create_makefile_pl => 'passthrough');

$build->create_build_script();
