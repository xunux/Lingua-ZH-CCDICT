package Lingua::ZH::CCDICT;

use strict;

# Unicode!
use 5.006001;

use vars qw ($VERSION);

$VERSION = '0.02';

use Params::Validate qw(:all);

my %storage;
BEGIN { %storage = map { lc $_ => $_ } ( qw( InMemory XML BerkeleyDB ) ) }

sub new
{
    my $class = shift;
    my %p = validate_with( params => \@_,
                           spec   =>
                           { storage =>
                             { callbacks =>
                               { 'is a valid storage type' =>
                                 sub { $storage{ lc $_[0] } } },
                             },
                           },
                           allow_extra => 1,
                         );

    my $storage_class = __PACKAGE__ . '::Storage::' . $storage{ lc delete $p{storage} };

    eval "use $storage_class";
    die $@ if $@;

    return $storage_class->new(%p);
}

# map types used in CCDICT to internal hash keys
my %ccdict_to_internal =
    ( fTotalStrokes => 'stroke_count',
      fCangjie      => 'cangjie',
      fFourCorner   => 'four_corner',
    );

my %romanization_to_internal =
    ( fMaciver      => 'maciver',
      fRey          => 'rey',
      fHagfaPinyim  => 'hagfa_pinyim',
      fSiyan        => 'siyan',
      fHailu        => 'hailu',
      fCantonese    => 'jyutping',
      fHanyu        => 'pinyin',
      fTongyong     => 'tongyong',
    );

my %romanization_types = map { $_ => 1 } values %romanization_to_internal;

sub parse_source_file
{
    my $self = shift;
    my $file = shift;
    my $status_fh = shift || $ENV{CCDICT_VERBOSE} ? \*STDERR : undef;
    my $lines_per = shift || 5000;

    open my $fh, "<$file"
        or die "Cannot read $file: $!";

    my $last_char;
    my %entry;
    while (<$fh>)
    {
        chomp;

        # skip internal codes used by CCDICT maintainer
        next unless substr( $_, 0, 1 ) eq 'U';

        my ($unicode, $type, $data) = split /\t/, $_, 3;

        my ($codepoint, $homograph) = $unicode =~ /U\+([\dABCDEF]+)\.(\d)/;

        die "Bad line (line #$.):\n$_\n\n" unless $codepoint;

        # not sure how to handle this, to be honest.
        next if $homograph;

        # generate a real Unicode character in Perl
        my $unicode_char = chr( hex($codepoint) );

        $last_char = $unicode_char unless defined $last_char;

        # this relies on the fact that data for each char is grouped
        # together on consecutive lines in the ccdict.txt file.
        if ( $unicode_char ne $last_char )
        {
            # make a copy on purpose
            $self->add_entry( $last_char, { %entry, unicode => $last_char } );

            %entry = ();

            $last_char = $unicode_char;
        }

        if ( exists $ccdict_to_internal{$type} )
        {
            my $internal = $ccdict_to_internal{$type};

            $entry{$internal} = $data;
        }
        elsif ( exists $romanization_to_internal{$type} )
        {
            my $internal = $romanization_to_internal{$type};

            my $class = $self->romanization_class($internal);

            # turn (obs. foo4) into something splittable
            $data =~ s/\(obs.\s+([^)]+)\)/<<<$1>>>/g;
            foreach my $syl ( split /\s+/, $data )
            {
                # not sure what this means but its in a few places
                next if $syl eq '[INDEX]';

                my $romanized;
                if ( $syl =~ s/<<<([^>]+)>>>/$1/ )
                {
                    $romanized =
                        $class->new( syllable => $syl,
                                     obsolete  => 1,
                                   );
                }
                elsif ( $syl =~ s/\(([^)]+)\)/$1/ )
                {
                    # not sure what simple parens around a syllable
                    # means
                    $romanized = $class->new( syllable => $syl );
                }
                elsif ( $syl =~ s/{([^}]+)}/$1/ )
                {
                    # not sure what braces mean either
                    $romanized = $class->new( syllable => $syl );
                }
                elsif ( $syl =~ s/\[([^\]]+)\]/$1/ )
                {
                    # square brackets?
                    $romanized = $class->new( syllable => $syl );
                }
                elsif ( $syl =~ s,/([^/]+)/,$1, )
                {
                    # slashes?
                    $romanized = $class->new( syllable => $syl );
                }
                else
                {
                    $romanized = $class->new( syllable => $syl );
                }

                next unless $romanized;

                push @{ $entry{$internal} }, $romanized;
            }
        }
        elsif ( $type eq 'fR/S' )
        {
            my ($radical, $index) = split /\./, $data;

            $entry{radical} = $radical;
            $entry{index} = $index;
        }
        elsif ( $type eq 'fAltR/S' )
        {
            my ($radical, $index) = split /\./, $data;

            $entry{alternate_radical} = $radical;
            $entry{alternate_index} = $index;
        }
        elsif ( $type eq 'fEnglish' )
        {
            $entry{english} =
                [ grep { defined && length } split /\s*\[(?:\d\d?|[a-g])\]\s*/, $data ];
        }
        else
        {
            die "Invalid line: $_\n";
        }

        if (  ! ( $. % $lines_per ) && $status_fh )
        {
            print $status_fh "$. lines processed\n";
        }
    }
}

sub romanization_class
{
    return
        ( $_[1] eq 'pinyin' ?
          'Lingua::ZH::CCDICT::Romanization::Pinyin::Hanyu' :
          $_[1] eq 'tongyong' ?
          'Lingua::ZH::CCDICT::Romanization::Pinyin' :
          'Lingua::ZH::CCDICT::Romanization'
        );
}

sub is_romanization_type
{
    return $romanization_types{ $_[1] };
}

sub internal_types
{
    return values %ccdict_to_internal, values %romanization_to_internal, 'index', 'radical';
}

# Some of these may be overridden in subclasses, but they provide an
# easy default
foreach my $type ( __PACKAGE__->internal_types )
{
    my $sub_name = "match_$type";
    no strict 'refs';

    *{$sub_name} = sub { shift->_match( $type => @_ ) };
}

package Lingua::ZH::CCDICT::Romanization;

use Params::Validate qw( validate SCALAR BOOLEAN );

use overload
    ( '""'   => sub { $_[0]->syllable },
      'bool' => sub { 1 },
      'cmp'  => sub { return
                          ( $_[2] ?
                            ( $_[1] cmp $_[0]->syllable ) :
                            ( $_[0]->syllable cmp $_[1] )
                          ); },
    );

sub new
{
    my $class = shift;

    my %p = validate( @_,
                      { syllable => { type => SCALAR },
                        obsolete => { type => BOOLEAN, default => 0 },
                      },
                    );

    unless ( $p{syllable} =~ /^[a-z1-9']+$/ )
    {
        warn "Bad romanization: $p{syllable}\n" if $ENV{DEBUG_CCDICT_SOURCE};
        return;
    }

    return bless \%p, $class;
}

sub syllable { $_[0]->{syllable} }

sub is_obsolete { $_[0]->{obsolete} }

package Lingua::ZH::CCDICT::Romanization::Pinyin;

use base 'Lingua::ZH::CCDICT::Romanization';

my $umlaut_u = chr(252);

my %pinyin_unicode =
    ( a1 => chr(257),
      e1 => chr(275),
      i1 => chr(299),
      o1 => chr(333),
      u1 => chr(363),
      "${umlaut_u}1" => chr(470),

      a2 => chr(225),
      e2 => chr(233),
      i2 => chr(237),
      o2 => chr(243),
      u2 => chr(250),
      "${umlaut_u}2" => chr(472),

      a3 => chr(462),
      e3 => chr(283),
      i3 => chr(464),
      o3 => chr(466),
      u3 => chr(468),
      "${umlaut_u}3" => chr(474),

      a4 => chr(224),
      e4 => chr(232),
      i4 => chr(236),
      o4 => chr(242),
      u4 => chr(249),
      "${umlaut_u}4" => chr(476),
    );

sub new
{
    my $self = shift->SUPER::new(@_);

    # handle errors found in parent class
    return unless defined $self->{syllable};

    $self->_make_unicode_version;

    return $self;
}

sub _make_unicode_version
{
    my $self = shift;

    my @syls = split /(?<=\d)/, $self->{syllable};

    $self->{pinyin_unicode} =
        join '', map { $self->_pinyin_as_unicode($_) } @syls;

    return $self;
}

sub _pinyin_as_unicode
{
    my $self = shift;
    my $syl = shift;

    my $num = chop $syl;

    unless ( $num =~ /[12345]/ )
    {
        warn "Bad pinyin: $self->{syllable}\n" if $ENV{DEBUG_CCDICT_SOURCE};
        return;
    }

    # no tone marking
    return $syl if $num == 5;

    my @letters = split //, $syl;

    my $vowel_count = grep { /[aeiou$umlaut_u]/ } @letters;

    my $vowel_to_change;
    for ( my $x = 0; $x <= $#letters; $x++ )
    {
        if ( $letters[$x] =~ /[aeiou$umlaut_u]/ )
        {
            $vowel_to_change = $x;
            last;
        }
    }

    unless ( $vowel_to_change )
    {
        warn "Bad pinyin: $self->{syllable}\n" if $ENV{DEBUG_CCDICT_SOURCE};
        return;
    }

    if ( $letters[$vowel_to_change + 1] &&
         $letters[$vowel_to_change + 1] =~ /[aeiou$umlaut_u]/ )
    {
        # handle multiple vowels properly
        $vowel_to_change++
            unless ( $letters[$vowel_to_change + 1] eq 'u' ||
                     $letters[$vowel_to_change + 1] eq 'o' );
    }

    $letters[$vowel_to_change] = $pinyin_unicode{"$letters[$vowel_to_change]$num"};

    return join '', @letters;
}

sub as_unicode { $_[0]->{pinyin_unicode} }

package Lingua::ZH::CCDICT::Romanization::Pinyin::Hanyu;

use base 'Lingua::ZH::CCDICT::Romanization::Pinyin';

sub new
{
    my $self = shift->SUPER::new(@_);

    # handle errors found in parent class
    return unless defined $self->{syllable};

    $self->{ascii} = $self->{syllable};
    $self->{syllable} =~ s/uu/$umlaut_u/g;

    $self->_make_unicode_version;

    return $self;
}

sub as_ascii { $_[0]->{ascii} }

package Lingua::ZH::CCDICT::ResultItem;

use Params::Validate qw( validate SCALAR UNDEF ARRAYREF );

foreach my $item ( qw( unicode radical index alternate_radical alternate_index
                       stroke_count cangjie four_corner ) )
{
    no strict 'refs';
    *{ __PACKAGE__ . "::$item"} =
        sub { return unless exists $_[0]->{$item};
              $_[0]->{$item} };
}

foreach my $item ( qw( maciver rey hagfa_pinyim siyan hailu
                       jyutping pinyin tongyong english ) )
{
    no strict 'refs';
    *{ __PACKAGE__ . "::$item"} =
        sub { return unless exists $_[0]->{$item};
              wantarray ? @{ $_[0]->{$item} } : $_[0]->{$item}[0] };

}
*hanyu   = \&pinyin;

sub new
{
    my $class = shift;
    my %p = validate( @_,
                      { unicode  => { type => SCALAR },
                        radical  => { type => SCALAR },
                        index    => { type => SCALAR },
                        alternate_radical => { type => SCALAR, optional => 1 },
                        alternate_index   => { type => SCALAR, optional => 1 },
                        stroke_count => { type => SCALAR, optional => 1 },
                        cangjie  => { type => SCALAR, optional => 1 },
                        four_corner => { type => SCALAR, optional => 1 },
                        maciver  => { type => ARRAYREF, optional => 1 },
                        rey      => { type => ARRAYREF, optional => 1 },
                        hagfa_pinyim => { type => ARRAYREF, optional => 1 },
                        siyan    => { type => ARRAYREF, optional => 1 },
                        hailu    => { type => ARRAYREF, optional => 1 },
                        jyutping => { type => ARRAYREF, optional => 1 },
                        pinyin   => { type => ARRAYREF, optional => 1 },
                        tongyong => { type => ARRAYREF, optional => 1 },
                        english => { type => ARRAYREF, optional => 1 },
                      },
                    );

    return bless \%p, $class;
}

1;

__END__


=head1 NAME

Lingua::ZH::CCDICT - An interface to the CCDICT Chinese dictionary

=head1 SYNOPSIS

  use Lingua::ZH::CCDICT;

  my $dict = Lingua::ZH::CCDICT->new( storage => 'InMemory',
                                      file    => '/path/to/ccdict.txt',
                                    );

=head1 DESCRIPTION

This module provides a Perl interface to the CCDICT dictionary created
by Thomas Chin.  This dictionary is indexed by Unicode character
number (traditional character), and contains information about these
characters.

As of version 3.2.0 of the dictionary, it was released under the Open
Publication License v0.4, without either of the optional clauses.  See
the CCDICT licensing statement for more details.  IANAL, but I believe
that the OPL combined with the fact that this module is under the same
terms as Perl itself, makes this module and the CCDICT dictionary fit
both the Free Software and Open Source definitions.

The dictionary contains the following information, though not all
information is avaialable for every character.

=over 4

=item * Radical number

The number of the radical.  Always available.

=item * Index

The total number of strokes minus the number of strokes in the
radical.  Always available.

=item * Alternate radical number and index

Actually, the dictionary defines a format for storing this
information, but as of version 3.2.0 of the dictionary, it does not
actually contain this for any characters.

=item * Total stroke count

The total number of strokes in the character.

=item * Cangjie

The Cangjie Chinese input system code.

=item * Four Corner

The Four Corner Chinese input system code.

=back

In addition, the dictionary contains English definitions (often
multiple definitions), and romanizations for the character in
different languages and systems.  The romanizations available include
the MacIver, Rey, Hagfa Pinyim, Siyan, and Hailu systems for Hakka, as
well as the Jyutping Cantonese system and the Hanyu and Tongyong
Pinyin systems for Mandarin.

The Hanyu Pinyin system was invented in Mainland China in 1952, while
the TongYong Pinyin system is a variation on this system invented in
Taiwan in 1998.  TongYong PinYin was adopted as Taiwan's official
Pinyin system in 2001.

However, due to the overwhelming dominance of the Hanyu system in
worldwide Chinese education, the Hanyu system is generally known
simply as Pinyin.  If you studied Mandarin as a foreign language, it
is likely that you learned Hanyu Pinyin.

=head1 DICTIONARY BUGS

The CCDICT dictionary is distributed by Thomas Chin in a simple, but
non-standard, textual ASCII-only format.  Errors in the dictionary are
handled by this module internally, although occasional odd entries may
result in odd data.  Please send bug reports to me so I can make sure
that the error is actually in the dictionary, not in this code.

=head1 STORAGE

This module is capable of parsing the CCDICT format file, and can also
rewrite it in a number of other formats, including XML or as a set of
BerkeleyDB files.

Each storage system is implemented via a module in the
C<Lingua::ZH::CCDICT::Storage::*> class hierarchy.  All of these
modules are subclasses of C<Lingua::ZH::CCDICT> class, and implement
its methods for searching the dictionary.

In addition some storage classes may offer additional methods.

=head2 Storage Subclasses

The following storage subclasses are available:

=over 4

=item * Lingua::ZH::CCDICT::Storage::InMemory

This class stores the entire parsed dictionary in memory.  Be
forewarned, on my GNU/Linux 2.4 machine, this takes about B<234
megabytes> of memory.  Carpe user!

The only parameter it takes is "file", which should contain the full
path to a CCDICT source file.

=item * Lingua::ZH::CCDICT::Storage::XML

This class can convert the CCDICT source file to XML, and perform
searches on it using XML::Twig.

The only parameter it takes is "xml_file", which should contain the
full path to a CCDICT xml file.  If the C<parse_source_file> method is
called, then the XML file specified by the "xml_file" parameter will
be created, overwriting any existing data.

This class is quite memory-efficient but searches are painfully slow.

=item * Lingua::ZH::CCDICT::Storage::BerkeleyDB

This class can convert the CCDICT source file to a set of BerkeleyDB
files.

The only parameter it takes is "work_dir".  This directory will be
used when creating new files from a CCDICT source file, when
C<parse_source_file> is called.  Once these files exist, they can be
used to perform searches.

This class is the most memory-efficient of all the storage classes, as
it uses BerkeleyDB cursors for result sets.  It is also quite fast.

=back

=head1 USAGE

This module allows you to look up information in the dictionary based
on a number of keys.  These include the Unicode character (as a
character, not its number), stroke count, radical number, and any of
the various romanization systems.

=head1 METHODS

These methods are always available.

=over 4

=item * new

This method always takes at least one parameter, "storage".  This
indicates what storage subclass to use.  The current options are
"InMemory", "XML", and "BerkeleyDB".

Any other parameters given will be passed to the appropriate
subclass's C<new> method.

=item * parse_source_file ($filename)

Given a source file, this will parse it and create a representation of
the appropriate type.

=back

=head2 Match methods

When doing a lookup based on the romanization of a character, the tone
is indicated with a number at the end of the syllable, as opposed to
using the Unicode character combining the latin letter with the
diacritic.

In addition, lookups based on a Hanyu Pinyin romanization should use
the u-with-umlaut character (character 252 in ASCII) rather than a
doubled "u" character.  Lower case should be used when doing lookups
on romanizations.

The return value for any lookup will be an object of an
C<Lingua::ZH::CCDICT::ResultSet> subclass.  All the subclasses share a
similar interface, described below.

Result sets always return matches in ascending Unicode character
order.

=over 4

=item * match_unicode (@chars)

This method matches on one or more Unicode characters.  Unicode
characters should be given as Perl characters (i.e. C<chr(0x7D20)>),
not as a number.

This dictionary index uses I<traditional> Chinese characters.
Simplified character lookups will not work.

=item * match_radical (@numbers)

Given a set of numbers, this method returns those characters
containing the specified radical(s).

=item * match_index (@numbers)

Given a set of numbers, this method returns those characters
containing the specified index(es).

=item * match_alternate_radical (@numbers)

Given a set of numbers, this method returns those characters
containing the specified radical(s) as alternates.

=item * match_alternate_index (@numbers)

Given a set of numbers, this method returns those characters
containing the specified index(es) as alternates.

=item * match_stroke_count (@numbers)

Given a set of numbers, this method returns those characters
containing the specified number(s) of strokes.

=item * match_cangjie (@codes)

Given a set of Cangjie codes, this method returns the character(s) for
those code(s).

=item * match_four_corner (@codes)

Given a set of Four Corner codes, this method returns the character(s)
for those code(s).

=item * match_maciver (@romanizations)

=item * match_rey (@romanizations)

=item * match_hagfa_pinyim (@romanizations)

=item * match_siyan (@romanizations)

=item * match_hailu (@romanizations)

=item * match_jyutpinh (@romanizations)

=item * match_pinyin (@romanizations)

This returns matches for I<Hanyu> Pinyin.

=item * match_tongyong (@romanizations)

=item * all_characters

Returns a result set containing all of the characters in the
dictionary.

=item * entry_count

Returns the number of entries in the dictionary

=back

=head2 The Lingua::ZH::CCDICT::ResultSet Class

This class offers the following API:

=over 4

=item * next

Return the next item in the result set.  If there are no items left
then a false value is returned.  A subsequent call will start back at
the first result.

=item * all

Returns all of the items in the result set.

=item * reset

Resets the index so that the next call to I<next> returns the first
item in the set.

=item * count

Returns a number indicating how many items have been returned so far.

=back

Subclasses of this class may offer additional methods.  See their
documentation for details.

=head2 The Lingua::ZH::CCDICT::ResultItem Class

Each individual result returned by an iterator returns an object of
this class.  This class provides the following methods:

=over 4

=item * unicode

=item * radical

=item * index

=item * alternate_radical

=item * alternate_index

=item * stroke_count

=item * cangjie

=item * four_corner

These methods always return a single item, when the requested data is
available, or a false value if this item is not available.

=item * maciver

=item * rey

=item * hagfa_pinyim

=item * siyan

=item * hailu

=item * jyutping

=item * pinyin

Also available via the method C<hanyu>.

=item * tongyong

=item * english

These methods represent data for which there may be multiple values.
In a list context, all values are returned.  In a scalar context, only
the first value is returned.  When the requested data is not
available, a false value is returned.

Romanizations are returned as C<Lingua::ZH::CCDICT::Romanization>
objects.  This class is described below.

=back

=head2 The Lingua::ZH::CCDICT::Romanization Class

This class represents romanizations.  For all romanizations, two
methods are available:

=over 4

=item * syllable

This is the romanized syllable, with the tone indicated via a number
at the end of the syllable.

=item * is_obsolete

The CCDICT dictionary marks some romanizations as obselete.  For those
entries, this value is true.

=back

All objects of this class are overloaded so that they stringify to the
value of the C<syllable> method, and in string comparisons they use
the value of this method as well.  In addition, they are overloaded in
a boolean context to return true.

The C<Lingua::ZH::CCDICT::Romanization::Pinyin> class is used for the
return values of the C<Lingua::ZH::CCDICT::ResultItem> class's
C<tongyong> method, and provides the following additional method:

=over 4

=item * as_unicode

The syllable with tone markings as diacritics using Unicode characters
where needed.

=back

The C<Lingua::ZH::CCDICT::Romanization::Pinyin::Hanyu> class is used
for the return values of the C<Lingua::ZH::CCDICT::ResultItem> class's
C<pinyin> method.  This class provides the C<as_unicode> method
described above, as well as:

=over 4

=item * as_ascii

The syllable with umlaut-"u" characters replaced with a doubled "u".
Useful when you can only display ASCII.

=back

=head1 ENVIRONMENT VARIABLES

=over 4

=item * CCDICT_DEBUG_SOURCE

Causes a warning when bad data is enountered in the ccdict dictionary
source.  This is primarily useful if you want to find bugs in the
dictionary itself.

=item * CCDICT_VERBOSE

Tells the module to give you progress reports when parsing the source
file.  These are sent to STDERR.

=back

=head1 AUTHOR

David Rolsky <autarch@urth.org>

=head1 COPYRIGHT

Copyright (c) 2002-2003 David Rolsky.  All rights reserved.  This
program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included
with this module.

=head1 CCDICT COPYRIGHT

Copyright (c) 1995-2002 Thomas Chin.

=head1 SEE ALSO

Lingua::ZH::CCDICT::Storage::InMemory,
Lingua::ZH::CCDICT::Storage::BerkeleyDB

Lingua::ZH::CEDICT - for converting between Chinese and English.

Encode::HanConvert and Lingua::ZH::HanConvert - for converting between
simplified and traditional characters in various character sets.

http://www.chinalanguage.com/CCDICT/ - the home of the CCDICT
dictionary.

=cut

