use strict;
use Test::More;
use Perl::Build;
use CPAN::Perl::Releases;

my %test = (
    '5.18.2' => q!R/RJ/RJBS/perl-5.18.2.tar.!,
    '5.18.0-RC4' => q!R/RJ/RJBS/perl-5.18.0-RC4.tar.!,
    '5.16.1' => q!R/RJ/RJBS/perl-5.16.1.tar.!,
    '5.12.5' => q!D/DO/DOM/perl-5.12.5.tar.!,
    '5.8.5'  => q!N/NW/NWCLARK/perl-5.8.5.tar.!,
);

subtest 'CPAN::Perl::Releases' => sub {
    local $Perl::Build::CPAN_MIRROR = '';
    for my $ver (keys %test ) {
        my ($tarball,$url) = Perl::Build->perl_release($ver);
        like ($url, qr!^/authors/id/\Q$test{$ver}\E!);
    }
};

subtest 'perl-releases-page' => sub {
    plan skip_all => 'author test only' unless $ENV{AUTHOR_TESTING};
    local $Perl::Build::CPAN_MIRROR = '';
    no warnings 'redefine';
    *{CPAN::Perl::Releases::perl_tarballs} = sub {};
    for my $ver (keys %test ) {
        my ($tarball,$url) = Perl::Build->perl_release($ver);
        like ($url, qr!^/authors/id/\Q$test{$ver}\E!);
    }
};

subtest 'search.cpan.org' => sub {
    plan skip_all => 'author test only' unless $ENV{AUTHOR_TESTING};
    my $tiny = HTTP::Tiny->new(timeout=>5);
    my $res = $tiny->get("http://search.cpan.org/");
    plan skip_all => 'search.cpan.org seems to be down' unless $res->{success};
    local $Perl::Build::CPAN_MIRROR = '';
    no warnings 'redefine';
    *{CPAN::Perl::Releases::perl_tarballs} = sub {};
    my $orig = HTTP::Tiny->can('get');
    *{HTTP::Tiny::get} = sub {
        return {success=>0,status=>599,reason=>"test error"} if $_[1] =~ m!perl-releases\.!;
        $orig->(@_);
    };
    for my $ver (keys %test ) {
        my ($tarball,$url) = Perl::Build->perl_release($ver);
        like ($url, qr!^/authors/id/\Q$test{$ver}\E!);
    }
};


done_testing;
