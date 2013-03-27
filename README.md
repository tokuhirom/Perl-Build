# NAME

Perl::Build - perl builder

# SYNOPSIS

# CLI interface without dependencies

    # perl-build command is FatPacker ready
    % curl https://raw.github.com/tokuhirom/Perl-Build/master/perl-build | perl - 5.16.2 /opt/perl-5.16/

# CLI interface

    % cpanm Perl::Build
    % perl-build 5.16.2 /opt/perl-5.16/

## Programmable interface

    # install perl from CPAN
    Perl::Build->install_from_cpan(
        '5.16.2' => (
            dst_path          => '/path/to/perl-5.16.2/',
            configure_options => ['-des'],
        )
    );

    # install perl from tar ball
    Perl::Build->install_from_cpan(
        'path/to/perl-5.16.2.tar.gz' => (
            dst_path          => '/path/to/perl-5.16.2/',
            configure_options => ['-des'],
        )
    );

# DESCRIPTION

This is yet another perl builder module.

__THIS IS A DEVELOPMENT RELEASE. API MAY CHANGE WITHOUT NOTICE__.

# METHODS

- Perl::Build->install\_from\_cpan($version, %args)

    Install $version perl from CPAN. This method fetches tar ball from CPAN, build, and install it.

    You can pass following options in %args.

    - dst\_path

        Destination directory to install perl.

    - configure\_options : ArrayRef(Optional)

        Command line arguments for ./Configure.

        (Default: \['-de'\])

    - tarball\_dir(Optional)

        Temporary directory to put tar ball.

    - build\_dir(Optional)

        Temporary directory to build binary.

- Perl::Build->install\_from\_tarball($dist\_tarball\_path, %args)

    Install perl from tar ball. This method extracts tar ball, build, and install.

    You can pass following options in %args.

    - dst\_path(Required)

        Destination directory to install perl.

    - configure\_options : ArrayRef(Optional)

        Command line arguments for ./Configure.

        (Default: \['-de'\])

    - build\_dir(Optional)

        Temporary directory to build binary.

- Perl::Build->install(%args)

    Build and install Perl5 from extracted source directory.

    - src\_path(Required)

        Source code directory to build.  That contains extracted Perl5 source code.

    - dst\_path(Required)

        Destination directory to install perl.

    - configure\_options : ArrayRef(Optional)

        Command line arguments for ./Configure.

        (Default: \['-de'\])

    - test: Bool(Optional)

        If you set this value as true, Perl::Build runs `make test` after building.

        (Default: 0)

- Perl::Build->symlink\_devel\_executables($bin\_dir:Str)

    Perl5 binary generated with ` -Dusedevel `, is "perl-5.12.2" form. This method symlinks "perl-5.12.2" to "perl".

# FAQ

- How can I use patchperl plugins?

    If you want to use patchperl plugins, please google "PERL5\_PATCHPERL\_PLUGIN".

# THANKS TO

Most of the code was taken from [App::perlbrew](http://search.cpan.org/perldoc?App::perlbrew).

TYPESTER - suggests `--patches` option

Thanks

# AUTHOR

Tokuhiro Matsuno <tokuhirom AAJKLFJEF@ GMAIL COM>



# LICENSE

This software takes most of the code from [App::perlbrew](http://search.cpan.org/perldoc?App::perlbrew).

Perl::Build uses same license with perlbrew.
