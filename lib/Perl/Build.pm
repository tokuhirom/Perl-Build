package Perl::Build;
use strict;
use warnings;
use utf8;

use 5.008001;
our $VERSION = '1.34';

use Carp ();
use File::Basename;
use File::Spec::Functions qw(catfile catdir rel2abs);
use CPAN::Perl::Releases;
use CPAN::Perl::Releases::MetaCPAN;
use File::pushd qw(pushd);
use File::Temp;
use HTTP::Tinyish;
use JSON::PP qw(decode_json);
use Devel::PatchPerl 0.88;
use Perl::Build::Built;
use Time::Local;

our $CPAN_MIRROR = $ENV{PERL_BUILD_CPAN_MIRROR} || 'https://cpan.metacpan.org';

sub available_perls {
    my $class = shift;

    my $releases = CPAN::Perl::Releases::MetaCPAN->new->get;
    my @available_versions;
    for my $release (@$releases) {
        if ($release->{name} =~ /^perl-(5.(\d+).(\d+)(-\w+)?)$/) {
            my ($version, $major, $minor, $rc) = ($1, $2, $3, $4);
            my $sort_by = sprintf "%03d%03d%s", $major, $minor, $rc || "ZZZ";
            push @available_versions, { version => $version, sort_by => $sort_by };
        }
    }
    map { $_->{version} } sort { $b->{sort_by} cmp $a->{sort_by} } @available_versions;
}

# @return extracted source directory
sub extract_tarball {
    my ($class, $dist_tarball, $destdir) = @_;

    # Was broken on Solaris, where GNU tar is probably
    # installed as 'gtar' - RT #61042
    my $tar = $^O eq 'solaris' ? 'gtar' : 'tar';

    my $type
        = $dist_tarball =~ m/bz2$/  ? 'j'
        : $dist_tarball =~ m/xz$/   ? 'J'
                                    : 'z';

    my $abs_tarball = File::Spec->rel2abs($dist_tarball);

    my @tar_files = `$tar t${type}f "$abs_tarball"`;
    $? == 0
        or die "Failed to extract $dist_tarball";

    chomp @tar_files;
    my %seen;
    my @prefixes = grep !$seen{$_}++, map m{\A(?:\./)?([^/]+)}, @tar_files;

    die "$dist_tarball does not contain single directory : @prefixes"
        if @prefixes != 1;

    system(qq{cd "$destdir"; $tar x${type}f "$abs_tarball"}) == 0
        or die "Failed to extract $dist_tarball";

    return catfile($destdir, $prefixes[0]);
}

sub perl_release {
    my ($class, $version) = @_;

    my ($dist_tarball, $dist_tarball_url);
    my @err;
    for my $func (qw/cpan_perl_releases metacpan/) {
        eval {
            ($dist_tarball, $dist_tarball_url) = $class->can("perl_release_by_$func")->($class,$version);
        };
        push @err, "[$func] $@" if $@;
        last if $dist_tarball && $dist_tarball_url;
    }
    if (!$dist_tarball and !$dist_tarball_url) {
        push @err, "ERROR: Cannot find the tarball for perl-$version\n";
        die join "", @err;
    }

    return ($dist_tarball, $dist_tarball_url);
}

sub perl_release_by_cpan_perl_releases {
    my ($class, $version) = @_;
    my $tarballs = CPAN::Perl::Releases::perl_tarballs($version);
    my $x = $tarballs->{'tar.gz'} || $tarballs->{'tar.bz2'} || $tarballs->{'tar.xz'};
    die "not found the tarball for perl-$version\n" unless $x;
    my $dist_tarball = (split("/", $x))[-1];
    my $dist_tarball_url = $CPAN_MIRROR . "/authors/id/$x";
    return ($dist_tarball, $dist_tarball_url);
}

sub perl_release_by_metacpan {
    my ($class, $version) = @_;
    my $releases = CPAN::Perl::Releases::MetaCPAN->new->get;
    for my $release (@$releases) {
        if ($release->{name} eq "perl-$version") {
            my ($path) = $release->{download_url} =~ m{(/authors/id/.*)};
            my $dist_tarball = (split("/", $path))[-1];
            my $dist_tarball_url = $CPAN_MIRROR . $path;
            return ($dist_tarball, $dist_tarball_url);
        }
    }
    die "not found the tarball for perl-$version\n";
}

sub perl_release_by_github {
    my ($class, $committish) = @_;

    # URL encode the committish
    require HTTP::Tiny;
    ( my $c = HTTP::Tiny->www_form_urlencode([''=>$committish]) ) =~ s/^=//;
    my $commit_url = "https://api.github.com/repos/Perl/perl5/commits/$c";

    # The API puts the error message in the content, so we can't http_get
    my $res = HTTP::Tinyish->new(verify_SSL => 1)->get($commit_url);

    my %content = do { local $@; local $SIG{__DIE__}; eval {
        %{ decode_json( $res->{content} ) } } };

    unless ($res->{success}) {
        my $m = $content{message} || $res->{reason};
        die "$m\n";
    }

    my $name = $committish;
    $committish = $content{sha};

    # If they specified part of the commit-hash use the full hash as the name.
    # Otherwise they specified a branch or tag, like "blead" or "blead@{date}"
    # and we'll use the prefix plus the commit date.

    if ( $committish =~ /^\Q$name/i ) {
        $name = $content{sha};
    } else {
        $name =~ s/@.*$//;
        $name =~ s{/}{_}g; # branches can have slashes, dest can't
        ( my $date = $content{commit}{committer}{date} ) =~ s/\D//g;
        $name .= "-$date";
    }

    my $url = "https://github.com/Perl/perl5/archive/$committish.tar.gz";

    return ( $url, $name );
}

sub http_get {
    my ($url) = @_;

    my $http = HTTP::Tinyish->new(verify_SSL => 1);
    my $response = $http->get($url);
    if ($response->{success}) {
        return $response->{content};
    } else {
        my $msg = $response->{status} == 599 ? ", $response->{content}" : "";
        chomp $msg;
        die "Cannot get content from $url: $response->{status} $response->{reason}$msg\n";
    }
}

sub http_mirror {
    my ($url, $path) = @_;

    my $http = HTTP::Tinyish->new(verify_SSL => 1);
    my $response = $http->mirror($url, $path);
    if ($response->{success}) {
        print "Downloaded $url to $path.\n";
    } else {
        my $msg = $response->{status} == 599 ? ", $response->{content}" : "";
        chomp $msg;
        die "Cannot get file from $url: $response->{status} $response->{reason}$msg";
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
    my ( $dist_tarball, $dist_tarball_url )
        = ref $version ? @{$version} : Perl::Build->perl_release($version);
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
            local $ENV{TEST_JOBS} = $jobs if $jobs;
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
	@make = qw(make install);
	if ($ENV{PERL_BUILD_INSTALL_OPTIONS}) {
	    push @make, $ENV{PERL_BUILD_INSTALL_OPTIONS};
	}
        $class->do_system(\@make);
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
        my ($name, $version) = basename( $executable ) =~ m/(.+?)(5\.\d.*)?$/;
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

    % git clone https://github.com/tokuhirom/Perl-Build.git $(plenv root)/plugins/perl-build/

=head1 CLI interface without dependencies

    # perl-build command is FatPacker ready
    % curl -L https://raw.githubusercontent.com/tokuhirom/Perl-Build/master/perl-build | perl - 5.16.2 /opt/perl-5.16/

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
    my $result = Perl::Build->install_from_tarball(
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

So, perl-build is just an installer.

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


