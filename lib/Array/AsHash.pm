package Array::AsHash;

use warnings;
use strict;
use Class::Std;
use Clone ();
use Scalar::Util qw(refaddr);

our $VERSION = '0.01';

{
    my ( %index_of, %array_for, %current_index_for, %curr_key_of ) : ATTRS;

    my $_actual_key = sub {
        my ( $self, $key ) = @_;
        if ( ref $key ) {
            my $new_key = $curr_key_of{ ident $self}{ refaddr $key};
            return refaddr $key unless defined $new_key;
            $key = $new_key;
        }
        return $key;
    };

    my $_insert = sub {
        my ( $self, $key, $label, $index ) = splice @_, 0, 4;
        $key = $self->$_actual_key($key);

        unless ( $self->exists($key) ) {
            $self->_croak("Cannot insert $label non-existent key ($key)");
        }
        if ( @_ % 2 ) {
            $self->_croak("Arguments to insert must be an even-sized list");
        }
        my $ident = ident $self;
        foreach ( my $i = 0 ; $i < @_ ; $i += 2 ) {
            my $new_key = $_[$i];
            if ( $self->exists($new_key) ) {
                $self->_croak("Cannot insert duplicate key ($new_key)");
            }
            $index_of{$ident}{$new_key} = $index + $i;
        }

        my @tail = splice @{ $array_for{$ident} }, $index;
        push @{ $array_for{$ident} }, @_, @tail;    #oops!  Need the indices
        my %seen = @_;
        foreach my $curr_key ( CORE::keys %{ $index_of{$ident} } ) {
            if ( $index_of{$ident}{$curr_key} >= $index && !$seen{$curr_key} ) {
                $index_of{$ident}{$curr_key} += @_;
            }
        }
        return $self;
    };

    # private because it doesn't match expectations.  The "index" of a
    # non-existent key is one greater than the current list
    my $_index = sub {
        my ( $self, $key ) = @_;
        my $ident = ident $self;
        my $index =
          $self->exists($key)
          ? $index_of{$ident}{$key}
          : scalar @{ $array_for{$ident} };    # automatically one greater
        return $index;
    };

    sub BUILD {
        my ( $class, $ident, $arg_ref ) = @_;
        my $array = $arg_ref->{array} || [];
        my $clone = $arg_ref->{clone} || 0;
        $array = Clone::clone($array) if $clone;

        unless ( 'ARRAY' eq ref $array ) {
            $class->_croak('Argument to new() must be an array reference');
        }
        if ( @$array % 2 ) {
            $class->_croak('Uneven number of keys in array');
        }

        $array_for{$ident} = $array;
        foreach ( my $i = 0 ; $i < @$array ; $i += 2 ) {
            my $key = $array->[$i];
            $index_of{$ident}{$key} = $i;
            if ( ref $key ) {
                my $old_address = refaddr $arg_ref->{array}[$i];
                my $curr_key    = "$key";
                $curr_key_of{$ident}{$old_address} = $curr_key;
            }
        }
    }

    sub keys {
        my $self  = shift;
        my @array = $self->get_array;
        my @keys;
        for ( my $i = 0 ; $i < @array ; $i += 2 ) {
            push @keys, $array[$i];
        }
        return wantarray ? @keys : \@keys;
    }

    sub values {
        my $self  = shift;
        my @array = $self->get_array;
        my @values;
        for ( my $i = 1 ; $i < @array ; $i += 2 ) {
            push @values, $array[$i];
        }
        return wantarray ? @values : \@values;
    }

    sub each {
        my $self  = shift;
        my $ident = ident $self;
        my $index = $current_index_for{$ident} || 0;
        my @array = $self->get_array;
        if ( $index >= @array ) {
            $self->reset_each;
            return;
        }
        my ( $key, $value ) = @array[ $index, $index + 1 ];
        $current_index_for{$ident} += 2;
        return ( $key, $value );
    }
    *kv = \&each;

    sub reset_each { $current_index_for{ ident shift } = 0 }

    sub insert_before {
        my $self  = shift;
        my $key   = shift;
        my $index = $self->$_index($key);
        $self->$_insert( $key, 'before', $index, @_ );
    }

    sub insert_after {
        my $self  = shift;
        my $key   = shift;
        my $index = $self->$_index($key) + 2;
        $self->$_insert( $key, 'after', $index, @_ );
    }

    sub delete {
        my $self = shift;
        my $key  = $self->$_actual_key(shift);
        my @value;

        if ( $self->exists($key) ) {
            my $ident = ident $self;
            my $index = $self->$_index($key);
            delete $index_of{$ident}{$key};
            my ( undef, $value ) = splice @{ $array_for{$ident} }, $index, 2;
            push @value, $value;
            foreach my $curr_key ( CORE::keys %{ $index_of{$ident} } ) {
                if ( $index_of{$ident}{$curr_key} >= $index ) {
                    $index_of{$ident}{$curr_key} -= 2;
                }
            }
        }
        if (@_) {
            push @value, $self->delete(@_);
        }
        return wantarray ? @value : \@value;
    }

    sub exists {
        my ( $self, $key ) = @_;
        $key = $self->$_actual_key($key);
        return unless defined $key;

        #use Data::Dumper::Simple;
        #main::diag(Dumper($_[1], $key, %index_of)) if $ENV{DEBUG};
        return exists $index_of{ ident $self}{$key};
    }

    sub get {
        my ( $self, $key ) = @_;
        $key = $self->$_actual_key($key);
        return unless defined $key;
        return $self->exists($key)
          ? $array_for{ ident $self}[ $self->$_index($key) + 1 ]
          : ();
    }

    sub put {
        my ( $self, $key, $value ) = @_;
        my $ident = ident $self;
        $key = $self->$_actual_key($key);
        my $index = $self->$_index($key);
        $index_of{$ident}{$key}          = $index;
        $array_for{$ident}[$index]       = $key;
        $array_for{$ident}[ $index + 1 ] = $value;
        return $self;
    }

    sub _croak {
        my ( $proto, $message ) = @_;
        require Carp;
        Carp::croak($message);
    }

    sub get_array {
        my $self = shift;
        return
          wantarray ? @{ $array_for{ ident $self} } : $array_for{ ident $self};
    }
}

=head1 NAME

Array::AsHash - Treat arrays as a hashes, even if you need references for keys.

=head1 VERSION

Version 0.01

=head1 SYNOPSIS

    use Array::AsHash;

    my $array = Array::AsHash->new({
        array => \@array,
        clone => 1, # optional
    });
   
    while (my ($key, $value) = $array->each) {
        # sorted
        ...
    }

    my $value = $array->get($key);
    $array->put($key, $value);
    
    if ( $array->exists($key) ) {
        ...
    }

    $array->delete($key);

=head1 DESCRIPTION

Sometimes we have an array that we need to treat as a hash.  We need the data
ordered, but we don't use an ordered hash because it's already an array.  Or
it's just quick 'n easy to run over array elements two at a time.  

Because we take a reference to what you pass to the constructor (or use the
reference you pass), you may wish to copy your data if you do not want it
altered (the data are not altered except through the publicly available methods
of this class).  

Also, we keep the array an array.  This does mean that things might get a bit
slow if you have a large array, but it also means that you can use references
(including objects) as "keys".  For the general case of fetching and storing
items, however, you'll find the operations are C<O(1)>.  Behaviors which can
affect the entire array are often C<O(N)>.

=head1 EXPORT

The C<each()> and C<exists()> methods may be exported on demand.  See their
documentation for details.
None.

=head1 METHODS

=head2 new

 my $array = Array::AsHash->new( { array => \@array } );

Returns a new C<Array::AsHash> object.  If an array is passed to C<new>, it
must contain an even number of elements.  This array will be treated as a set
of key/value pairs:

 my @array = qw/foo bar one 1/;
 my $array = Array::AsHash->new({array => \@array});
 print $array->get('foo'); # prints 'bar'

Note that the array is stored internally and changes to the C<Array::AsHash>
object will change the array that was passed to the constructor as an argument.
If you do not wish this behavior, clone the array beforehand or ask the
constructor to clone it for you.

 my $array = Array::AsHash->new(
    {
        array => \@array,
        clone => 1, # optional
    }
 );

Of course, you can simply create an empty object and it will still work.

 my $array = Array::AsHash->new;
 $array->put('foo', 'bar');

=head2 keys

  my @keys = $array->keys;

Returns the "keys" of the array.  Returns an array reference in scalar context.

=head2 values

  my @values = $array->values;

Returns the "values" of the array.  Returns an array reference in scalar context.

=head2 delete

 my @values = $array->delete(@keys);

Deletes the given C<@keys> from the array.  Returns the values of the deleted keys.
Non-existing keys will be silently ignored.

=head2 each

 while ( my ($key, $value) = $array->each ) {
    # iterate over array like a hash
 }

Lazily returns keys and values, in order, until no more are left.  Every time
each() is called, will automatically increment to the next key value pair.  If
no more key/value pairs are left, will reset itself to the first key/value
pair.

As with a regular hash, if you do not iterate over all of the data, the internal
pointer will be pointing at the I<next> key/value pair to be returned.  If you need
to restart from the beginning, call the C<reset_each> method.

=head2 kv

 while ( my ($key, $value) = $array->kv ) {
    # iterate over array like a hash
 }

C<kv> is a synonym for C<each>.

=head2 reset_each

 $array->reset_each;

Resets the C<each> iterator to point to the beginning of the array.

=head2 exists

 if ($array->exists($thing)) { ... }

Returns true if the given C<$thing> exists in the array as a I<key>.

=head2 get_array

 my @array = $array->get_array;

Returns the array in the object.  Returns an array reference in scalar context.

=head2 get

 my $value = $array->get($key);

Returns the value associated with a given key, if any.

=head2 put

 $array->put($key, $value);

Sets the value for a given C<$key>.  If the key does not already exist, this
pushes two elements onto the end of the array.

=head2 insert_before

 $array->insert_before($key, @kv_pairs);

This method takes a given C<$key> and attempts to insert an even-sized list of
key/value pairs I<before> the given key.  Will croak if C<$key> does not exist
or if C<@kv_pairs> is not an even-sized list.

 $array->insert_before($key, this => 'that', one => 1);

=head2 insert_after

 $array->insert_after($key, @kv_pairs);

This method takes a given C<$key> and attempts to insert an even-sized list of
key/value pairs I<after> the given key.  Will croak if C<$key> does not exist
or if C<@kv_pairs> is not an even-sized list.

 $array->insert_after($key, this => 'that', one => 1);

=head1 AUTHOR

Curtis "Ovid" Poe, C<< <ovid@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-array-ashash@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Array-AsHash>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SEE ALSO

L<Clone>, L<Tie::IxHash> L<Class::Std> (how this module is implemented).

=head1 COPYRIGHT & LICENSE

Copyright 2005 Curtis, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;    # End of Array::AsHash
