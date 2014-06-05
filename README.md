# NAME

Perl::Build - perl builder

# SYNOPSIS

# Install as plenv plugin(Recommended)

    % git clone git://github.com/tokuhirom/Perl-Build.git ~/.plenv/plugins/perl-build/

# CLI interface without dependencies

    # perl-build command is FatPacker ready
    % curl https://raw.githubusercontent.com/tokuhirom/Perl-Build/master/perl-build | perl - 5.16.2 /opt/perl-5.16/

# CLI interface

    % cpanm Perl::Build
    % perl-build 5.16.2 /opt/perl-5.16/

## Programmable interface

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

# DESCRIPTION

This is yet another perl builder module.

**THIS IS A DEVELOPMENT RELEASE. API MAY CHANGE WITHOUT NOTICE**.

# METHODS

- Perl::Build->install\_from\_cpan($version, %args)

    Install $version perl from CPAN. This method fetches tar ball from CPAN, build, and install it.

    You can pass following options in %args.

    - dst\_path

        Destination directory to install perl.

    - configure\_options : ArrayRef(Optional)

        Command line arguments for ./Configure.

        (Default: `['-de']`)

    - tarball\_dir (Optional)

        Temporary directory to put tar ball.

    - build\_dir (Optional)

        Temporary directory to build binary.

    - jobs: Int(Optional)

        Parallel building and testing.

        (Default: 1)

- Perl::Build->install\_from\_tarball($dist\_tarball\_path, %args)

    Install perl from tar ball. This method extracts tar ball, build, and install.

    You can pass following options in %args.

    - dst\_path (Required)

        Destination directory to install perl.

    - configure\_options : ArrayRef(Optional)

        Command line arguments for ./Configure.

        (Default: `['-de']`)

    - build\_dir (Optional)

        Temporary directory to build binary.

    - jobs: Int(Optional)

        Parallel building and testing.

        (Default: 1)

- Perl::Build->install(%args)

    Build and install Perl5 from extracted source directory.

    - src\_path (Required)

        Source code directory to build.  That contains extracted Perl5 source code.

    - dst\_path (Required)

        Destination directory to install perl.

    - configure\_options : ArrayRef(Optional)

        Command line arguments for ./Configure.

        (Default: `['-de']`)

    - test: Bool(Optional)

        If you set this value as true, Perl::Build runs `make test` after building.

        (Default: 0)

    - jobs: Int(Optional)

        Parallel building and testing.

        (Default: 1)

    Returns an instance of [Perl::Build::Built](https://metacpan.org/pod/Perl::Build::Built) to facilitate using the built perl from code.

- Perl::Build->symlink\_devel\_executables($bin\_dir:Str)

    Perl5 binary generated with ` -Dusedevel `, is "perl-5.12.2" form. This method symlinks "perl-5.12.2" to "perl".

# FAQ

- How can I use patchperl plugins?

    If you want to use patchperl plugins, please Google "PERL5\_PATCHPERL\_PLUGIN".

- What's the difference between perlbrew?

    [perlbrew](https://metacpan.org/pod/perlbrew) is a perl5 installation manager. But perl-build is a simple perl5 compilation and installation assistant tool.
    It makes perl5 installation easily. That's all. perl-build doesn't care about the user's environment.

    So, perl-build is just a installer.

# THANKS TO

Most of the code was taken from [App::perlbrew](https://metacpan.org/pod/App::perlbrew).

TYPESTER - suggests `--patches` option

Thanks

# AUTHOR

Tokuhiro Matsuno <tokuhirom@gmail.com>

# LICENSE

Copyright (C) Tokuhiro Matsuno

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

This software takes lot of the code from [App::perlbrew](https://metacpan.org/pod/App::perlbrew). App::perlbrew's license is:

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
