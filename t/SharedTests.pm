package SharedTests;

use strict;

my $umlaut_u = chr(252);

use Test::More;

if ( _should_run_tests() )
{
    plan tests => 53;
}
else
{
    plan skip_all => <<'EOF';
Tests take a long time to run.  Set the CCDICT_RUN_TESTS variable to a true value if you really want to run them.
EOF
}

sub run_tests
{
    my $dict = shift;

    {
        my $results = $dict->match_unicode( chr 0x7DD1 );

        ok( $results,
            "match_unicode should return something" );

        my @results = $results->all;

        is( scalar @results, 1,
            "match_unicode should only return one result when given one character" );

        my $item = $results[0];

        my @py = $item->pinyin;

        is( $item->radical, 120,
            "radical should be 120" );

        is( $item->index, 8,
            "index should be 8" );

        is( $item->stroke_count, 14,
            "index should be 8" );

        is( @py, 2,
            "should be two pinyin romanizations for this character" );

        is( $py[0]->as_ascii, 'luu4',
            "first pinyin romanization should be luu4 in ascii" );

        is( $py[0]->is_obsolete, 0,
            "first pinyin romanization should not be obsolete" );

        is( $py[0]->syllable, "l${umlaut_u}4",
            "first pinyin romanization should be luu4 in ascii" );

        my $expect = 'l' . chr(476);
        is( $py[0]->as_unicode, $expect,
            "first pinyin's unicode version is not what was expected" );

        is( $py[1]->as_ascii, 'lu4',
            "second pinyin romanization should be lu4 in ascii" );

        is( $py[1]->is_obsolete, 0,
            "second pinyin romanization should not be obsolete" );

        is( $py[1]->syllable, "lu4",
            "second pinyin romanization should be lu4 in ascii" );

        $expect = 'l' . chr(249);
        is( $py[1]->as_unicode, $expect,
            "second pinyin's unicode version is not what was expected" );

        my @ty = $item->tongyong;

        is( @ty, 2,
            "should be two pinyin romanizations for this character" );

        is( $ty[0]->is_obsolete, 0,
            "first pinyin romanization should not be obsolete" );

        is( $ty[0]->syllable, "lyu4",
            "first pinyin romanization should be luu4 in ascii" );

        $expect = 'ly' . chr(249);
        is( $ty[0]->as_unicode, $expect,
            "first pinyin's unicode version is not what was expected" );

        is( $ty[1]->is_obsolete, 0,
            "second pinyin romanization should not be obsolete" );

        is( $ty[1]->syllable, "lu4",
            "second pinyin romanization should be lu4 in ascii" );

        my $expect = 'l' . chr(249);
        is( $ty[1]->as_unicode, $expect,
            "second pinyin's unicode version is not what was expected" );
    }

    {
        my $results = $dict->match_unicode( chr 0x7DD7 );

        ok( $results,
            "match_unicode should return something" );

        my @results = $results->all;

        is( scalar @results, 1,
            "match_unicode should only return one result when given one character" );

        my $item = $results[0];

        is( $item->cangjie, 'VFDBU',
            "cangjie should be VFDBU" );

        is( $item->four_corner, 26900,
            "four_corner should be 26900" );

        foreach ( [ maciver  => 'siong1' ],
                  [ rey      => 'siong1' ],
                  [ siyan    => 'siong1' ],
                  [ hailu    => 'siong1' ],
                  [ jyutping => 'soeng1' ],
                  [ english  => 'light-yellow silk' ],
                )
        {
            my $type = $_->[0];

            my @pieces = $item->$type();

            is( scalar @pieces, 1,
                "$type should only return one item" );

            is( $pieces[0], $_->[1],
                "$type should return $_->[1]" );
        }
    }

    {
        my $results = $dict->match_maciver("s'uk8");

        my @results = $results->all;

        is( scalar @results, 13,
            "match_maciver should return thirteen results when given s'uk8" );

        foreach my $char ( sort { hex $a <=> hex $b }
                           qw( 0x587E
                               0x5B70
                               0x5C5E
                               0x5C6C
                               0x719F
                               0x8961
                               0x8969
                               0x8D16
                               0x8D4E
                               0x9E00
                               0x20169
                               0x21492
                               0x2150A
                             )
                         )
        {
            is( ord( (shift @results)->unicode), hex $char,
                "the result should be unicode character $char" );
        }
    }

    {
        my $results = $dict->match_four_corner(26900);

        my @results = $results->all;

        is( scalar @results, 14,
            "match_four_corner should return fourteen result when given 26900" );

        is( ord( $results[0]->unicode ), 0x4138,
            "the first result should be unicode character 0x4138" );
    }


}

sub _should_run_tests
{
    # .svn dir should only be on maintainer boxes
    return $ENV{CCDICT_RUN_TESTS} || -d '.svn';
}

sub find_source
{
    foreach my $dir ( File::Spec->curdir,
                      File::Spec->updir,
                      File::Spec->catdir( File::Spec->updir, File::Spec->updir )
                    )
    {
        my $source = File::Spec->catfile( $dir, 'ccdict', 'ccdict.txt' );
        return $source if -e $source;
    }
}

1;
