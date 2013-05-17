use strict;
use warnings;

use Test::More;
use Perl::Build::Built;

sub exception(&) {
    my $code       = shift;
    my $prev_error = $@;
    my ( @ret, $error, $failed );
    {
        local $@;
        $failed = not eval {
            $@ = $prev_error;
            $code->();
            return 1;
        };
        $error = $@;
    }
    if ( !$failed ) {
        return undef;
    }
    return $error;
}

sub lives($$) {
    my ( $result, @reason ) = @_;
    @_ = ( $result, undef, @reason );
    goto \&is;
}

sub throws($$) {
    my ( $result, @reason ) = @_;
    @_ = ( $result, undef, @reason );
    goto \&isnt;
}

my $sample;

throws exception { die "can catch" }, 'minimal exception test works';

lives exception {
    $sample =
      Perl::Build::Built->new( { installed_path => 'wizzardry_example' } );
},
  'new does not bail';

throws exception {
    $sample->run_env( [] );
}, 'array ref is invalid';

lives exception {
    $sample->run_env(
        sub {
            like( $ENV{PATH}, qr/wizzardry_example/,
                'installed_path propagates to ENV{PATH}' );
        }
    );
}, 'run_env runs';

lives exception {
    unlike( $sample->combined_man_path || '',
        qr/wizzardry_example/,
        "combined_man_path not inclusive due to no real man path existing" );
}, 'combined_man_path lives';

done_testing;
