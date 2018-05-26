requires 'perl' => '5.008002';
requires 'CPAN::Perl::Releases' => '0';
requires 'CPAN::Perl::Releases::MetaCPAN' => '0';
requires 'File::pushd' => '0';
requires 'HTTP::Tinyish' => '0';
requires 'JSON::PP' => '0';
requires 'Devel::PatchPerl' => '0.88';
requires 'File::Temp';
requires 'Getopt::Long';
requires 'Pod::Usage', '1.63';

on test => sub {
    requires 'Test::More' => '0.98';
};

