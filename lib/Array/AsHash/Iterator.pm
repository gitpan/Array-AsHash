package Array::AsHash::Iterator;

use strict;
use warnings;

use Class::Std;

our $VERSION = '0.01';

{
    my %parent_of    :ATTR( :init_arg<parent> );
    my %iterator_for :ATTR( :init_arg<iterator> );

    sub next {
        my $self = shift;
        return $iterator_for{ident $self}->();
    }

    sub first {
        my $self = shift;
        return $parent_of{ident $self}->first;
    }

    sub last {
        my $self = shift;
        return $parent_of{ident $self}->last;
    }

    sub reset_each {
        my $self = shift;
        return $parent_of{ident $self}->reset_each;
    }

    sub parent {
        my $self = shift;
        return $parent_of{ident $self};
    }
}

1;
__END__

=head1 NAME

Array::AsHash::Iterator - Iterator object for L<Array::AsHash>

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    my $iterator = Array::AsHash->new({array => \@array})->each;

    while (my ($key, $value) = $iterator->next) {
        print "First \n" if $iterator->first;
        print "$key : $value\n";
        print "Last \n" if $iterator->last;
    }

=head1 DESCRIPTION

This is the iterator returned by the C<Array::AsHash::each> method.  Do not
instantiate this class directly, it won't work.

=head1 EXPORT

None.

=head1 METHODS

=head2 next

  while (my ($key, $value) = $iterator->next) {
    ...
  }

Returns the next key/value pair in the iterator.

=head2 first

  if ($iterator->first) {
    ...
  }

Returns true after when we are on the first key/value pair (after it has been
returned) and before we have returned the second key/value pair.

=head2 last

  if ($iterator->last) {
    ...
  }

Returns true after we have returned the last key/value pair.

=head2 parent

 my $parent = $iterator->parent;

Returns the parent L<Array::AsHash> object used to create the iterator.

=head2 reset_each

 $iterator->reset_each;

As with a regular hash, if you do not iterate over all of the data, the internal
pointer will be pointing at the I<next> key/value pair to be returned.  If you need
to restart from the beginning, call the C<reset_each> method.

=head1 AUTHOR

Curtis "Ovid" Poe, C<< <ovid@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-array-ashash@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Array-AsHash>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SEE ALSO

L<Clone>, L<Tie::IxHash>, L<Array::AsHash>, L<Class::Std> (how this module is
implemented).

=head1 COPYRIGHT & LICENSE

Copyright 2005 Curtis "Ovid" Poe, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
