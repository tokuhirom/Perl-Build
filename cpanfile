requires 'perl' => '5.008002';
requires 'CPAN::Perl::Releases' => '0';
requires 'File::pushd' => '0';
requires 'HTTP::Tiny' => '0';
requires 'Devel::PatchPerl' => '0.84';
requires 'File::Temp';
requires 'Getopt::Long';
requires 'Pod::Usage';

on test => sub {
    requires 'Test::More' => '0.98';
};

