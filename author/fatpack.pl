#!/bin/sh
SRC=script/perl-build
DST=perl-build
export PERL5LIB=`dirname $0`/../lib/

fatpack trace $SRC
fatpack packlists-for `cat fatpacker.trace` >packlists
fatpack tree `cat packlists`
(echo "#!/usr/bin/env perl"; fatpack file; cat $SRC) > $DST
chmod +x $DST

