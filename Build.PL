use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name       => 'Array::AsHash',
    license           => 'perl',
    dist_author       => 'Curtis <ovid@cpan.org>',
    dist_version_from => 'lib/Array/AsHash.pm',
    requires          => {
        'Class::Std'   => 0,
        'Clone'        => 0.18,
        'Scalar::Util' => 1.14,
        'Test::More'   => 0,
    },
    add_to_cleanup     => ['Array-AsHash-*'],
    create_makefile_pl => 'traditional',
);

$builder->create_build_script();
