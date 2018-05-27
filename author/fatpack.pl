#!/usr/bin/env perl
use strict;
use warnings;
use FindBin;
use App::FatPacker::Simple;
use App::cpm::CLI;
use Carton::Snapshot;
use CPAN::Meta::Requirements;
use Getopt::Long ();

sub cpm {
    App::cpm::CLI->new->run(@_) == 0 or die
}

sub fatpack {
    App::FatPacker::Simple->new->parse_options(@_)->run
}

sub gen_snapshot {
    my $snapshot = Carton::Snapshot->new(path => "cpanfile.snapshot");
    my $no_exclude = CPAN::Meta::Requirements->new;
    $snapshot->find_installs("local", $no_exclude);
    $snapshot->save;
}

chdir $FindBin::Bin;

Getopt::Long::GetOptions
    "u|update" => \my $update,
    "h|help" => sub { exec "perldoc", $0 },
or exit 1;

my $target = '5.8.1';

my $resolver = -f "cpanfile.snapshot" && !$update ? "snapshot" : "metadb";

warn "Resolver $resolver\n";
cpm "install", "--cpanfile", "../cpanfile", "--target-perl", $target, "--resolver", $resolver;
gen_snapshot if $update;
print STDERR "FatPacking...";
fatpack
    "-q",
    "-o", "../perl-build",
    "-d", "local,../lib",
    "-e", "Test::Simple,Test,File::Spec,Carp",
    "--shebang", '#!/usr/bin/env perl',
    "../script/perl-build";
print STDERR " DONE\n";

__END__

=head1 NAME

fatpack.pl - fatpack perl-build

=head1 SYNOPSIS

  perl fatpack.pl
  perl fatpack.pl --update

=head1 DESCRIPTION

This script does:

=over 4

=item *

install CPAN module dependencies of perl-build into ./local with cpanfile.snapshot

=item *

fatpack ../script/perl-build with modules in ./local and ../lib

=back

If you want to update CPAN module dependencies and re-generate cpanfile.snapshot,
then execute this script with C<--update> option.

=head1 REQUIREMENT

App::cpm, App::FatPacker::Simple, Carton

You can install them by

  cpanm -nq App::cpm App::FatPacker::Simple Carton

=cut

