package Lingua::ZH::CCDICT::ResultSet::BerkeleyDB;

use strict;

use BerkeleyDB qw( DB_NEXT );
use Storable ();

sub new
{
    my $class = shift;
    my %p = @_;

    return bless { index => 0,
                   keys  => $p{keys},
                   db    => $p{db},
                 }, $class;
}

sub next
{
    my $self = shift;

    my $index = $self->{index};

    unless ( exists $self->{keys}[$index] )
    {
        $self->{index} = 0;

        return;
    }

    my $value = $self->_get_value( $self->{keys}[$index] );

    $self->{index}++;

    return Lingua::ZH::CCDICT::ResultItem->new( Storable::thaw($value) );
}

sub all
{
    my $self = shift;

    return
        ( map { Lingua::ZH::CCDICT::ResultItem->new( Storable::thaw( $self->_get_value($_) ) ) }
          @{ $self->{keys} }
        );
}

sub _get_value
{
    my $self = shift;
    my $key = shift;

    my $value;
    my $status = $self->{db}->db_get( $key, $value );

    die "Failed to retrieve key ($key): $status" if $status;

    return $value;
}

sub count
{
    my $self = shift;

    return $self->{index};
}

sub reset
{
    my $self = shift;

    $self->{index} = 0;
}

1;

__END__

=head1 NAME

Lingua::ZH::CCDICT::ResultSet::BerkeleyDB - Iterates over results in a BerkeleyDB database

=head1 SYNOPSIS

  my $results = $ccdict->match_unicode( chr(0x8830), chr(0x88A4) );

  while ( my $result = $results->next )
  {
      print "Result Number ", $result->count, ": ";
      print " cangjie is ", $result->cangjie, "\n";
  }

=head1 DESCRIPTION

This module implements the C<Lingua::ZH::CCDICT::ResultSet> interface,
as described in C<Lingua::ZH::CCDICT>.

It does this by fetching results from a BerkeleyDB database based on
an array of keys stored in memory.

=cut
