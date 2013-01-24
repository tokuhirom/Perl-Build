use strict;
use warnings;
use utf8;
use Test::More;
use Perl::Build;

my @perls = Perl::Build->available_perls();
ok @perls;

note $_ for @perls;

done_testing;

