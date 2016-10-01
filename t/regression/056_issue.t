use strict;
use warnings;

BEGIN {
    use Test::More;

    *CORE::GLOBAL::glob = sub {
        return ("/home/axafbin/.plenv/versions/5.22.2/bin/perl5.22.2");
    };

    *CORE::GLOBAL::system = sub {
        is $_[0], "ln -fs /home/axafbin/.plenv/versions/5.22.2/bin/perl5.22.2 /home/axafbin/.plenv/versions/5.22.2/bin/perl";
    };
}

use Perl::Build;

Perl::Build->symlink_devel_executables("/home/axafbin/.plenv/versions/5.22.2/bin");
done_testing;
