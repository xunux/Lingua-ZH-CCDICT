use strict;

$^W = 1;

use File::Spec;

use lib File::Spec->curdir, File::Spec->catdir( File::Spec->curdir, 't' );

use File::Temp;

use SharedTests;

use Lingua::ZH::CCDICT::Storage::BerkeleyDB;

Test::More::diag
    ( "\nReading dictionary source file into BerkeleyDB files, this may take a while ..." );

my $source = SharedTests::find_source()
    or die "Cannot find ccdict.txt source file\n";

my $dict =
    Lingua::ZH::CCDICT->new( storage  => 'BerkeleyDB',
                             work_dir => File::Temp::tempdir( undef, CLEANUP => 1 ),
                           );

$dict->parse_source_file($source);

SharedTests::run_tests($dict);
