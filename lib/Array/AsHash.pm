package Array::AsHash;

use warnings;
use strict;
use Class::Std;
use Clone ();
use Scalar::Util qw(refaddr);

our $VERSION = '0.11';

my $_bool;

BEGIN {
    $_bool = sub {
        my $self = CORE::shift;
        return $self->acount;
    };
}

use overload
  bool     => $_bool,
  fallback => 1;

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
        push @{ $array_for{$ident} }, @_, @tail;
        my %seen = @_;
        foreach my $curr_key ( CORE::keys %{ $index_of{$ident} } ) {
            if ( $index_of{$ident}{$curr_key} >= $index
                && !exists $seen{$curr_key} )
            {
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

    sub clone {
        my $self = CORE::shift;
        return ( ref $self )->new(
            {
                array => scalar $self->get_array,
                clone => 1,
            }
        );
    }

    sub unshift {
        my $self     = CORE::shift;
        my @kv_pairs = @_;
        if ( @kv_pairs % 2 ) {
            $self->_croak("Arguments to unshift() must be an even-sized list");
        }
        my $ident = ident $self;
        foreach my $curr_key ( CORE::keys %{ $index_of{$ident} } ) {
            $index_of{$ident}{$curr_key} += @kv_pairs;
        }
        for ( my $i = 0 ; $i < @kv_pairs ; $i += 2 ) {
            my ( $key, $value ) = @kv_pairs[ $i, $i + 1 ];
            if ( $self->exists($key) ) {
                $self->_croak("Cannot unshift an existing key ($key)");
            }
            $index_of{$ident}{$key} = $i;
        }
        unshift @{ $array_for{$ident} }, @kv_pairs;
    }

    sub push {
        my $self     = CORE::shift;
        my @kv_pairs = @_;
        if ( @kv_pairs % 2 ) {
            $self->_croak("Arguments to unshift() must be an even-sized list");
        }
        my $ident = ident $self;
        my @array = $self->get_array;
        for ( my $i = 0 ; $i < @kv_pairs ; $i += 2 ) {
            my ( $key, $value ) = @kv_pairs[ $i, $i + 1 ];
            if ( $self->exists($key) ) {
                $self->_croak("Cannot unshift an existing key ($key)");
            }
            $index_of{$ident}{$key} = @array + $i;
        }
        CORE::push @{ $array_for{ ident $self} }, @kv_pairs;
    }

    sub pop {
        my $self = shift;
        return unless $self;
        my $ident = ident $self;
        my ( $key, $value ) = splice @{ $array_for{$ident} }, -2;
        delete $index_of{$ident}{$key};
        return wantarray ? ( $key, $value ) : [ $key, $value ];
    }

    sub shift {
        my $self = CORE::shift;
        return unless $self;
        my $ident = ident $self;
        foreach my $curr_key ( CORE::keys %{ $index_of{$ident} } ) {
            $index_of{$ident}{$curr_key} -= 2;
        }
        my ( $key, $value ) = splice @{ $array_for{$ident} }, 0, 2;
        delete $index_of{$ident}{$key};
        return wantarray ? ( $key, $value ) : [ $key, $value ];
    }

    sub hcount {
        my $self  = CORE::shift;
        my $count = $self->acount;
        return $count / 2;
    }

    sub acount {
        my $self  = CORE::shift;
        my @array = $self->get_array;
        return scalar @array;
    }

    sub hindex {
        my $self  = CORE::shift;
        my $index = $self->aindex(CORE::shift);
        return defined $index ? $index / 2 : ();
    }

    sub aindex {
        my $self = CORE::shift;
        my $key  = $self->$_actual_key(CORE::shift);
        return unless $self->exists($key);
        return $self->$_index($key);
    }

    sub keys {
        my $self  = CORE::shift;
        my @array = $self->get_array;
        my @keys;
        for ( my $i = 0 ; $i < @array ; $i += 2 ) {
            CORE::push @keys, $array[$i];
        }
        return wantarray ? @keys : \@keys;
    }

    sub values {
        my $self  = CORE::shift;
        my @array = $self->get_array;
        my @values;
        for ( my $i = 1 ; $i < @array ; $i += 2 ) {
            CORE::push @values, $array[$i];
        }
        return wantarray ? @values : \@values;
    }

    sub first {
        my $self  = CORE::shift;
        my $index = $current_index_for{ ident $self};
        return defined $index && 2 == $index;
    }

    sub last {
        my $self  = CORE::shift;
        my $index = $current_index_for{ ident $self};
        return defined $index && $self->acount == $index;
    }

    sub each {
        my $self  = CORE::shift;
        my $ident = ident $self;
        my $index = $current_index_for{$ident} || 0;
        my @array = $self->get_array;
        if ( $index >= @array ) {
            $self->reset_each;
            return;
        }
        my ( $key, $value ) = @array[ $index, $index + 1 ];
        no warnings 'uninitialized';
        $current_index_for{$ident} += 2;
        return ( $key, $value );
    }
    *kv = \&each;

    sub reset_each { $current_index_for{ ident CORE::shift } = undef }

    sub insert_before {
        my $self  = CORE::shift;
        my $key   = CORE::shift;
        my $index = $self->$_index($key);
        $self->$_insert( $key, 'before', $index, @_ );
    }

    sub insert_after {
        my $self  = CORE::shift;
        my $key   = CORE::shift;
        my $index = $self->$_index($key) + 2;
        $self->$_insert( $key, 'after', $index, @_ );
    }

    sub delete {
        my $self     = CORE::shift;
        my $num_args = @_;
        my $key      = $self->$_actual_key(CORE::shift);
        my @value;

        if ( $self->exists($key) ) {
            my $ident = ident $self;
            my $index = $self->$_index($key);
            delete $index_of{$ident}{$key};
            my ( undef, $value ) = splice @{ $array_for{$ident} }, $index, 2;
            CORE::push @value, $value;
            foreach my $curr_key ( CORE::keys %{ $index_of{$ident} } ) {
                if ( $index_of{$ident}{$curr_key} >= $index ) {
                    $index_of{$ident}{$curr_key} -= 2;
                }
            }
        }
        if (@_) {
            CORE::push @value, $self->delete(@_);
        }
        return wantarray  ? @value
          : $num_args > 1 ? \@value
          : $value[0];
    }

    sub exists {
        my ( $self, $key ) = @_;
        $key = $self->$_actual_key($key);
        return unless defined $key;

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

    sub get_pairs {
        my ( $self, @keys ) = @_;

        my @pairs;
        foreach my $key (@keys) {
            next unless $self->exists($key);
            CORE::push @pairs, $key, $self->get($key);
        }
        return wantarray ? @pairs : \@pairs;
    }

    sub default {
        my ( $self, @pairs ) = @_;
        if ( @pairs % 2 ) {
            $self->_croak("Arguments to default must be an even-sized list");
        }
        for ( my $i = 0 ; $i < @pairs ; $i += 2 ) {
            my ( $k, $v ) = @pairs[ $i, $i + 1 ];
            next if $self->exists($k);
            $self->put( $k, $v );
        }
        return $self;
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
        my $self = CORE::shift;
        return
          wantarray ? @{ $array_for{ ident $self} } : $array_for{ ident $self};
    }
}

1;
__END__

=head1 NAME

Array::AsHash - Treat arrays as a hashes, even if you need references for keys.

=head1 VERSION

Version 0.11

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

None.

=head1 OVERLOADING

Note that the boolean value of the object has been overloaded.  An empty array
object will report false in boolean context:

 my $array = Array::AsHash->new;
 if ($array) {
   # never gets here
 }

=head1 CONSTRUCTOR

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

Internally, we use the L<Clone> module to clone the array.  This will not
always work if you are attempting to clone objects (inside-out objects are
particularly difficult to clone).  If you encounter this, you will need to
clone the array yourself.  Most of the time, however, it should work.

Of course, you can simply create an empty object and it will still work.

 my $array = Array::AsHash->new;
 $array->put('foo', 'bar');

=head1 HASH-LIKE METHODS

The following methods allow one to treat an L<Array::AsHash> object
more-or-less like a hash.

=head2 keys

  my @keys = $array->keys;

Returns the "keys" of the array.  Returns an array reference in scalar context.

=head2 values

  my @values = $array->values;

Returns the "values" of the array.  Returns an array reference in scalar context.

=head2 delete

 my @values = $array->delete(@keys);

Deletes the given C<@keys> from the array.  Returns the values of the deleted keys.
In scalar context, returns an array reference of the keys.

As a "common-case" optimization, if only one key is requested for deletion,
deletion in scalar context will result in the one value (if any) being
returned instead of an array reference.

 my $deleted = $array->delete($key); # returns the value for $key
 my $deleted = $array->delete($key1, $key2); # returns an array reference

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

=head2 first

 if ($array->first) { ... }

Returns true if we are iterating over the array with C<each()> and we are on the
first iteration.

=head2 last

 if ($array->last) { ... }

Returns true if we are iterating over the array with C<each()> and we are on the
last iteration.

=head2 reset_each

 $array->reset_each;

Resets the C<each> iterator to point to the beginning of the array.

=head2 exists

 if ($array->exists($thing)) { ... }

Returns true if the given C<$thing> exists in the array as a I<key>.

=head2 get

 my $value = $array->get($key);

Returns the value associated with a given key, if any.

=head2 put

 $array->put($key, $value);

Sets the value for a given C<$key>.  If the key does not already exist, this
pushes two elements onto the end of the array.

=head2 get_pairs

 my $array = Array::AsHash->new({array => [qw/foo bar one 1 two 2/]});
 my @pairs = $array->get_pairs(qw/foo two/); # @pairs = (foo => 'bar', two => 2);
 my $pairs = $array->get_pairs(qw/xxx two/); # $pairs = [ two => 2 ];

C<get_pairs> returns an even-size list of key/value pairs.  It silently discards
non-existent keys.  In scalar context it returns an array reference.

This method is useful for reordering an array.

 my $array  = Array::AsHash->new({array => [qw/foo bar two 2 one 1/]});
 my @pairs  = $array->get_pairs(sort $array->keys);
 my $sorted = Array::AsHash->new({array => \@pairs});

=head2 default

 $array->default(@kv_pairs);

Given an even-sized list of key/value pairs, each key which does not already exist
in the array will be set to the corresponding value.

=head2 hcount

 my $pair_count = $array->hcount;

Returns the number of key/value pairs in the array.

=head2 hindex

 my $index = $array->hindex('foo');

Returns the I<hash index> of a given key, if the keys exists.  The hash index
is the array index divided by 2.  In other words, it's the index of the
key/value pair.

=head1 ARRAY-LIKE METHODS

The following methods allow one to treat a L<Array::AsHash> object more-or-less
like an array.

=head2 shift

 my ($key, $value) = $array->shift;

Removes the first key/value pair, if any, from the array and returns it.
Returns an array reference in scalar context.

=head2 pop

 my ($key, $value) = $array->pop;

Removes the last key/value pair, if any, from the array and returns it.
Returns an array reference in scalar context.

=head2 unshift

 $array->unshift(@kv_pairs);

Takes an even-sized list of key/value pairs and attempts to unshift them
onto the front of the array.  Will croak if any of the keys already exists.

=head2 push

 $array->unshift(@kv_pairs);

Takes an even-sized list of key/value pairs and attempts to push them
onto the end of the array.  Will croak if any of the keys already exists.

=head2 insert_before

 $array->insert_before($key, @kv_pairs);

Similar to splice(), this method takes a given C<$key> and attempts to insert
an even-sized list of key/value pairs I<before> the given key.  Will croak if
C<$key> does not exist or if C<@kv_pairs> is not an even-sized list.

 $array->insert_before($key, this => 'that', one => 1);

=head2 insert_after

 $array->insert_after($key, @kv_pairs);

This method takes a given C<$key> and attempts to insert an even-sized list of
key/value pairs I<after> the given key.  Will croak if C<$key> does not exist
or if C<@kv_pairs> is not an even-sized list.

 $array->insert_after($key, this => 'that', one => 1);

=head2 acount

 my $count = $array->acount;

Returns the number of elements in the array.

=head2 aindex

 my $count = $array->aindex('foo');

Returns the I<aray index> of a given key, if the keys exists.

=head1 OTHER METHODS

The following methods really don't match the aforementioned categories.

=head2 get_array

 my @array = $array->get_array;

Returns the array in the object.  Returns an array reference in scalar context.
Note that altering the returned array can affect the internal state of the
L<Array::AsHash> object and will probably break it.  You should usually only
get the underlying array as the last action before disposing of the object.
Otherwise, attempt to clone the array with the C<clone> method and use I<that>
array.

 my @array = $array->clone->get_array;

=head2 clone

 my $array2 = $array->clone;

Attempts to clone (deep copy) and return a new object.  This may fail if the 
array contains objects which L<Clone> cannot handle.

=head1 WHY NOT A TIED HASH?

You may very well find that a tied hash fits your purposes better and there's
certainly nothing wrong with them.  Personally, I do not use tied variables
unless absolutely necessary because ties are frequently buggy, they tend to be
slow and they take a perfectly ordinary variable and make it hard to maintain.
Return a tied variable and some poor maintenance programmer is just going to
see an hash and they'll get awfully confused when their code isn't doing quite
what they expect.

Of course, this module provides a richer interface than a tied hash would, but
that's just another benefit of using a proper class instead of a tie.

=head1 AUTHOR

Curtis "Ovid" Poe, C<< <ovid@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-array-ashash@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Array-AsHash>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SEE ALSO

L<Clone>, L<Tie::IxHash>, L<Class::Std> (how this module is implemented).

=head1 COPYRIGHT & LICENSE

Copyright 2005 Curtis "Ovid" Poe, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut
