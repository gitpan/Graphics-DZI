use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Graphics::DZI',
    license             => 'perl',
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

