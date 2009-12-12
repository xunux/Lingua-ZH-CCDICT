package Lingua::ZH::CCDICT::Storage::InMemory;

use strict;

use base 'Lingua::ZH::CCDICT';

use Params::Validate qw( validate SCALAR );

use Lingua::ZH::CCDICT::ResultSet::Array;

sub new
{
    my $class = shift;
    my %p = validate( @_,
                      { file => { type => SCALAR },
                      },
                    );

    my $self = bless {}, $class;

    $self->parse_source_file( $p{file} );

    return $self;
}

sub add_entry
{
    my $self = shift;
    my $unicode = shift;
    my $entry = shift;

    foreach my $key ( keys %$entry )
    {
        next if $key eq 'english' || $key eq 'unicode';

        foreach my $val ( ref $entry->{$key} eq 'ARRAY' ?
                          @{ $entry->{$key} } :
                          $entry->{$key} )
        {
            # intentionally stringify to take advantage of
            # stringification overloading
            push @{ $self->{$key}{"$val"} }, $unicode;
        }
    }

    $self->{unicode}{$unicode} = $entry;
    $self->{unicode}{$unicode}{unicode} = $unicode;
}

sub all_characters
{
    my $self = shift;

    return
        Lingua::ZH::CCDICT::ResultSet::Array->new
            ( results =>
              [ map { Lingua::ZH::CCDICT::ResultSet->new( %{ $self->{unicode}{$_} } ) }
                sort keys %{ $self->{unicode} } ]
            );
}

sub match_unicode
{
    my $self = shift;

    my %seen;
    my @chars = map { $seen{$_}++ ? () : $_ } sort @_;

    my @results;
    foreach my $char (@chars)
    {
        if ( exists $self->{unicode}{$char} )
        {
            push @results,
                Lingua::ZH::CCDICT::ResultItem->new( %{ $self->{unicode}{$char} } );
        }
    }

    return Lingua::ZH::CCDICT::ResultSet::Array->new( array => \@results );
}

sub _match
{
    my $self = shift;
    my $type = shift;

    return
        $self->match_unicode( map { ( exists $self->{$type}{$_} ?
                                      @{ $self->{$type}{$_} } :
                                      ()
                                    ) }
                              @_
                            );
}

sub entry_count
{
    return scalar keys %{ $_[0]->{unicode} };
}

sub save
{
    # ???
}

1;

__END__

=head1 NAME

Lingua::ZH::CCDICT::Storage::InMemory - Store the dictionary in memory

=head1 USAGE

  use Lingua::ZH::CCDICT;

  my $dict = Lingua::ZH::CCDICT->new( storage => 'InMemory',
                                      file    => '/path/to/source/ccdict.txt',
                                    );

=head1 DESCRIPTION

This module stores the CCDICT dictionary in memory.  It uses a rather
extraordinary amount of memory in doing so (234MB on my system), but
it is fast.

The object can be serialized to disk and reloaded, which is quicker
than parsing the dictionary source repeatedly.

For serious usage, the C<Lingua::ZH::CCDICT::Storage::BerkeleyDB>
class is strongly recommended.

=head1 METHODS

This subclass offers no extra methods.

=head1 SEE ALSO

Lingua::ZH::CCDICT

=cut
