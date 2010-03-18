use strict;
use warnings;
use Module::Build;

my $version = '0.03';

use Module::Build;
my $class = Module::Build->subclass(
    class => "Module::Build::Custom",
    code => <<'SUBCLASS' );

sub ACTION_upload {
    my $self = shift;
    
    $self->do_system(qw(cpan-upload Graphics-DZI-$version.tar.gz));
}
SUBCLASS

my $builder = Module::Build::Custom->new(
    module_name         => 'Graphics::DZI',
    license             => 'perl',
    version             => $version,
    dist_author         => 'Robert Barta <drrho@cpan.org>',
    dist_version_from   => 'lib/Graphics/DZI.pm',
    build_requires => {
	'Moose'               => undef,
	'Image::Magick'       => undef,
	'File::Path'          => undef,
	'File::Slurp'         => undef,
	'File::Basename'      => undef,
	'Getopt::Long'        => undef,
	'Pod::Usage'          => undef,
	'Log::Log4perl'       => undef,
	'Image::Magick'       => undef,
	'List::MoreUtils'     => undef,
        'Test::More'          => undef,
	'Test::Exception'     => undef,
	'Test::Pod::Coverage' => undef,
    },
    add_to_cleanup      => [ 'Graphics-DZI-*' ],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();

