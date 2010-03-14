package Graphics::DZI::Files;

use warnings;
use strict;

use Moose;
extends 'Graphics::DZI';

our $log;
use Log::Log4perl;
BEGIN {
    $log = Log::Log4perl->get_logger ();
}

=head1 NAME

Graphics::DZI::Files - DeepZoom Image Pyramid Generation, File-based

=head1 SYNOPSIS

  use Graphics::DZI::Files;
  my $dzi = new Graphics::DZI::Files (image    => $image,
				      overlap  => 4,
				      tilesize => 256,
				      scale    => 2,
 				      format   => 'png',
                                      prefix   => 'xxx',
                                      path     => '/where/ever/');
  use File::Slurp;
  write_file ('/where/ever/xxx.xml', $dzi->descriptor);
  $dzi->iterate ();

=head1 DESCRIPTION

This subclass of L<Graphics::DZI> generates tiles and stores them at the specified path location.

=head1 INTERFACE

=head2 Constructor

Additional to the parent class L<Graphics::DZI>, the constructor takes the following fields:

=over

=item C<format> (default C<png>):

An image format (C<png>, C<jpg>, ...). Any format L<Image::Magick> understands will do.

=item C<path>:

A directory name (including trailing C</>) where the tiles are written to.

=item C<prefix>:

The string to be prefixed the C<_files/> part in the directory name. Usually the name of the image
to be converted. No slashes.

=back

=cut

#has 'format'   => (isa => 'Str'   ,        is => 'ro', default => 'png');
has 'path'    => (isa => 'Str'   ,        is => 'ro');
has 'prefix'  => (isa => 'Str'   ,        is => 'ro');

=head2 Methods

=over

=item B<manifest>

This method writes any tile to a file, appropriately named for DZI inclusion.

=cut

sub manifest {
    my $self  = shift;
    my $tile  = shift;
    my $level = shift;
    my $row   = shift;
    my $col   = shift;

    my $path = $self->path . "$level/";
    use File::Path qw(make_path);
    make_path ($path);

    my $filen = $path . (sprintf "%s_%s", $col, $row ) . '.' . $self->format;
    $log->debug ("saving tile $level $row $col --> $filen");
    $tile->Write( $filen );
}

=back

=head1 AUTHOR

Robert Barta, C<< <drrho at cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2010 Robert Barta, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

our $VERSION = '0.02';
"against all odds";
