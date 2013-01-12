use strict;
use warnings;
use Module::Build;

my $build = Module::Build->new(
    license              => 'perl',
    dynamic_config       => 0,

    build_requires       => {
        'Test::More' => '0.98',
        'Test::Requires' => 0,
    },
    configure_requires   => { 'Module::Build' => '0.38' },
    requires             => {
        perl                   => '5.008005',
        'File::pushd'          => 0,
        'CPAN::Perl::Releases' => 0,
        'Devel::PatchPerl'     => 0,
    },

    no_index    => { 'directory' => [ 'inc' ] },
    name        => 'Perl-Build',
    module_name => 'Perl::Build',

    script_files => ['bin/perl-build'],

    test_files => (-d '.git' || $ENV{RELEASE_TESTING}) ? 't/ xt/' : 't/',
    recursive_test_files => 1,
   
    create_readme  => 1,
    create_license => 1,
);
$build->create_build_script();
