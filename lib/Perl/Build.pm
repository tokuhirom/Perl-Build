package Perl::Build;
use strict;
use warnings;
use utf8;

use 5.008002;
our $VERSION = '1.10';

use Carp ();
use File::Basename;
use File::Spec::Functions qw(catfile catdir rel2abs);
use CPAN::Perl::Releases;
use File::pushd qw(pushd);
use File::Temp;
use HTTP::Tiny;
use Devel::PatchPerl 0.88;
use Perl::Build::Built;
use Time::Local;

our $CPAN_MIRROR = $ENV{PERL_BUILD_CPAN_MIRROR} || 'http://www.cpan.org';

sub available_perls {
    my ( $class, $dist ) = @_;

    my $url = "http://www.cpan.org/src/5.0/";
    my $html = http_get( $url );

    unless($html) {
        die "\nERROR: Unable to retrieve the list of perls.\n\n";
    }

    my @available_versions;

    my %uniq;
    for ( split "\n", $html ) {
        if (my ($version) = m|<a href="perl-(.+)\.tar\.gz">(.+?)</a>|) {
            next if $uniq{$version}++;
            push @available_versions, $version;
        }
    }

    return @available_versions;
}

# @return extracted source directory
sub extract_tarball {
    my ($class, $dist_tarball, $destdir) = @_;

    # Was broken on Solaris, where GNU tar is probably
    # installed as 'gtar' - RT #61042
    my $tarx =
        ($^O eq 'solaris' ? 'gtar ' : 'tar ') .
        ( $dist_tarball =~ m/bz2$/ ? 'xjf' : 'xzf' );
    my $extract_command = "cd @{[ $destdir ]}; $tarx @{[ File::Spec->rel2abs($dist_tarball) ]}";
    system($extract_command) == 0
        or die "Failed to extract $dist_tarball";
    $dist_tarball =~ s{(?:.*/)?([^/]+)\.tar\.(?:gz|bz2)$}{$1};
    if ($dist_tarball eq 'blead') {
        opendir my $dh, $destdir or die "Can't open $destdir: $!";
        my $latest = [];
        while(my $dir = readdir $dh) {
            next unless -d catfile($destdir, $dir) && $dir =~ /perl-[0-9a-f]{7,8}$/;
            my $mtime = (stat(_))[9];
            $latest = [$dir, $mtime] if !$latest->[1] or $latest->[1] < $mtime;
        }
        closedir $dh;
        return catfile($destdir, $latest->[0]);
    } else {
        return "$destdir/$dist_tarball"; # Note that this is incorrect for blead
    }
}

sub perl_release {
    my ($class, $version) = @_;

    my ($dist_tarball, $dist_tarball_url);
    for my $func (qw/cpan_perl_releases perl_releases_page search_cpan_org/) {
        eval {
            ($dist_tarball, $dist_tarball_url) = $class->can("perl_release_by_$func")->($class,$version);
        };
        warn "WARN: [$func] $@" if $@;
        last if $dist_tarball && $dist_tarball_url;
    }
    die "ERROR: Cannot find the tarball for perl-$version\n"
        if !$dist_tarball and !$dist_tarball_url;
           
    return ($dist_tarball, $dist_tarball_url);
}

sub perl_release_by_cpan_perl_releases {
    my ($class, $version) = @_;
    my $tarballs = CPAN::Perl::Releases::perl_tarballs($version);

    my $x = (values %$tarballs)[0];
    die "not found the tarball for perl-$version\n" unless $x;
    my $dist_tarball = (split("/", $x))[-1];
    my $dist_tarball_url = $CPAN_MIRROR . "/authors/id/$x";
    return ($dist_tarball, $dist_tarball_url);
}

sub perl_release_by_perl_releases_page {
    my ($class, $version) = @_;

    my $url = "http://perl-releases.s3-website-us-east-1.amazonaws.com/";
    my $http = HTTP::Tiny->new();
    my $response = $http->get($url);
    if (!$response->{success}) {
        die "Cannot get content from $url: $response->{status} $response->{reason}\n";
    }

    if ( ! exists $response->{headers}{'last-modified'} ) {
        die "There is not Last-Modified header. ignore this response\n";
    }

    my $last_modified;
    # Copy from HTTP::Tiny::_parse_date_time
    my $MoY = "Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec";
    if ( $response->{headers}{'last-modified'} =~ 
             /^[SMTWF][a-z]+, +(\d{1,2}) ($MoY) +(\d\d\d\d) +(\d\d):(\d\d):(\d\d) +GMT$/) {
        my @tl_parts = ($6, $5, $4, $1, (index($MoY,$2)/4), $3);
        $last_modified = eval {
            my $t = @tl_parts ? Time::Local::timegm(@tl_parts) : -1;
            $t < 0 ? undef : $t;
        };
    }
    if ( ! defined $last_modified || time - $last_modified > 3*86400 ) { #parse error or 3days old
        die "This page is 3 or more days old. ignore\n";
    }

    my ($dist_path, $dist_tarball) =
        $response->{content} =~ m[^\Q${version}\E\t(.+?/(perl-${version}.tar.(gz|bz2)))]m;
    die "not found the tarball for perl-$version\n"
        if !$dist_path and !$dist_tarball;
    my $dist_tarball_url = "$CPAN_MIRROR/authors/id/${dist_path}";
    return ($dist_tarball, $dist_tarball_url);

}

sub perl_release_by_search_cpan_org {
    my ($class, $version) = @_;

    my $html = http_get("http://search.cpan.org/dist/perl-${version}");

    unless ($html) {
        die "Failed to download perl-${version} tarball\n";
    }

    my ($dist_path, $dist_tarball) =
        $html =~ m[<a href="/CPAN/(authors/id/.+/(perl-${version}.tar.(gz|bz2)))">Download</a>];
    die "not found the tarball for perl-$version\n"
        if !$dist_path and !$dist_tarball;
    my $dist_tarball_url = "$CPAN_MIRROR/${dist_path}";
    return ($dist_tarball, $dist_tarball_url);

}


sub http_get {
    my ($url) = @_;

    my $http = HTTP::Tiny->new();
    my $response = $http->get($url);
    if ($response->{success}) {
        return $response->{content};
    } else {
        die "Cannot get content from $url: $response->{status} $response->{reason}\n";
    }
}

sub http_mirror {
    my ($url, $path) = @_;

    my $http = HTTP::Tiny->new();
    my $response = $http->mirror($url, $path);
    if ($response->{success}) {
        print "Downloaded $url to $path.\n";
    } else {
        die "Cannot get file from $url: $response->{status} $response->{reason}";
    }
}

sub install_from_cpan {
    my ($class, $version, %args) = @_;

    $args{patchperl} && Carp::croak "The patchperl argument was deprected.";

    my $tarball_dir = $args{tarball_dir}
        || File::Temp::tempdir( CLEANUP => 1 );
    my $build_dir = $args{build_dir}
        || File::Temp::tempdir( CLEANUP => 1 );
    my $dst_path = $args{dst_path}
        or die "Missing mandatory parameter: dst_path";
    my $configure_options = $args{configure_options}
        || ['-de'];

    # download tar ball
    my ($dist_tarball, $dist_tarball_url) = Perl::Build->perl_release($version);
    my $dist_tarball_path = catfile($tarball_dir, $dist_tarball);
    if (-f $dist_tarball_path) {
        print "Use the previously fetched ${dist_tarball}\n";
    }
    else {
        print "Fetching $version as $dist_tarball_path ($dist_tarball_url)\n";
        http_mirror( $dist_tarball_url, $dist_tarball_path );
    }

    # and extract tar ball.
    my $dist_extracted_path = Perl::Build->extract_tarball($dist_tarball_path, $build_dir);
    Perl::Build->install(
        src_path          => $dist_extracted_path,
        dst_path          => $dst_path,
        configure_options => $configure_options,
        test              => $args{test},
        jobs              => $args{jobs},
    );
}

sub install_from_url {
    my ($class, $dist_tarball_url, %args) = @_;
    $args{patchperl} && Carp::croak "The patchperl argument was deprected.";

    my $build_dir = $args{build_dir}
        || File::Temp::tempdir( CLEANUP => 1 );
    my $tarball_dir = $args{tarball_dir}
        || File::Temp::tempdir( CLEANUP => 1 );
    my $dst_path = $args{dst_path}
        or die "Missing mandatory parameter: dst_path";
    my $configure_options = $args{configure_options}
        || ['-de'];

    my $dist_tarball = basename($dist_tarball_url);
    my $dist_tarball_path = catfile($tarball_dir, $dist_tarball);
    if (-f $dist_tarball_path) {
        print "Use the previously fetched ${dist_tarball}\n";
    }
    else {
        print "Fetching $dist_tarball_path ($dist_tarball_url)\n";
        http_mirror( $dist_tarball_url, $dist_tarball_path );
    }

    my $dist_extracted_path = Perl::Build->extract_tarball($dist_tarball_path, $build_dir);
    Perl::Build->install(
        src_path          => $dist_extracted_path,
        dst_path          => $dst_path,
        configure_options => $configure_options,
        test              => $args{test},
        jobs              => $args{jobs},
    );
}

sub install_from_tarball {
    my ($class, $dist_tarball_path, %args) = @_;
    $args{patchperl} && Carp::croak "The patchperl argument was deprected.";

    my $build_dir = $args{build_dir}
        || File::Temp::tempdir( CLEANUP => 1 );
    my $dst_path = $args{dst_path}
        or die "Missing mandatory parameter: dst_path";
    my $configure_options = $args{configure_options}
        || ['-de'];

    my $dist_extracted_path = Perl::Build->extract_tarball($dist_tarball_path, $build_dir);
    Perl::Build->install(
        src_path          => $dist_extracted_path,
        dst_path          => $dst_path,
        configure_options => $configure_options,
        test              => $args{test},
        jobs              => $args{jobs},
    );
}

sub install {
    my ($class, %args) = @_;
    $args{patchperl} && Carp::croak "The patchperl argument was deprected.";

    my $src_path = $args{src_path}
        or die "Missing mandatory parameter: src_path";
    my $dst_path = $args{dst_path}
        or die "Missing mandatory parameter: dst_path";
    my $configure_options = $args{configure_options}
        or die "Missing mandatory parameter: configure_options";
    my $jobs = $args{jobs}; # optional
    my $test = $args{test}; # optional

    unshift @$configure_options, qq(-Dprefix=$dst_path);

    # Perl5 installs public executable scripts(like `prove`) to /usr/local/share/
    # if it exists.
    #
    # This -A'eval:scriptdir=$prefix/bin' option avoid this feature.
    unless (grep { /eval:scriptdir=/} @$configure_options) {
        push @$configure_options, "-A'eval:scriptdir=${dst_path}/bin'";
    }

    # clean up environment
    delete $ENV{$_} for qw(PERL5LIB PERL5OPT);

    {
        my $dir = pushd($src_path);

        # determine_version is a public API.
        my $dist_version = Devel::PatchPerl->determine_version();
        print "Configuring perl '$dist_version'\n";

        # clean up
        $class->do_system("rm -f config.sh Policy.sh");

        # apply patches
        Devel::PatchPerl->patch_source();

        # configure
        $class->do_system(['sh', 'Configure', @$configure_options]);
        # patch for older perls
        # XXX is this needed? patchperl do this?
        # if (Perl::Build->perl_version_to_integer($dist_version) < Perl::Build->perl_version_to_integer( '5.8.9' )) {
        #     $class->do_system("$^X -i -nle 'print unless /command-line/' makefile x2p/makefile");
        # }

        # build
        my @make = qw(make);
        if ($ENV{PERL_BUILD_COMPILE_OPTIONS}) {
            push @make, $ENV{PERL_BUILD_COMPILE_OPTIONS};
        }
        if ($jobs) {
            push @make, '-j', $jobs;
        }
        $class->do_system(\@make);
        if ($test) {
            local $ENV{TEST_JOBS} = $jobs;
            # Test via "make test_harness" if available so we'll get
            # automatic parallel testing via $HARNESS_OPTIONS. The
            # "test_harness" target was added in 5.7.3, which was the last
            # development release before 5.8.0.
            my $test_target = 'test';
            if ($dist_version && $dist_version =~ /^5\.([0-9]+)\.([0-9]+)/
                && ($1 >= 8 || $1 == 7 && $2 == 3)) {
                $test_target = "test_harness";
            }
            $class->do_system([@make, $test_target]);
        }
        $class->do_system('make install');
    }
    return Perl::Build::Built->new({
        installed_path => $dst_path,
    });
}

sub do_system {
    my ($class, $cmd) = @_;

    if (ref $cmd eq 'ARRAY') {
        $class->info(join(' ', @$cmd));
        system(@$cmd) == 0
            or die "Installation failure: @$cmd";
    } else {
        $class->info($cmd);
        system($cmd) == 0
            or die "Installation failure: $cmd";
    }
}

sub symlink_devel_executables {
    my ($class, $bin_dir) = @_;

    for my $executable (glob("$bin_dir/*")) {
        my ($name, $version) = $executable =~ m/bin\/(.+?)(5\.\d.*)?$/;
        if ($version) {
            my $cmd = "ln -fs $executable $bin_dir/$name";
            $class->info($cmd);
            system($cmd);
        }
    }
}

sub info {
    my ($class, @msg) = @_;
    print @msg, "\n";
}

1;
__END__

=encoding utf8

=for stopwords tarball Optional symlinks patchperl

=head1 NAME

Perl::Build - perl builder

=head1 SYNOPSIS

=head1 Install as plenv plugin (Recommended)

    % git clone git://github.com/tokuhirom/Perl-Build.git ~/.plenv/plugins/perl-build/

=head1 CLI interface without dependencies

    # perl-build command is FatPacker ready
    % curl https://raw.githubusercontent.com/tokuhirom/Perl-Build/master/perl-build | perl - 5.16.2 /opt/perl-5.16/

=head1 CLI interface

    % cpanm Perl::Build
    % perl-build 5.16.2 /opt/perl-5.16/

=head2 Programmable interface

    # install perl from CPAN
    my $result = Perl::Build->install_from_cpan(
        '5.16.2' => (
            dst_path          => '/path/to/perl-5.16.2/',
            configure_options => ['-des'],
        )
    );

    # install perl from tar ball
    my $result = Perl::Build->install_from_cpan(
        'path/to/perl-5.16.2.tar.gz' => (
            dst_path          => '/path/to/perl-5.16.2/',
            configure_options => ['-des'],
        )
    );

=head1 DESCRIPTION

This is yet another perl builder module.

B<THIS IS A DEVELOPMENT RELEASE. API MAY CHANGE WITHOUT NOTICE>.

=head1 METHODS

=over 4

=item C<< Perl::Build->install_from_cpan($version, %args) >>

Install C<< $version >> perl from CPAN. This method fetches tar ball from CPAN, build, and install it.

You can pass following options in C<< %args >>.

=over 4

=item C<< dst_path >>

Destination directory to install perl.

=item C<< configure_options : ArrayRef(Optional) >>

Command line arguments for C<< ./Configure >>.

(Default: C<< ['-de'] >>)

=item C<< tarball_dir >> (Optional)

Temporary directory to put tar ball.

=item C<< build_dir >> (Optional)

Temporary directory to build binary.

=item C<< jobs: Int >> (Optional)

Parallel building and testing.

(Default: C<1>)

=back

=item C<< Perl::Build->install_from_tarball($dist_tarball_path, %args) >>

Install perl from tar ball. This method extracts tar ball, build, and install.

You can pass following options in C<< %args >>.

=over 4

=item C<< dst_path >> (Required)

Destination directory to install perl.

=item C<< configure_options : ArrayRef >> (Optional)

Command line arguments for C<< ./Configure >>.

(Default: C<< ['-de'] >>)

=item C<< build_dir >> (Optional)

Temporary directory to build binary.

=item C<< jobs: Int >> (Optional)

Parallel building and testing.

(Default: C<1>)

=back

=item C<< Perl::Build->install(%args) >>

Build and install Perl5 from extracted source directory.

=over 4

=item C<< src_path >> (Required)

Source code directory to build.  That contains extracted Perl5 source code.

=item C<< dst_path >> (Required)

Destination directory to install perl.

=item C<< configure_options : ArrayRef >> (Optional)

Command line arguments for C<< ./Configure >>.

(Default: C<< ['-de'] >>)

=item C<< test: Bool >> (Optional)

If you set this value as C<< true >>, C<< Perl::Build >> runs C<< make test >> after building.

(Default: C<0>)

=item C<< jobs: Int >> (Optional)

Parallel building and testing.

(Default: C<1>)

=back

Returns an instance of L<Perl::Build::Built> to facilitate using the built perl from code.

=item C<< Perl::Build->symlink_devel_executables($bin_dir:Str) >>

Perl5 binary generated with C<< -Dusedevel >>, is "perl-5.12.2" form. This method symlinks "perl-5.12.2" to "perl".

=back

=head1 FAQ

=over 4

=item How can I use patchperl plugins?

If you want to use patchperl plugins, please Google "PERL5_PATCHPERL_PLUGIN".

=item What's the difference between C<< perlbrew >>?

L<perlbrew> is a perl5 installation manager. But perl-build is a simple perl5 compilation and installation assistant tool.
It makes perl5 installation easily. That's all. perl-build doesn't care about the user's environment.

So, perl-build is just a installer.

=back

=head1 THANKS TO

Most of the code was taken from L<< C<App::perlbrew> >>.

TYPESTER - suggests C<< --patches >> option

Thanks

=head1 AUTHOR

Tokuhiro Matsuno E<lt>tokuhirom@gmail.comE<gt>


=head1 LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This software takes lot of the code from L<App::perlbrew>. App::perlbrew's license is:

    The MIT License

    Copyright (c) 2010,2011 Kang-min Liu

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.


