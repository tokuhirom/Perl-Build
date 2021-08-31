requires 'perl' => '5.008001';
requires 'CPAN::Perl::Releases' => '3.58';
requires 'CPAN::Perl::Releases::MetaCPAN' => '0.006';
requires 'File::pushd' => '0';
requires 'HTTP::Tinyish' => '0.17';
requires 'JSON::PP' => '0';
requires 'Devel::PatchPerl' => '0.88';
requires 'File::Temp';
requires 'Getopt::Long';
requires 'Pod::Usage', '1.63';

feature 'userelocatableinc', 'userelocatableinc support' => sub {
  recommends 'App::ChangeShebang';
};

on test => sub {
    requires 'Test::More' => '0.98';
};
