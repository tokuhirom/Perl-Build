#!/bin/sh
SRC=script/perl-build
DST=perl-build
fatpack trace $SRC
fatpack packlists-for `cat fatpacker.trace` >packlists
fatpack tree `cat packlists`
(echo "#!/usr/bin/env perl"; fatpack file; cat $SRC) > $DST
chmod +x $DST

