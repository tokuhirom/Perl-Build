requires 'perl' => '5.008005';
requires 'CPAN::Perl::Releases' => '0';
requires 'File::pushd' => '0';
requires 'HTTP::Tiny' => '0';
requires 'Devel::PatchPerl' => '0.84';
on configure => sub {
    requires 'Module::Build' => '0.38';
};

on build => sub {
    requires 'Test::Requires' => '0';
    requires 'Test::More' => '0.98';
};

on develop => sub {
};

