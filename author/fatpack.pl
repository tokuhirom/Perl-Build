#!/bin/sh
SRC=script/perl-build
DST=perl-build
export PERL5LIB=`dirname $0`/../lib/

fatpack trace $SRC
fatpack packlists-for `cat fatpacker.trace` >packlists
fatpack tree `cat packlists`

if type perlstrip >/dev/null 2>&1; then
    find fatlib -type f -name '*.pm' | xargs -n1 perlstrip -s
fi

(echo "#!/usr/bin/env perl"; fatpack file; cat $SRC) > $DST
chmod +x $DST

