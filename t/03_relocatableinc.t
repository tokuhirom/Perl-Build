use strict;
use warnings;
use Test::More;

use File::Temp     qw<>;
use File::Basename qw< dirname >;
use File::Path     qw< make_path >;

use Perl::Build;

my $root = File::Temp->newdir( "Perl-Build-relocatableinc-XXXXXXXXX",
    TMPDIR => 1 );
write_files($root);

my @system_calls;
my @shebang_calls;
my @info;
no warnings qw< redefine once >;
*Perl::Build::do_system = sub { push @system_calls, $_[1] };
*Perl::Build::do_capture_stdout = sub {
    push @system_calls, $_[1];
    return "archlibexp='$root/dst/lib'\n";
};
*Perl::Build::info = sub { push @info, $_[1] };
*App::ChangeShebang::new = sub { my $c = shift; bless {@_}, $c };
*App::ChangeShebang::run = sub { push @shebang_calls, \@_ };
use warnings qw< once redefine >;

{
    local @INC;    # no chance to load it, even if installed.
    ok !Perl::Build->_change_shebang("$root/dst"),
        "_change_shebang returns falsy when App::ChangeShebang isn't installed";
    is_deeply \@info, [
        'Not changing shebang lines, App::ChangeShebang is not installed',
    ], "_change_shebang prints info when App::ChangeShebang isn't installed";
}

$INC{"App/ChangeShebang.pm"} = 1;

Perl::Build->install(
    src_path          => "$root/src",
    dst_path          => "$root/dst",
    configure_options => [ '-de', '-Duserelocatableinc' ],
);

is_deeply \@system_calls, [
    "rm -f config.sh Policy.sh",
    [   "sh", "Configure", "-Dprefix=$root/dst", "-de",
        "-Duserelocatableinc", "-A'eval:scriptdir=$root/dst/bin'"
    ],
    [ "make", "install" ],
    [ "make", "install" ],
    [ "$root/dst/bin/perl", '-V:archlibexp' ],
], "Ran system calls we expected";

is_deeply \@shebang_calls, [ [
    bless {
        file  => [ map {"$root/dst/bin/$_"} qw< perl perl99 perl99.99.99 > ],
        force => 1,
    }, 'App::ChangeShebang'
] ], "Ran App::ChangeShebang as expected";

my %expect = (
    'src/config.h' => [
        qr{^\#define \s+ STARTPERL \s+ "\#\!\Q.../perl\E"}xms,
    ],
    'dst/lib/Config.pm' => [
        qr{^\s+ scriptdir \s+ => \s+ \Qrelocate_inc('.../'),}xms,
    ],
    'dst/lib/Config_heavy.pl' => [
        qr{^initialinstalllocation='\Q$root/dst/bin\E'}xms,
        qr{^installbin='\.\.\./'}xms,
        qr{^installprefix='\.\.\./\.\.'}xms,
        qr{^installsitescript='\.\.\./'}xms,
        qr{^perlpath='\.\.\./perl'}xms,
        qr{^scriptdir='\.\.\./'}xms,
        qr{^scriptdirexp='\.\.\./'}xms,
        qr{^sitescript='\.\.\./'}xms,
        qr{^sitescriptexp='\.\.\./'}xms,
        qr{^startperl='\#\!\.\.\./perl'}xms,
        qr{^foreach \s+ my \s+ .what \s+ \(
            [^)]* installbin
            [^)]* installprefix
            [^)]* installsitescript
            [^)]* perlpath
            [^)]* scriptdir
            [^)]* sitescript
            [^)]* startperl
            [^)]*
        \)}xms,
    ],
);

foreach my $file (sort keys %expect) {
    open my $fh, '<', "$root/$file" or die "Unable to open $file: $!";
    my $content = do { local $/; readline $fh };
    close $fh;

    foreach my $re (@{ $expect{$file} }) {
        like $content, $re, "[$file] Matches $re";
    }
}

done_testing;

sub write_files {
    my ($dir) = @_;

    make_path("$root/dst/bin");
    foreach my $file (qw< perl perl99 perl99.99.99 >) {
        open my $fh, '>', "$dir/dst/bin/$file"
            or die "Unable to open $file: $!";
        print $fh '';    # like touch
        close $fh;
    }

    my $fh;
    while ( readline DATA ) {
        if (/^--- FILE: (.*)/) {
            my $file = $1;
            make_path( dirname( "$dir/$file" ) );
            open $fh, '>', "$dir/$file" or die "Unable to open $file: $!";
        }
        elsif ($fh) {
            s{/dest/p5}{$dir/dst}gxms;
            print $fh $_;
        }
    }
    close $fh;
}

__DATA__
--- FILE: src/config.h
#ifndef _config_h_
#define _config_h_


/* STARTPERL:
 *	This variable contains the string to put in front of a perl
 *	script to make sure (one hopes) that it runs with perl and not
 *	some shell.
 */
#define STARTPERL "#!/dest/p5/bin/perl"		/**/

#endif
--- FILE: dst/lib/Config.pm
# This file was created by configpm when Perl was built. Any changes
# made to this file will be lost the next time perl is built.

# for a description of the variables, please have a look at the
# Glossary file, as written in the Porting folder, or use the url:
# https://github.com/Perl/perl5/blob/blead/Porting/Glossary

package Config;
use strict;
use warnings;
our ( %Config, $VERSION );

$VERSION = "5.034000";



# tie returns the object, so the value returned to require will be true.
tie %Config, 'Config', {
    archlibexp => relocate_inc('.../../lib/5.34.0/x86_64-linux'),
    archname => 'x86_64-linux',
    cc => 'cc',
    d_readlink => 'define',
    d_symlink => 'define',
    dlext => 'so',
    dlsrc => 'dl_dlopen.xs',
    dont_use_nlink => undef,
    exe_ext => '',
    inc_version_list => ' ',
    intsize => '4',
    ldlibpthname => 'LD_LIBRARY_PATH',
    libpth => '/usr/local/lib /usr/lib /usr/lib64 /usr/local/lib64',
    osname => 'linux',
    osvers => '3.10.0-1160.25.1.el7.x86_64',
    path_sep => ':',
    privlibexp => relocate_inc('.../../lib/5.34.0'),
    scriptdir => '/dest/p5/bin',
    sitearchexp => relocate_inc('.../../lib/site_perl/5.34.0/x86_64-linux'),
    sitelibexp => relocate_inc('.../../lib/site_perl/5.34.0'),
    so => 'so',
    useithreads => undef,
    usevendorprefix => undef,
    version => '5.34.0',
};
--- FILE: dst/lib/Config_heavy.pl
package Config;
use strict;
use warnings;
our %Config;

# snpped a bunch of useless content

local *_ = \my $a;
$_ = <<'!END!';
Author=''
CONFIG='true'
Date=''
Header=''
Id=''
Locker=''
Log=''
PATCHLEVEL='34'
PERL_API_REVISION='5'
PERL_API_SUBVERSION='0'
PERL_API_VERSION='34'
PERL_CONFIG_SH='true'
PERL_PATCHLEVEL=''
PERL_REVISION='5'
PERL_SUBVERSION='0'
PERL_VERSION='34'
RCSfile=''
Revision=''
SUBVERSION='0'
Source=''
State=''
_a='.a'
_exe=''
_o='.o'
afs='false'
afsroot='/afs'
alignbytes='8'
aphostname='/bin/hostname'
api_revision='5'
api_subversion='0'
api_version='34'
api_versionstring='5.34.0'
ar='ar'
archlib='.../../lib/5.34.0/x86_64-linux'
archlibexp='.../../lib/5.34.0/x86_64-linux'
archname='x86_64-linux'
archname64=''
archobjs=''
asctime_r_proto='0'
awk='awk'
baserev='5.0'
bash=''
bin='.../'
bin_ELF='define'
binexp='.../'
bison='bison'
byacc='byacc'
byteorder='12345678'
c=''
castflags='0'
cat='cat'
cc='cc'
cccdlflags='-fPIC'
ccdlflags='-Wl,-E'
ccflags='-fwrapv -fno-strict-aliasing -pipe -fstack-protector-strong -I/usr/local/include -D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64 -D_FORTIFY_SOURCE=2'
ccflags_uselargefiles='-D_LARGEFILE_SOURCE -D_FILE_OFFSET_BITS=64'
ccname='gcc'
ccsymbols=''
ccversion=''
cf_by='afresh'
cf_email='me@example.com'
cf_time='Mon Jul 12 18:41:36 EDT 2021'
charbits='8'
charsize='1'
chgrp=''
chmod='chmod'
chown=''
clocktype='clock_t'
comm='comm'
compiler_warning='grep -i warning'
compress=''
config_arg0='Configure'
config_arg1='-Dprefix=/dest/p5'
config_arg2='-de'
config_arg3='-Duserelocatableinc'
config_arg4='-A'eval:scriptdir=/dest/p5/bin''
config_argc='4'
config_args='-Dprefix=/dest/p5 -de -Duserelocatableinc -A'eval:scriptdir=/dest/p5/bin''
contains='grep'
cp='cp'
cpio=''
cpp='cpp'
cpp_stuff='42'
cppccsymbols=''
cppflags='-fwrapv -fno-strict-aliasing -pipe -fstack-protector-strong -I/usr/local/include'
cpplast='-'
cppminus='-'
cpprun='cc  -E'
cppstdin='cc  -E'
ignore_versioned_solibs='y'
inc_version_list=' '
inc_version_list_init='0'
incpath=''
incpth='/usr/lib/gcc/x86_64-redhat-linux/4.8.2/include /usr/local/include /usr/include'
inews=''
initialinstalllocation='/dest/p5/bin'
installarchlib='.../../lib/5.34.0/x86_64-linux'
installbin='/dest/p5/bin'
installhtml1dir=''
installhtml3dir=''
installman1dir='.../../man/man1'
installman3dir='.../../man/man3'
installprefix='/dest/p5'
installprefixexp='.../..'
installprivlib='.../../lib/5.34.0'
installscript='/dest/p5/bin'
installsitearch='.../../lib/site_perl/5.34.0/x86_64-linux'
installsitebin='.../../bin'
installsitehtml1dir=''
installsitehtml3dir=''
installsitelib='.../../lib/site_perl/5.34.0'
installsiteman1dir='.../../man/man1'
installsiteman3dir='.../../man/man3'
installsitescript='.../../bin'
installstyle='lib'
installusrbinperl='undef'
installvendorarch=''
installvendorbin=''
installvendorhtml1dir=''
installvendorhtml3dir=''
installvendorlib=''
installvendorman1dir=''
installvendorman3dir=''
installvendorscript=''
man1dir='.../../man/man1'
man1direxp='.../../man/man1'
man1ext='1'
man3dir='.../../man/man3'
man3direxp='.../../man/man3'
man3ext='3'
mips_type=''
mistrustnm=''
perllibs='-lpthread -lnsl -ldl -lm -lcrypt -lutil -lc'
perlpath='/dest/p5/bin/perl'
pg='pg'
phostname='hostname'
pidtype='pid_t'
prefix='.../..'
prefixexp='.../..'
privlib='.../../lib/5.34.0'
privlibexp='.../../lib/5.34.0'
scriptdir='/dest/p5/bin'
scriptdirexp='/dest/p5/bin'
shar=''
sharpbang='#!'
shmattype='void *'
shortsize='2'
shrpenv=''
shsharp='true'
sig_count='65'
signal_t='void'
sitearch='.../../lib/site_perl/5.34.0/x86_64-linux'
sitearchexp='.../../lib/site_perl/5.34.0/x86_64-linux'
sitebin='.../../bin'
sitebinexp='.../../bin'
sitehtml1dir=''
sitehtml1direxp=''
sitehtml3dir=''
sitehtml3direxp=''
sitelib='.../../lib/site_perl/5.34.0'
sitelib_stem='.../../lib/site_perl'
sitelibexp='.../../lib/site_perl/5.34.0'
siteman1dir='.../../man/man1'
siteman1direxp='.../../man/man1'
siteman3dir='.../../man/man3'
siteman3direxp='.../../man/man3'
siteprefix='.../..'
siteprefixexp='.../..'
sitescript='.../../bin'
sitescriptexp='.../../bin'
sizesize='8'
sizetype='size_t'
st_ino_size='8'
startperl='#!/dest/p5/bin/perl'
startsh='#!/bin/sh'
static_ext=' '
subversion='0'
sysman='/usr/share/man/man1'
sysroot=''
tail=''
tar=''
targetarch=''
targetdir=''
targetenv=''
targethost=''
targetmkdir=''
targetport=''
targetsh='/bin/sh'
tbl=''
tee=''
test='test'
timeincl='/usr/include/sys/time.h '
timetype='time_t'
tmpnam_r_proto='0'
to=':'
touch='touch'
tr='tr'
trnl='\n'
troff=''
vendorscriptexp=''
version='5.34.0'
version_patchlevel_string='version 34 subversion 0'
versiononly='undef'
!END!

my $i = ord(8);
foreach my $c (7,6,5,4,3,2,1) { $i <<= 8; $i |= ord($c); }
our $byteorder = join('', unpack('aaaaaaaa', pack('L!', $i)));
foreach my $what (qw(prefixexp archlibexp man1direxp man3direxp privlibexp sitearchexp sitebinexp sitelibexp siteman1direxp siteman3direxp sitescriptexp siteprefixexp sitelib_stem installarchlib installman1dir installman3dir installprefixexp installprivlib installsitearch installsitebin installsitelib installsiteman1dir installsiteman3dir installsitescript)) {
    s/^($what=)(['"])(.*?)\2/$1 . $2 . relocate_inc($3) . $2/me;
}
s/(byteorder=)(['"]).*?\2/$1$2$Config::byteorder$2/m;

1;
--- FILE: src/patchlevel.h
/*    patchlevel.h
 *
 *    The very minumum needed to make Devel::PatchPerl happy
 */

#define PERL_REVISION	99		/* age */
#define PERL_VERSION	99		/* epoch */
#define PERL_SUBVERSION	99		/* generation */

