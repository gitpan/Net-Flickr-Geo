# $Id.pm,v 1.11 2007/06/07 06:55:36 asc Exp $

package Net::Flickr::Geo;
use base qw (Net::Flickr::API);

$Net::Flickr::Geo::VERSION = '0.4';

=head1 NAME 

Net::Flickr::Geo - tools for working with geotagged Flickr photos

=head1 SYNOPSIS

 use Config::Simple;
 use Net::Flickr::Geo;

 my $cfg = Config::Simple->new("/path/to/config");
 my $fl  = Net::Flickr::Geo->new($cfg);

 mt $id     = '99999999';
 my $upload = 1;

 my @res = $fl->mk_pinwin_map($id, $upload);

 # returns :
 # ['/tmp/GGsf4552h.jpg', '99999992'];


=head1 DESCRIPTION

Tools for working with geotagged Flickr photos.

=head1 OPTIONS

Options are passed to Net::Flickr::Backup using a Config::Simple object or
a valid Config::Simple config file. Options are grouped by "block".

=head2 flick

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

=over 4

=item * B<map_source>

Valid options are :

=over 4

=item * B<yahoo>

Fetch images using the Yahoo! Map Image API

=item * B<modestmaps>

Fetch images using the ModestMaps map tile composer.

ModestMaps is Python based and You will need to have a current version of the
ModestMaps libraries, and all its dependencies, installed whatever machine is
using Net::Flickr::Geo.

=back

Default is I<yahoo>.

=item * B<map_mode>

Convert the background map image to use a different colour scale.
Valid options are :

=over 4

=item * B<grey>

You know, black and white and all that grey in between.

=back

Default is none (or colour).

=item * B<map_height>

The height of the background map on which the pinwin/thumbnail will be
placed.

Default is 1024.

=item * B<map_width>

The width of the background map on which the pinwin/thumbnail will be
placed.

Default is 1024.

=item * B<map_radius>

Set the Yahoo! Map Image API 'radius' property. From the docs :

"How far (in miles) from the specified location to display on the map."

Default is none, and to use a zoom level that maps to the I<accuracy> property
of a photo.

=item * B<upload_public>

Mark pinwin uploads to Flickr as viewable by anyone.

Default is false.

=item * B<upload_friend>

Mark pinwin uploads to Flickr as viewable only by friends.

Default is false.

=item * B<upload_family>

Mark pinwin uploads to Flickr as viewable only by family.

Default is false.

=back 

=head2 yahoo

=over 4

=item * B<appid>

A valid Yahoo! developers API key.

=back

=head2 modestmaps

=over 4

=item * B<server>

The URL to a server running the ws-compose.py HTTP interface to the 
ModestMaps tile-creation service.

This requires Modest Maps revision 339 or higher.

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

=back

=cut

use File::Temp qw (tempfile);

use LWP::UserAgent;
use LWP::Simple;
use HTTP::Request;
use Geo::Coordinates::DecimalDegrees;
use Flickr::Upload;
use MIME::Base64;

=head1 PACKAGE METHODS

=cut

=head2 __PACKAGE__->new($cfg)

Returns a I<Net::Flickr::Geo> object.

=cut

# Defined in Net::Flickr::API

sub init {
        my $self = shift;
        my $args = shift;

        if (! $self->SUPER::init($args)){
                return undef;
        }

        my $b64 = '';

        {
                local $/;
                undef $/;
                $b64 = <DATA>;
        }

        my ($fh, $pinwin) = tempfile(UNLINK => 0, SUFFIX => ".png");

        $fh->print(MIME::Base64::decode_base64($b64));
        $fh->close();

        if (! -s $pinwin){
                $self->log()->error("failed to create pinwin ($pinwin)");
                return 0;
        }

        $self->log()->info("created temporary pinwin : $pinwin");
        $self->{'__pinwin'} = $pinwin;
        return 1;
}

=head1 OBJECT METHODS YOU SHOULD CARE ABOUT

=cut

=head2 $obj->mk_pinwin_map($photo_id, $upload=0, $out='')

Fetch a map using the Yahoo! Map Image API for a geotagged Flickr photo
and place a "pinwin" style thumbnail of the photo over the map's marker.

Returns a list.

The first element of the list will be the path to the newly created map
image. If uploads are enabled the newly created Flickr photo ID will be
passed as the second element.

=cut

sub mk_pinwin_map {
        my $self     = shift;
        my $photo_id = shift;
        my $upload   = shift;
        my $out      = shift;

        my $res = $self->api_call({'method' => 'flickr.photos.getInfo',
                                   'args'   => {'photo_id' => $photo_id}});

        if (! $res){
                return undef;
        }

        my $ph  = ($res->findnodes("/rsp/photo"))[0];
        my $map = $self->plot_photo($ph, $out);

        if (! $map){
                return undef;
        }

        my @res = ($map);

        if ($upload){
                my $id = $self->upload_map($ph, $map);
                push @res, $id;
        }

        return (\@res);
}

=head2 $obj->mk_pinwin_maps_for_set($set_id, $upload=0)

For each geotagged photo in a set, Ffetch a map using the Yahoo! Map
Image API for a geotagged Flickr photo and place a "pinwin" style
thumbnail of the photo over the map's marker.

If uploads are enabled then each map for a given photo will be
added such that it appears before the photo it references.

Returns a list of array references.

The first element of each array reference will be the path to the newly
created map image. If uploads are enabled the newly created Flickr photo
ID will be passed as the second element.

=cut

sub mk_pinwin_maps_for_set {
        my $self   = shift;
        my $set_id = shift;
        my $upload = shift;

        my $res = $self->api_call({'method' => 'flickr.photosets.getPhotos',
                                   'args' => {'photoset_id' => $set_id,
                                              'extras'      => 'geo, machine_tags'}});

        if (! $res){
                return undef;
        }

        my @maps = ();
        my @set  = ();

        my %ihasamapz = ();

        foreach my $ph ($res->findnodes("/rsp/photoset/photo")){

                my $id = $ph->getAttribute("id");
                my $mt = $ph->getAttribute("machine_tags");

                if ($mt =~ /\bflickr\:map\=pinwin\b/){

                        if ($mt =~ /\bflickr\:photo\=(\d+)\b/){
                                $ihasamapz{$1} = $id;
                        }
                       
                        $self->log()->info("photo id $id tagged pinwin, skipping");
                        next;
                }

                if (my $mapid = $ihasamapz{$id}){
                        $self->log()->info("photo id $id already has a map $mapid, skipping");
                        next;
                }

                if (! $ph->getAttribute("latitude")){
                        $self->log()->info("photo id $id has no geo information, skipping");
                        next;
                }

                # 

                my $map = $self->plot_photo($ph);

                if (! $map){
                        next;
                }

                my @local_res = ($map);

                if ($upload){
                        my $id = $self->upload_map($ph, $map);

                        push @local_res, $id;
                        push @set, $id;
                        push @set, $ph->getAttribute("id");
                }

                push @maps, \@local_res;
        }

        if (($upload) && (scalar(@set))) {
                $self->api_call({'method' => 'flickr.photosets.editPhotos',
                                 'args' => {'photoset_id'      => $set_id,
                                            'primary_photo_id' => $set[0],
                                            'photo_ids'        => join(",", @set)}});
        }

        return @maps;
}

=head2 $obj->mk_pinwin_maps_for_photoset($set_id, $upload)

This is just an alias for I<mk_pinwin_maps_for_photoset>.

=cut

sub mk_pinwin_maps_for_photoset {
        my $self = shift;
        $self->mk_pinwin_maps_for_set(@_);
}

sub plot_photo {
        my $self = shift;
        my $ph   = shift;
        my $out  = shift;

        $out ||= $self->mk_tempfile(".jpg");

        my $map  = $self->fetch_map_image($ph);

        if (! $map) {
                return undef;
        }

        my $thumb = $self->fetch_flickr_photo($ph, "thumb");

        if (! $thumb){
                return undef;
        }

        my $new = $self->modify_map($ph, $map, $thumb, $out);

        unlink($map);
        unlink($thumb);
        return $new;
}

sub fetch_flickr_photo {
        my $self = shift;
        my $ph = shift;

        my $id = $ph->getAttribute("id");
        my $fid = $ph->getAttribute("farm");
        my $sid = $ph->getAttribute("server");;
        my $secret = $ph->getAttribute("secret");
        
        my $static_url = "http://farm" . $fid . ".static.flickr.com/" . $sid . "/" . $id . "_" . $secret . "_s.jpg";
        return $self->simple_get($static_url, $self->mk_tempfile(".jpg"));
}

sub mk_tempfile {
        my $self = shift;
        my $ext  = shift;

        my ($fh, $filename) = tempfile(UNLINK => 0, SUFFIX => $ext);
        return $filename;
}

sub simple_get {
        my $self   = shift;
        my $remote = shift;       
        my $local  = shift;

        $local ||= $self->mk_tempfile();

        $self->log()->info("fetch remote file : $remote");
        $self->log()->info("store local file : $local");

        if (! getstore($remote, $local)){
                $self->log()->error("failed to retrieve remote URL ($remote)");
                return 0;
        }

        return $local;
}

sub fetch_map_image {
        my $self = shift;
        my $ph = shift;

        my $lat = $self->get_geo_property($ph, "latitude");
        my $lon = $self->get_geo_property($ph, "longitude");
        my $acc = $self->get_geo_property($ph, "accuracy");

        if ((! $lat) || (! $lon)){
                return undef;
        }

        my $src = $self->{'cfg'}->param("pinwin.map_source");

        if ($src eq "modestmaps"){
                return $self->fetch_modest_map_image($lat, $lon, $acc);
        }
        
        return $self->fetch_yahoo_map_image($lat, $lon, $acc);
}

sub fetch_modest_map_image {
        my $self = shift;
        my $lat  = shift;
        my $lon  = shift;
        my $acc  = shift;

        my $out = $self->mk_tempfile(".png");

        my $provider = $self->{'cfg'}->param("modestmaps.provider");

        $provider =~ /^([^_]+)_/;
        my $short = lc($1);

        $acc = $self->mk_flickr_accuracy($short . "_mm", $acc);

        if (my $enforced = $self->{'cfg'}->param("modestmaps.enforce_zoom")){
                if ($acc > $enforced){
                        $acc = $enforced;
                }
        }

        my $h = $self->pinwin_map_dimensions("height");
        my $w = $self->pinwin_map_dimensions("width");

        my $remote = $self->{'cfg'}->param("modestmaps.server");

        my $url = sprintf("%s?provider=%s&latitude=%s&longitude=%s&accuracy=%s&height=%s&width=%s",
                          $remote, $provider, $lat, $lon, $acc, $h, $w);

        return $self->simple_get($url, $out);
}

sub fetch_yahoo_map_image {
        my $self = shift;
        my $lat = shift;
        my $lon = shift;
        my $acc = shift;

        my $appid = $self->{'cfg'}->param("yahoo.appid");

        my $h = $self->pinwin_map_dimensions("height");
        my $w = $self->pinwin_map_dimensions("width");

        my $ua  = LWP::UserAgent->new();
        my $url = "http://local.yahooapis.com/MapsService/V1/mapImage?image_width=" . $w . "&image_height=" . $h . "&appid=" . $appid . "&latitude=" . $lat . "&longitude=" . $lon;

        if (my $r = $self->{'cfg'}->param("pinwin.map_radius")){
                $url .= "&radius=$r";
        }

        else {
                my $z = $self->mk_flickr_accuracy('yahoo', $acc);
                $url .= "&zoom=$z";
        }

        $self->log()->info("fetch yahoo map : $url");

        my $req = HTTP::Request->new(GET => $url);
        my $res = $ua->request($req);

        if (! $res->is_success()){
                $self->log()->error("failed to retrieve yahoo map : " . $res->code());
                return 0;
        }

        my $xml = $self->_parse_results_xml($res);

        if (! $xml){
                $self->log()->error("failed to parse yahoo api response");
                return 0;
        }
        
        my $map = $xml->findvalue("/Result");
        return $self->simple_get($map, $self->mk_tempfile(".png"));
}

sub mk_flickr_accuracy {
        my $self     = shift;
        my $provider = shift;
        my $acc      = shift;

        # yahoo : 1 (street) - 12 (country)
        # flickr : 1 (world) - 16 (street)
        
        my %map = ('yahoo' => {1 => 12,
                               2 => 12,
                               3 => 12,
                               4 => 11,
                               5 => 10,
                               6 => 9,
                               7 => 8,
                               8 => 7,
                               9 => 6,
                               10 => 5,
                               12 => 4,
                               13 => 3,
                               14 => 2,
                               15 => 1,
                               16 => 1},
                  );

        # 

        foreach my $i (1..17) {                
                foreach my $p ('google', 'microsoft', 'yahoo'){

                        my $key = $p . "_mm";
                        $map{$key} ||= {};
                        $map{$key}->{$i} = $i + 1;
                }
        }

        # 

        if (! exists($map{$provider})){
                return 0;
        }

        if (! exists($map{$provider}->{$acc})){
                return 0;
        }

        return $map{$provider}->{$acc};
}

sub modify_map {
        my $self  = shift;
        my $ph    = shift;
        my $map   = shift;
        my $thumb = shift;
        my $out   = shift;

        #

        my $pinwin = $self->{'__pinwin'};

        # work files

        my $grmap    = $self->mk_tempfile(".png");
        my $pinthumb = $self->mk_tempfile(".png");

        # place the thumb on the pinwin

        my $th_cmd = "composite -quality 100 -geometry +11+10 $thumb $pinwin $pinthumb";        

        $self->log()->info($th_cmd);     
        system($th_cmd);

        if ($self->{'cfg'}->param("pinwin.map_mode") eq "grey") {
                # create a greyscale map
                
                my $grmap  = $self->mk_tempfile(".jpg");                
                my $gr_cmd = "convert -quality 100 -colorspace GRAY $map $grmap";

                $self->log()->info($gr_cmd);     
                system($gr_cmd);

                $map = $grmap;
        }

        # place the pinwin on the map

        my $h = $self->pinwin_map_dimensions("height");
        my $w = $self->pinwin_map_dimensions("width");

        my $geo_h = int($h / 2) - 134;
        my $geo_w = int($w / 2) - 28;

        my $map_cmd = "composite -quality 100 -geometry +" . $geo_w . "+" . $geo_h . " $pinthumb $map $out";

        $self->log()->info($map_cmd);
        system($map_cmd);

        # clean up 

        unlink($grmap);
        unlink($flmap);
        unlink($pinthumb);

        return $out;
}

sub get_geo_property {
        my $self = shift;
        my $ph = shift;
        my $prop = shift;

        my $value = $ph->getAttribute($prop);

        if (! $value){
                $value = $ph->findvalue("location/\@" . $prop);
        }

        return $value;
}

sub pretty_print_latlong {
        my $self = shift;
        my $lat = shift;
        my $lon = shift;

        my @lat_dms = decimal2dms($lat);
        my $ns = ($lat_dms[3]) ? "N" : "S";

        my $str_lat = sprintf(qq(%d° %d' %d" $ns), @lat_dms);

        my @lon_dms = decimal2dms($lon);
        my $ew = ($lon_dms[3]) ? "E" : "W";

        my $str_lon = sprintf(qq(%d° %d' %d" $ew), @lon_dms);
        return "$str_lat, $str_lon";
}

sub upload_map {
        my $self = shift;
        my $ph   = shift;
        my $map  = shift;

        my $ua  = Flickr::Upload->new({'key'=> $self->{'cfg'}->param("flickr.api_key"),
                                       'secret' => $self->{'cfg'}->param("flickr.api_secret")});

        #

        my $lat = $self->get_geo_property($ph, "latitude");
        my $lon = $self->get_geo_property($ph, "longitude");
        my $title = $self->pretty_print_latlong($lat, $lon);

        my $tag = "flickr:photo=" . $ph->getAttribute("id");

        my $public = ($self->{'cfg'}->param("pinwin.upload_public")) ? 1 : 0;
        my $friend = ($self->{'cfg'}->param("pinwin.upload_friend")) ? 1 : 0;
        my $family = ($self->{'cfg'}->param("pinwin.upload_family")) ? 1 : 0;

        $self->log()->info("upload to flickr : $map ");
        $self->log()->info("meta : $title perms : $public; $friend; $family");

        my $id = undef;

        eval {
                $id = $ua->upload(
                            'photo'      => $map,
                                  'auth_token' => $self->{cfg}->param("flickr.auth_token"),
                                  'title'      => $title,
                                  'tags'       => "$tag flickr:map=pinwin",
                                  'is_public'  => $public,
                                  'is_friend'  => $friend,
                                  'is_family'  => $family,
                                 );
        };

        if (! $id) {
                $self->log()->error("failed to upload photo, $@");
                return;
        }

        # This is not a love song...

        $self->api_call({'method' => 'flickr.photos.setContentType',
                         'args' => {'photo_id' => $id, 'content_type' => 3}});


        $self->log()->info("photo uploaded with ID $id");
        return $id;
}

sub pinwin_map_dimensions {
        my $self = shift;
        my $prop = shift;

        my $v = $self->{'cfg'}->param("pinwin.map_" . $prop);
        $v ||= 1024;
        return $v;
}

sub DESTROY {
        my $self = shift;
        $self->log()->info("removing temporary pinwin : " . $self->{'__pinwin'});
        unlink($self->{'__pinwin'});
        $self->SUPER::DESTROY();
}

=head1 VERSION

0.4

=head1 DATE

$Date: 2007/08/26 04:26:50 $

=head1 AUTHOR

Aaron Straup Cope  E<lt>ascope@cpan.orgE<gt>

=head1 NOTES

All uploads to Flickr are marked with a content-type of "other".

=head1 IMPORTANT

B<This package requires that you have the command-line version of ImageMagick installed.>

It will be updated to use the Perl I<Image::Magick> libraries in future releases.

=head1 SEE ALSO

L<Net::Flickr::API>

L<http://developer.yahoo.com/maps/rest/V1/mapImage.html>

L<http://modestmaps.mapstraction.com/>

L<http://mike.teczno.com/notes/oakland-crime-maps/IX.html>

L<http://www.aaronland.info/weblog/2007/07/28/trees/#delmaps_pm>

L<http://www.aaronland.info/weblog/2007/06/08/pynchonite/#net-flickr-geo>

L<http://www.aaronland.info/weblog/2007/06/08/pynchonite/#nfg_mm>

L<http://flickr.com/photos/straup/sets/72157600321286227/>

L<http://www.flickr.com/help/filters/>

=head1 BUGS

Sure, why not.

Please report all bugs via L<http://rt.cpan.org>

=head1 LICENSE

Copyright (c) 2007 Aaron Straup Cope. All Rights Reserved.

This is free software. You may redistribute it and/or
modify it under the same terms as Perl itself.

=cut

return 1;

__DATA__
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
RU5ErkJggg==
