use strict;

$^W = 1;

use File::Spec;

use lib File::Spec->curdir, File::Spec->catdir( File::Spec->curdir, 't' );

use File::Spec;

use SharedTests;

use Lingua::ZH::CCDICT::Storage::InMemory;

Test::More::diag
    ( "\nReading dictionary source file into memory, this may take a while ..." );

my $source = SharedTests::find_source()
    or die "Cannot find ccdict.txt source file\n";

my $dict =
    Lingua::ZH::CCDICT->new( storage => 'InMemory',
                             file    => $source,
                           );

SharedTests::run_tests($dict);

Test::More::diag
    ( "\nFinished tests, process exit may take a while ..." );
