package Lingua::ZH::CCDICT::ResultSet::Array;

use strict;

sub new
{
    my $class = shift;
    my %p = @_;

    return bless { index => 0,
                   array => $p{array},
                 }, $class;
}

sub next
{
    my $self = shift;

    my $index = $self->{index};

    unless ( exists $self->{array}[$index] )
    {
        $self->{index} = 0;

        return;
    }

    $self->{index}++;

    return $self->{array}[$index];
}

sub all
{
    my $self = shift;

    return @{ $self->{array} };
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

Lingua::ZH::CCDICT::ResultSet::Array - An iterator over an array

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

It does this by simply returning results one at a time from an array
in memory.

=cut
