use strict;
# $Id: ModestMaps.pm,v 1.31 2008/03/17 15:59:13 asc Exp $

package Net::Flickr::Geo::ModestMaps;
use base qw(Net::Flickr::Geo);

$Net::Flickr::Geo::ModestMaps::VERSION = '0.65';

=head1 NAME

Net::Flickr::Geo::ModestMaps - tools for working with geotagged Flickr photos and Modest Maps

=head1 SYNOPSIS

 my %opts = ();
 getopts('c:s:', \%opts);

 #
 # Defaults
 #

 my $cfg = Config::Simple->new($opts{'c'});

 #
 # Atkinson dithering is hawt but takes a really long
 # time...
 #

 $cfg->param("modestmaps.filter", "atkinson");
 $cfg->param("modestmaps.timeout", (45 * 60));

 #
 # Let's say all but one of your photos are in the center of
 # Paris and the last one is at the airport. If you try to render
 # a 'poster style' (that is all the tiles for the bounding box
 # containing those points at street level) map you will make 
 # your computer cry...
 #

 $cfg->param("pinwin.skip_photos", [506934069]);

 #
 # I CAN HAS MAPZ?
 #

 my $fl = Net::Flickr::Geo::ModestMaps->new($cfg);
 $fl->log()->add(Log::Dispatch::Screen->new('name' => 'scr', min_level => 'info'));

 my $map_data = $fl->mk_poster_map_for_photoset($opts{'s'});

 #
 # returns stuff like :
 #
 # {
 #  'url' => 'http://127.0.0.1:9999/?provider=YAHOO_AERIAL&marker=yadda yadda yadda',
 #  'image-height' => '8528',
 #  'marker-484080715' => '5076,5606,4919,5072,500,375',
 #  'marker-506435771' => '5256,4768,5099,542,500,375',
 #  'path' => '/tmp/dkl0o7uxjY.jpg',
 #  'image-width' => '6656',
 # }
 #

 my $results = $fl->upload_poster_map($map_data->{'path'});

 #
 # returns stuff like :
 #
 # [
 #   ['/tmp/GGsf4552h.jpg', '99999992'],
 #   ['/tmp/kosfGgsfdh.jpg', '99999254'],
 #   ['/tmp/h354jF590.jpg', '999984643'],
 #   [ and so on... ] 
 # ];
 #

=head1 DESCRIPTION

Tools for working with geotagged Flickr photos and the Modest Maps ws-pinwin HTTP service.


=cut

=head1 OPTIONS

Options are passed to Net::Flickr::Backup using a Config::Simple object or
a valid Config::Simple config file. Options are grouped by "block".

=head2 flickr

=over 4

=item * B<api_key>

String. I<required>

A valid Flickr API key.

=item * B<api_secret>

String. I<required>

A valid Flickr Auth API secret key.

=item * B<auth_token>

String. I<required>

A valid Flickr Auth API token.

The B<api_handler> defines which XML/XPath handler to use to process API responses.

=over 4 

=item * B<LibXML>

Use XML::LibXML.

=item * B<XPath>

Use XML::XPath.

=back

=back

=head2 pinwin

=item * B<map_height>

The height of the background map on which the pinwin/thumbnail will be
placed.

Default is 1024.

=item * B<map_width>

The width of the background map on which the pinwin/thumbnail will be
placed.

Default is 1024.

=item * B<upload>

Boolean.

Automatically upload newly create map images to Flickr. Photos will be tagged with the following machine tags :

=over 4

=item * B<flickr:photo=photo_id>

Where I<photo_id> is the photo that has been added to the map image.

=item * B<flickr:map=pinwin>

=back

Default is false.

=item * B<upload_public>

Boolean.

Mark pinwin uploads to Flickr as viewable by anyone.

Default is false.

=item * B<upload_friend>

Boolean.

Mark pinwin uploads to Flickr as viewable only by friends.

Default is false.

=item * B<upload_family>

Boolean.

Mark pinwin uploads to Flickr as viewable only by family.

Default is false.

=item * B<photo_size>

String.

The string label for the photo size to display, as defined by the flickr.photos.getSizes
API method : 

 http://www.flickr.com/services/api/flickr.photos.getSizes.html

Default is I<Medium>

=item * B<zoom>

Int.

By default, the object will try to map the (Flickr) accuracy to the corresponding
zoom level of the Modest Maps provider you have chosen. If this option is defined
then it will be used as the zoom level regardless of what Flickr says.

=item * B<crop_width>

Int.

Used by the I<crop_poster_map> (and by extension I<upload_poster_map>) object methods to
define the width of each slice taken from a poster map.

Default is 1771

=item * B<crop_height>

Int.

Used by the I<crop_poster_map> (and by extension I<upload_poster_map>) object methods to
define the height of each slice taken from a poster map.

Default is 1239

=item * B<skip_photos>

Int (or array reference of ints)

Used by I<photoset> related object methods, a list of photos to exclude from the list
returned by the Flickr API.

=item * B<skip_tags>

String (or array reference of strings)

Used by I<photoset> related object methods, a list of tags that all photos must B<not> have if
they are to be included in the final output.

=item * B<ensure_tags>

String (or array reference of strings)

Used by I<photoset> related object methods, a list of tags that all photos must have if
they are to be included in the final output.

=head2 modestmaps

=over 4

=item * B<server>

The URL to a server running the ws-pinwin.py HTTP interface to the 
ModestMaps tile-creation service.

This requires Modest Maps 1.0 release or higher.

=item * B<provider>

A map provider and tile format for generating map images.

As of this writing, current providers are :

=over 4

=item * B<MICROSOFT_ROAD>

=item * B<MICROSOFT_AERIAL>

=item * B<MICROSOFT_HYBRID>

=item * B<GOOGLE_ROAD>

=item * B<GOOGLE_AERIAL>

=item * B<GOOGLE_HYBRID>

=item * B<YAHOO_ROAD>

=item * B<YAHOO_AERIAL>

=item * B<YAHOO_HYBRID>

=back 

=item * B<method>

Used only when creating poster maps, the method parameter defines how the underlying
map is generated. Valid options are :

=over 4

=item * B<extent>

Render map tiles at a suitable zoom level in order to fit the bounding
box (for all the images in a photoset) in an image with specific dimensions
(I<pinwin.map_height> and I<pinwin.map_width>).

=item * B<bbox>

Render all the map tiles necessary to display the bounding box (for all the
images in a photoset) at a specific zoom level.

=back

Default is bbox.

=item * B<bleed>

If true then extra white space will be added the underlying image in order to
fit any markers that may extend beyond the original dimensions of the map.

Boolean.

Default is true.

=item * B<adjust>

Used only when creating poster maps, the adjust parameter tells the modest maps server
to extend bbox passed by I<n> kilometers. This is mostly for esthetics so that there is
a little extra map love near pinwin located at the borders of a map.

Boolean.

Default is .25

=item * B<filter>

Tell the Modest Maps server to filter the rendered map image before applying an markers.
Valid options are :

=over 4

=item * B<atkinson>

Apply the Atkinson dithering filter to the map image.

This is brutally slow. Especially for poster maps. That's life.

=back

=item * B<timeout>

Int.

The number of seconds the object's HTTP handler will wait when requesting data from the 
Modest Maps server.

Default is 300 seconds.

=back

=cut

use Data::Dumper;
use FileHandle;
use GD;
use Imager;
use URI;

=head1 PACKAGE METHODS

=cut

=head2 __PACKAGE__->new($cfg)

Returns a I<Net::Flickr::Geo> object.

=cut

# Defined in Net::Flickr::API

=head1 OBJECT METHODS

=cut

=head2 $obj->mk_pinwin_map_for_photo($photo_id)

Fetch a map using the Modest Maps ws-pinwin API for a geotagged Flickr photo
and place a "pinwin" style thumbnail of the photo over the map's marker.

Returns an array of arrays  (kind of pointless really, but at least consistent).

The first element of the (second-level) array will be the path to the newly created map
image. If uploads are enabled the newly created Flickr photo ID will be
passed as the second element.

=cut

# Defined in Net::Flickr::Geo

=head2 $obj->mk_pinwin_maps_for_photoset($photoset_id)

For each geotagged photo in a set, fetch a map using the Modest Maps
ws-pinwin API for a geotagged Flickr photo and place a "pinwin" style
thumbnail of the photo over the map's marker.

If uploads are enabled then each map for a given photo will be
added such that it appears before the photo it references.

Returns an array of arrays.

The first element of each (second-level) array reference will be the path to the newly
created map image. If uploads are enabled the newly created Flickr photo
ID will be passed as the second element.

=cut

# Defined in Net::Flickr::Geo

=head2 $obj->mk_poster_map_for_photoset($set_id)

For each geotagged photo in a set, plot the latitude and longitude and
create a bounding box for the collection. Then fetch a map for that box
using the Modest Maps ws-pinwin API for a geotagged Flickr photo and place
a "pinwin" style thumbnail for each photo in the set.

Automatic uploads are not available for this method since the resultant
images will almost always be too big.

Returns a hash reference containing the URL that was used to request the
map image, the path to the data that was sent back as well as all of the
Modest Maps specific headers sent back.

=cut

sub mk_poster_map_for_photoset {
        my $self   = shift;
        my $set_id = shift;

        my $ph_size = $self->divine_option("pinwin.photo_size", "Medium");
        my $provider = $self->divine_option("modestmaps.provider");
        my $method = $self->divine_option("modestmaps.method", "bbox");
        my $bleed = $self->divine_option("modestmaps.bleed", 1);
        my $adjust = $self->divine_option("modestmaps.adjust", .25);
        my $filter = $self->divine_option("modestmaps.filter", );

        my $upload = $self->divine_option("pinwin.upload", 0);

        # 

        my $photos = $self->collect_photos_for_set($set_id);

        if (! $photos){
                return undef;
        }

        my $ne_lat = undef;
        my $ne_lon = undef;

        my $sw_lat = undef;
        my $sw_lon = undef;

        my %urls = ();
        my @markers = ();
        my @poly = ();

        foreach my $ph (@$photos){

                my $id = $ph->getAttribute("id");

                my $ph_url = $self->flickr_photo_url($ph);
                $urls{$id} = $ph_url;

                my $sz = $self->api_call({'method' => 'flickr.photos.getSizes',
                                          'args' => {'photo_id' => $id,}});
                
                my $sm = ($sz->findnodes("/rsp/sizes/size[\@label='$ph_size']"))[0];
                my $w = $sm->getAttribute("width");
                my $h = $sm->getAttribute("height");

                my $lat = $ph->getAttribute("latitude");
                my $lon = $ph->getAttribute("longitude");

                push @poly, "$lat,$lon";

                if ((! defined($sw_lat)) || ($lat < $sw_lat)){
                    $sw_lat = $lat;
                }

                if ((! defined($ne_lat)) || ($lat > $ne_lat)){
                    $ne_lat = $lat;
                }

                if ((! defined($sw_lon)) || ($lon < $sw_lon)){
                    $sw_lon = $lon;
                }

                if ((! defined($ne_lon)) || ($lon > $ne_lon)){
                    $ne_lon = $lon;
                }

                push @markers, "$id,$lat,$lon,$w,$h";
        }

        my $bbox = "$sw_lat,$sw_lon,$ne_lat,$ne_lon";

        #
        # fetch the actual map
        #

        # @markers = splice(@markers, 0, 3);

        my %mm_args = (
                       'provider' => $provider,
                       'method' => $method,
                       'bleed' => $bleed,
                       'adjust' => $adjust,
                       'bbox' => $bbox,
                       # 'polyline' => join(":", @poly),
                       'marker' => \@markers,
                   );

        if ($method eq "extent"){
                $mm_args{'width'} = $self->divine_option("pinwin.map_width", 1024);
                $mm_args{'height'} = $self->divine_option("pinwin.map_height", 1024);
        }

        else {
                $mm_args{'zoom'} = $self->divine_option("pinwin.zoom", 17);                
        }

        if ($filter){
                $mm_args{'filter'} = $filter;
        }

        if (my $convex = $self->divine_option("modestmaps.convex")){
                $mm_args{'convex'} = $convex;
        }

        $self->log()->info(Dumper(\%mm_args));

        my $map_data  = $self->fetch_modestmap_image(\%mm_args);
        
        if (! $map_data){
                return undef;
        }

	# return $map_data;

        #
        # place the markers
        # 

        my @images = ();

        foreach my $prop (%$map_data){

                if ($prop =~ /^marker-(.*)$/){

                        my $id = $1;
                        
                        my $ph_url = $urls{$id};
                        my $ph_img = $self->mk_tempfile(".jpg");
                        
                        if (! $self->simple_get($ph_url, $ph_img)){
                                next;
                        }

                        my @pw_details = split(",", $map_data->{$prop});
                        my $pw_x = $pw_details[2];
                        my $pw_y = $pw_details[3];
                        my $pw_w = $pw_details[4];
                        my $pw_h = $pw_details[5];

                        push @images, [$ph_img, $pw_x, $pw_y, $pw_w, $pw_h];
                }
        }

        my $out = $self->place_marker_images($map_data->{'path'}, \@images);
        $map_data->{'path'} = $out;

	return $map_data;
}

=head2 $obj->upload_poster_map($poster_map)

Take a file created by the I<mk_poster_map_for_photoset> and chop it up
in "postcard-sized" pieces and upload each to Flickr.

Returns an array of arrays.

The first element of the (second-level) array will be the path to the newly created map
image. If uploads are enabled the newly created Flickr photo ID will be
passed as the second element.

=cut

sub upload_poster_map {
        my $self = shift;
        my $map = shift;

        my $slices = $self->crop_poster_map($map);
        my @res = shift;

        foreach my $img (@$slices){

                my %args = ('photo' => $img);
                my $id = $self->upload_image(\%args);
                
                push @res, [$img, $id];
                unlink($img);
        }

        return \@res;
}

=head2 $obj->crop_poster_map($poster_map)

Take a file created by the I<mk_poster_map_for_photoset> and chop it up
in "postcard-sized" pieces.

The height and width of each piece are defined by the I<pinwin.crop_width> and
I<pinwin.crop_height> config options.

Any image whose cropping creates a file smaller than either dimension will
be padded with extra (white) space.

Returns a list of files.

=cut

sub crop_poster_map {
        my $self = shift;
        my $map = shift;

        my $crop_width = $self->divine_option("pinwin.crop_width", 1771);
        my $crop_height = $self->divine_option("pinwin.crop_width", 1239);

        my $offset_x = 0;
        my $offset_y = 0;

        my @slices = ();

        my $im = Imager->new();
        $im->read('file' => $map);

        my $map_h = $im->getheight();
        my $map_w = $im->getwidth();

        while ($offset_x < $map_w) {

                while ($offset_y < $map_h) {

                        my $x = $offset_x;
                        my $y = $offset_y;

                        my $slice = $im->crop('left' => $x, 'top' => $y, 'width' => $crop_width, 'height' => $crop_height);

			my $h = $slice->getheight();
                        my $w = $slice->getwidth();
                        
                        if (($h < $crop_height) || ($w < $crop_width)){

                                my $canvas = Imager->new('xsize' => $crop_width, 'ysize' => $crop_height);
                                $canvas->box('color' => 'white', 'xmin' => 0, 'ymin' => 0, 'xmax' => $crop_width, 'ymax' => $crop_height, 'filled' => 1);
                                $canvas->paste('img' => $slice, 'left' => 0, 'top' => 0);
                                push @slices, $canvas;
                        }

                        else {
                        	push @slices, $slice;
	                }

                        $offset_y += $crop_height;
                }

                $offset_x += $crop_width;
                $offset_y = 0;
        }

        my @files = ();

        foreach my $im (@slices) {
                my $out = $self->mk_tempfile(".png");
                $self->log()->info("write slice $out");

                $im->write('file' => $out);
                push @files, $out;
        }

        return \@files;
}

#
# not so public
#

sub fetch_map_image {
        my $self = shift;
        my $ph = shift;
        my $thumb_data = shift;

        my $lat = $self->get_geo_property($ph, "latitude");
        my $lon = $self->get_geo_property($ph, "longitude");
        my $acc = $self->get_geo_property($ph, "accuracy");

        if ((! $lat) || (! $lon)){
                return undef;
        }

        # 

        my $zoom = $self->flickr_accuracy_to_zoom($acc);
        $self->log()->info("zoom to $zoom ($acc)");

        #

        my $out = $self->mk_tempfile(".png");

        my $provider = $self->divine_option("modestmaps.provider");
        my $bleed = $self->divine_option("modestmaps.bleed");
        my $filter = $self->divine_option("modestmaps.filter");
        $zoom = $self->divine_option("modestmaps.zoom", $zoom);

        # 

        my @marker = (
                      'thumbnail',
                      $lat, $lon,
                      $thumb_data->{'width'}, $thumb_data->{'height'}
                     );


        my $height = $self->divine_option("pinwin.map_height", 1024);
        my $width = $self->divine_option("pinwin.map_width", 1024);

        my %mm_args = (
                    'provider' => $provider,
                    'latitude' => $lat,
                    'longitude' => $lon,
                    'zoom' => $zoom,
                    'method' => 'center',
                    'height' => $height,
                    'width' => $width,
                    'bleed' => $bleed,
                    'marker' => join(",", @marker),
                   );

        if ($filter){
                $mm_args{'filter'} = $filter;
        }

        $self->log()->info(Dumper(\%mm_args));
        return $self->fetch_modestmap_image(\%mm_args, $out);
}

sub flickr_accuracy_to_zoom {
        my $self = shift;
        my $acc = shift;

        my $provider = $self->divine_option("modestmaps.provider");
        $provider =~ /^([^_]+)_/;
        my $short = lc($1);

        if ($short eq 'yahoo'){
                return $acc;
        }

        else {
                return $acc + 1;
        }

}

sub fetch_modestmap_image {
        my $self = shift;
        my $args = shift;
        my $out = shift;

        $out ||= $self->mk_tempfile(".jpg");

        my $timeout = $self->divine_option("modestmaps.timeout", (5 * 60));
        my $remote = $self->divine_option("modestmaps.server");

        $self->log()->info("fetch from $remote w/timeout : $timeout");

        my $uri = URI->new($remote);
        $uri->query_form(%$args);
        my $url = $uri->as_string();

        my $ua = LWP::UserAgent->new();
        $ua->timeout($timeout);

        # hello POST?

        my $req = HTTP::Request->new('GET' => $url);
        my $res = $ua->request($req);

        my $status = $res->code();

        if ($status != 200){

                my $h = $res->headers();
                my $code = $h->header('x-errorcode');
                my $msg = $h->header('x-errormessage');
                $self->log()->error("http error : $status - modest maps server error : $code ($msg)");
                return;
        }

        my $fh = FileHandle->new(">$out");
        binmode($fh);

        $fh->print($res->content());
        $fh->close();

        my %data = (
                    'url' => $url,
                    'path' => $out,
                   );
        
        my $headers = $res->headers();

        foreach my $field ($headers->header_field_names()){

                if ($field =~/^X-wscompose-(.*)$/i){
                        $data{lc($1)} = $headers->header($field);
                }
        }

        $self->log()->info("received modest map image and stored in $out");
        return \%data;
}

sub modify_map {
        my $self = shift;
        my $ph = shift;
        my $map_data = shift;
        my $thumb_data = shift;

        my @pw_details = split(",", $map_data->{'marker-thumbnail'});
        my $pw_x = $pw_details[2];
        my $pw_y = $pw_details[3];
        my $pw_w = $pw_details[4];
        my $pw_h = $pw_details[5];
        
        my @images = ([$thumb_data->{path}, $pw_x, $pw_y, $pw_w, $pw_h]);

        return $self->place_marker_images($map_data->{'path'}, \@images);
}

sub place_marker_images {
        my $self = shift;
        my $map_img = shift;
        my $markers = shift;

        # use GD instead of Imager because the latter has
        # a habit of rendeing the actual thumbnails all wrong...

        # ensure the truecolor luv to prevent nasty dithering

        my $truecolor = 1;
        
        my $im = GD::Image->newFromPng($map_img, $truecolor);

        foreach my $data (@$markers){
                my ($mrk_img, $x, $y, $w, $h) = @$data;
                my $ph = GD::Image->newFromJpeg($mrk_img, $truecolor);
                $im->copy($ph, $x, $y, 0, 0, $w, $h);

                unlink($mrk_img);
        }

        my $out = $self->mk_tempfile(".jpg");
        my $fh = FileHandle->new(">$out");

        binmode($fh);
        $fh->print($im->jpeg(100));
        $fh->close();

        unlink($map_img);
        return $out;
}

=head1 VERSION

0.65

=head1 DATE

$Date: 2008/03/17 15:59:13 $

=head1 AUTHOR

Aaron Straup Cope  E<lt>ascope@cpan.orgE<gt>

=head1 EXAMPLES

L<http://flickr.com/photos/straup/tags/modestmaps/>

=head1 REQUIREMENTS

Modest Maps 1.0 or higher. 

L<http://modestmaps.mapstraction.com/>

=head1 NOTES

All uploads to Flickr are marked with a content-type of "other".

=head1 SEE ALSO

L<Net::Flickr::Geo>

L<http://modestmaps.com/>

L<http://mike.teczno.com/notes/oakland-crime-maps/IX.html>

=head1 BUGS

Sure, why not.

Please report all bugs via L<http://rt.cpan.org>

=head1 LICENSE

Copyright (c) 2007-2008 Aaron Straup Cope. All Rights Reserved.

This is free software. You may redistribute it and/or
modify it under the same terms as Perl itself.

=cut

return 1;
