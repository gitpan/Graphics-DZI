package Graphics::DZI;

use warnings;
use strict;

use Moose;

our $log;
use Log::Log4perl;
BEGIN {
    $log = Log::Log4perl->get_logger ();
}

=head1 NAME

Graphics::DZI - DeepZoom Image Pyramid Generation

=head1 SYNOPSIS

  use Graphics::DZI;
  my $dzi = Graphics::DZI::A4 (image    => $image,
                               overlap  => $overlap,
                               tilesize => $tilesize,
                               format   => $format,
                               );

  write_file ('/var/www/xxx.xml', $dzi->descriptor);
  $dzi->iterate ();
  # !!! this does only display the tiles on the screen
  # !!! see Graphics::DZI::Files for a subclass which 
  # !!! actually writes to files

=head1 DESCRIPTION

This base package generates tiles from a given image in such a way that they follow the DeepZoom
image pyramid scheme. Consequently this image becomes zoomable with tools like Seadragon.

  http://en.wikipedia.org/wiki/Deep_Zoom

As this is a base class, you may want to look either at the I<deepzoom> script which operators on
the command line, or at one of the subclasses.

=head1 INTERFACE

=head2 Constructor

The constructor accepts the following fields:

=over

=item C<image>

The L<Image::Magick> object which is used as canvas.

=item C<scale> (integer, default: 1)

Specifies how much the image is stretched in the process.

=item C<overlap> (integer, default: 4)

Specifies how much the individual tiles overlap.

=item C<tilesize> (integer, default: 128)

Specifies the quadratic size of each tile.

=back

=cut

has 'image'    => (isa => 'Image::Magick', is => 'rw', required => 1);
has 'scale'    => (isa => 'Int',           is => 'ro', default => 1);
has 'overlap'  => (isa => 'Int',           is => 'ro', default => 4);
has 'tilesize' => (isa => 'Int',           is => 'ro', default => 128);
has 'format'   => (isa => 'Str'   ,        is => 'ro', default => 'png');

=head2 Methods

=over

=item B<crop>

I<$tile> = I<$dzi>->crop (I<$scale>, I<$x>, I<$y>, I<$dx>, I<$dy>)

Given the dimensions of a tile and a current (not the original)
stretch factor this method will return a tile object.

=cut

sub crop {
    my $self = shift;
    my $scale = shift;
    my ($tx, $ty, $tdx, $tdy) = @_;

    my $image = $self->{image};
    my $tile  = $image->Clone;
    if ($scale != 1) {                                                                       # if our image is not quite the total space
	my ($htx, $hty, $htdx, $htdy) = map { int ($_ / $scale) }
	                                ($tx, $ty, $tdx, $tdy);                              # rescale this tile to the image dims we have
	$log->debug ("rescale $tx, $ty  -->  $htx, $hty");
	$tile->Crop (geometry => "${htdx}x${htdy}+${htx}+${hty}");                           # cut that smaller one out
	$tile->Resize ("${tdx}x${tdy}");                                                     # and make it bigger
    } else {                                                                                 # otherwise we are happy with what we have, dimension-wise
	$tile->Crop (geometry => "${tdx}x${tdy}+${tx}+${ty}");                               # cut one out
    }
    $log->debug ("tiled ${tdx}x${tdy}+${tx}+${ty}");

    foreach my $o (@{ $self->{overlays} }) {                                                 # if we have overlay images
	my ($w, $h) = $o->{image}->GetAttributes ('width', 'height');
	$o->{dx} = $w;
	$o->{dy} = $h;

	if (my $r = _intersection ($tx,     $ty,     $tx+$tdx,           $ty+$tdy,                   # tile and overlay intersect?
				   $o->{x}, $o->{y}, $o->{x} + $o->{dx}, $o->{y} +$o->{dy})) {
#	    warn " intersection!";
	    my ($ox, $oy, $dx, $dy) = (
		$r->[0] - $o->{x},           # x relative to overlay
		$r->[1] - $o->{y},           # y relative to overlay

		$r->[2] - $r->[0],           # width of the intersection
		$r->[3] - $r->[1],           # height
		);

	    my $oc = $o->{image}->clone;
#	    $oc->Display();

	    $oc->Crop (geometry => "${dx}x${dy}+${ox}+${oy}");
#	    warn "cropped oc";
#	    $oc->Display();

	    $tile->Composite (image => $oc,
			      x     => $r->[0] - $tx,    # intersection left/top relative to tile
			      'y'   => $r->[1] - $ty,
			      compose => 'Over',
#			      compose => 'Overlay',
#                             opacity => 50,
		);
#	    $tile->Display();
	}
    }

    return $tile;
}

sub _intersection {
    my ($ax, $ay, $axx, $ayy,
	$bx, $by, $bxx, $byy) = @_;

    if (_intersects ($ax, $ay, $axx, $ayy,
		     $bx, $by, $bxx, $byy)) {
	return [
	    $ax  > $bx  ? $ax  : $bx,
	    $ay  > $by  ? $ay  : $by,
	    $axx > $bxx ? $bxx : $axx,
	    $ayy > $byy ? $byy : $ayy
	    ];
    }
}

sub _intersects {
    my ($ax, $ay, $axx, $ayy,
	$bx, $by, $bxx, $byy) = @_;

    return undef
	if $axx < $bx
	|| $bxx < $ax
	|| $ayy < $by
	|| $byy < $ay;
    return 1;
}

=item B<iterate>

I<$dzi>->iterate

This method will generate all necessary tiles, invoking the I<manifest> method. You may want to
override that one, if you do not want the tiles to be simply displayed on screen :-) Any options
you add as parameters will be passed on to I<manifest>.

=cut

sub iterate {
    my $self = shift;
    my %options = @_;

    my $overlap_tilesize = $self->{tilesize} + 2 * $self->{overlap};
    my $border_tilesize  = $self->{tilesize} +     $self->{overlap};

    my $image = $self->{image};                                      # DANGER: here we use our original - more efficient, though
    my ($WIDTH, $HEIGHT) = map { $_ * $self->{scale} } $image->GetAttributes ('width', 'height');
    $log->debug ("total dimensions: $WIDTH, $HEIGHT");
    use POSIX;
    my $MAXLEVEL = POSIX::ceil (log ($WIDTH > $HEIGHT ? $WIDTH : $HEIGHT) / log (2));
    $log->debug ("   --> levels: $MAXLEVEL");

    my ($width, $height) = ($WIDTH, $HEIGHT);
    my $scale = $self->{scale};
    foreach my $level (reverse (0..$MAXLEVEL)) {

	my ($x, $col) = (0, 0);
	while ($x < $width) {
	    my ($y, $row) = (0, 0);
	    my $tile_dx = $x == 0 ? $border_tilesize : $overlap_tilesize;
	    while ($y < $height) {

		my $tile_dy = $y == 0 ? $border_tilesize : $overlap_tilesize;

		my $tile = $self->crop ($scale, $x, $y, $tile_dx, $tile_dy);
		$self->manifest ($tile, $level, $row, $col, %options);

		$y += ($tile_dy - 2 * $self->{overlap});
		$row++;
	    }
	    $x += ($tile_dx - 2 * $self->{overlap});
	    $col++;
	}
	($width, $height) = map { int ($_ / 2) } ($width, $height);
	$scale /= 2;
	
#	$image->Resize (width => int($width/2), height => int($height/2));         # resize the canvas for next iteration
	foreach my $o (@{ $self->{overlays} }) {                                   # also resize all overlays
	    my ($w, $h) = $o->{image}->GetAttributes ('width', 'height');          # current dimensions
	    $o->{image}->Resize (width => int($w/2), height => int($h/2));         # half size
	    $o->{x} /= 2;                                                          # dont forget x, y 
	    $o->{y} /= 2;
	}
    }
}

=item B<manifest>

I<$dzi>->manifest (I<$tile>, I<$level>, I<$row>, I<$col>)

This method will get one tile as parameter and will simply display the tile on the screen.
Subclasses which want to persist the tiles, can use the additional parameters (level, row and
column) to create file names.

=cut

sub manifest {
    my $self = shift;
    my $tile = shift;
    $tile->Display();
}

=item B<descriptor>

I<$string> = I<$dzi>->descriptor

This method returns the DZI XML descriptor as string.

=cut

sub descriptor {
    my $self = shift;
    my $overlap  = $self->{overlap};
    my $tilesize = $self->{tilesize};
    my $format   = $self->{format};
    my ($width, $height) = map { $_ * $self->{scale} }  $self->{image}->GetAttributes ('width', 'height');
    return qq{<?xml version='1.0' encoding='UTF-8'?>
<Image TileSize='$tilesize'
       Overlap='$overlap'
       Format='$format'
       xmlns='http://schemas.microsoft.com/deepzoom/2008'>
    <Size Width='$width' Height='$height'/>
</Image>
};


}

=back

=head1 AUTHOR

Robert Barta, C<< <drrho at cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Robert Barta, all rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl
itself.

=cut

our $VERSION = '0.02';

"against all odds";
