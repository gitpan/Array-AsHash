#!/usr/bin/perl
# '$Id: 10dump.t,v 1.6 2004/08/03 04:52:28 ovid Exp $';
use warnings;
use strict;

use Test::More tests => 96;
#use Test::More qw/no_plan/;

my $CLASS;

BEGIN {
    chdir 't' if -d 't';
    unshift @INC => '../lib', 'lib';
    require Foo;
    require Bar;
    $CLASS = 'Array::AsHash';
    use_ok($CLASS) or die;
}

can_ok $CLASS, 'new';
eval { $CLASS->new( { array => {} } ) };
like $@, qr/Argument to new\(\) must be an array reference/,
  '... and passing anything but an aref to new() should croak';
eval { $CLASS->new( { array => [ 1, 2, 3 ] } ) };
like $@, qr/Uneven number of keys in array/,
  '... and passing an uneven number of array elements to new() should croak';

ok defined(my $array = $CLASS->new), 'Calling new() without arguments should succeed';
isa_ok $array, $CLASS, '... and the object it returns';

can_ok $array, 'get';
ok !defined $array->get('foo'), '... and non-existent keys should return undef';
ok !( my @foo = $array->get('foo') ),
  '... and should also work in list context';

can_ok $array, 'exists';
ok !$array->exists('foo'), '... and non-existent keys should return false';

can_ok $array, 'put';
ok $array->put( foo => 'bar' ), '... and storing a new value should succeed';
ok $array->exists('foo'), '... and the key should exist in the array';
is $array->get('foo'),    'bar', '... and getting a value should succceed';

can_ok $array, 'get_array';
is_deeply scalar $array->get_array, [ foo => 'bar' ],
  '... and in scalar context it should return an array reference';

is_deeply [ $array->get_array ], [ foo => 'bar' ],
  '... and in list context it should return a list';

can_ok $array, 'keys';
my @keys = $array->keys;
is_deeply \@keys, ['foo'],
  '... calling it in list context should return a list of keys';
my $keys = $array->keys;
is_deeply $keys, ['foo'],
  '... calling it in scalar context should return an array ref';

can_ok $array, 'values';
my @values = $array->values;
is_deeply \@values, ['bar'],
  '... calling it in list context should return a list of values';
my $values = $array->values;
is_deeply $values, ['bar'],
  '... calling it in scalar context should return an array ref';

# test uncloned arrays

{
    my @array = qw/foo bar this that one 1/;
    ok $array = $CLASS->new( { array => \@array } ),
      'We should be able to create an object with an existing array';
    isa_ok $array, $CLASS, '... and the object it returns';
    is_deeply scalar $array->keys, [qw/foo this one/],
      '... and the keys should be correct';
    is_deeply scalar $array->values, [qw/bar that 1/],
      '... as should the values';
    $array->put( 'foo', 'oof' );
    is $array[1], $array->get('foo'),
      '... and uncloned arrays should affect their parents';
}

# test delete

{
    my @array = qw/foo bar this that one 1/;
    $array = $CLASS->new( { array => \@array, clone => 1 } ), can_ok $array,
      'delete';
    ok my @values = $array->delete('this'), '... and deleting a key should work';
    is_deeply \@values, ['that'],
      '... and it should return the value we deleted';

    is_deeply scalar $array->keys, [qw/foo one/],
      '... and our remaining keys should be correct';
    is_deeply scalar $array->values, [qw/bar 1/],
      '... and our remaining values should be correct';
    is $array->get('foo'), 'bar',
      '... and getting items before the deleted key should work';
    is $array->get('one'), 1,
      '... and getting items after the deleted key should work';

    $array->insert_after('foo', 'this', 'that', 'xxx', 'yyy');
    is $array->get('xxx'), 'yyy', 'We should be able to fetch new values from arrays with deletions';
    is $array->get('foo'), 'bar',
      '... and getting items before the inserted keys should work';
    is $array->get('one'), 1,
      '... and getting items after the inserted keys should work';
    ok @values = $array->delete('this', 'xxx'), '... and deleting multiple keys should work';
    is_deeply \@values, ['that', 'yyy'],
      '... and it should return the values we deleted';
    
    is_deeply scalar $array->keys, [qw/foo one/],
      '... and our remaining keys should be correct';
    is_deeply scalar $array->values, [qw/bar 1/],
      '... and our remaining values should be correct';
    is $array->get('foo'), 'bar',
      '... and getting items before the deleted key should work';
    is $array->get('one'), 1,
      '... and getting items after the deleted key should work';

    ok ! (@values = $array->delete('no_such_key')),
        'Trying to delete a non-existent key should silently fail';
    is_deeply scalar $array->keys, [qw/foo one/],
      '... and our remaining keys should be correct';
    is_deeply scalar $array->values, [qw/bar 1/],
      '... and our remaining values should be correct';
    ok @values = $array->delete('no_such_key', 'one'),
        'Trying to delete a non-existent key and an existing key should work';
    is_deeply \@values, [1],
        '... and return the correct value(s)';
    is_deeply scalar $array->keys, [qw/foo/],
      '... and our remaining keys should be correct';
    is_deeply scalar $array->values, [qw/bar/],
      '... and our remaining values should be correct';
}

# test contextual delete

{
    my @array = qw/foo bar this that one 1/;
    my $array = $CLASS->new( { array => \@array } );
    my $value = $array->delete('foo');
    is $value, 'bar', 'Scalar delete of a single key should return the value';
    $value = $array->delete('this', 'one');
    is_deeply $value, ['that', 1],
        '... but deleteting multiple keys in scalar context should return an aref';
}

# test each()

{
    my @array = qw/foo bar this that one 1/;
    $array = $CLASS->new( { array => \@array, clone => 1 } );
    can_ok $array, 'each';

    my $count        = @array / 2;
    my $actual_count = 0;
    while ( my ( $k, $v ) = $array->each ) {
        my ( $k1, $v1 ) = splice @array, 0, 2;
        is $k, $k1, '... and the key should be the same';
        is $v, $v1, '... and the value should be the same';
        $actual_count++;
        last if $actual_count > $count;
    }
    is $actual_count, $count,
      '... and each() should return the correct number of items';

    @array = qw/foo bar this that one 1/;
    my ( $k, $v ) = $array->each;
    is_deeply [ $k, $v ], [ @array[ 0, 1 ] ],
      'After each() is finished, it should be automatically reset';

    can_ok $array, 'reset_each';
    $array->reset_each;
    ( $k, $v ) = $array->each;
    is_deeply [ $k, $v ], [ @array[ 0, 1 ] ],
      '... and reset_each() should reset the each() iterator';
}

# test kv

{
    my @array = qw/foo bar this that one 1/;
    $array = $CLASS->new( { array => \@array, clone => 1 } );
    can_ok $array, 'kv';

    my $count        = @array / 2;
    my $actual_count = 0;
    while ( my ( $k, $v ) = $array->kv ) {
        is_deeply [ $k, $v ], [ splice @array, 0, 2 ],
          '... and kv() should behave like each()';
        $actual_count++;
        last if $actual_count > $count;
    }
}

# tests objects as keys without clone

{
    my $foo = Foo->new;
    my $bar = Bar->new;

    my @array = ( $foo => 2, 3 => $bar );
    my $array = $CLASS->new( { array => \@array } );
    is $array->get($foo), 2, 'Using objects as keys should work';
    ok $array->exists($foo), '... and exists() should work properly';
    is $array->get(3)->package, 'Bar',
      '... and storing objects as values should work';
    ok $array->put( $foo, 17 ),
      '... and putting in a new value should work for objects';
    is $array->get($foo), 17, '... as should fetching the new value';
    ok $array->exists($foo), '... and exists() should work properly';

    my $foo2 = Foo->new;
    ok !$array->exists($foo2),
      'exists() should not report objects which do not exist';
    ok $array->put( $foo2, 'foo2' ),
      '... and putting a new object in should work';
    ok $array->exists($foo2), '... and it should now exist';
    is $array->get($foo2),    'foo2',
      '... and we should be able to fetch the value';
    ok $array->exists($foo), '... and exists() should work properly';
}

# tests objects as keys with clone

{
    my $foo   = Foo->new;
    my $bar   = Bar->new;
    my @array = ( $foo => 2, 3 => $bar );
    my $array = $CLASS->new( { array => \@array, clone => 1 } );
    is $array->get($foo), 2,
      'Using objects as keys should work even if we have cloned the array';
    ok $array->exists($foo), '... and exists() should work properly';
    is $array->get(3)->package, 'Bar',
      '... and storing objects as values should work';
    ok $array->put( $foo, 2 ),
      '... and putting in a new value should work for cloned objects';
    is $array->get($foo), 2, '... as should fetching the new value';
    ok $array->exists($foo), '... and exists() should work properly';

    my $foo2 = Foo->new;
    ok !$array->exists($foo2),
      'exists() should not report objects which do not exist';
    ok $array->put( $foo2, 'foo2' ),
      '... and putting a new object in should work';
    ok $array->exists($foo2), '... and it should now exist';
    is $array->get($foo2),    'foo2',
      '... and we should be able to fetch the value';
    ok $array->exists($foo), '... and exists() should work properly';
}

# test overloading

{
    my $array = $CLASS->new;
    ok ! $array, 'An empty array in boolean context should return false';
    $array->put(foo => 'bar');
    ok $array, '... but it should return true if we add elements to it';
}

# test cloning

{
    my $foo   = Foo->new;
    my $bar   = Bar->new;
    my @array = ( $foo => 2, 3 => $bar );
    my $array1 = $CLASS->new( { array => \@array, clone => 1 } );
    can_ok $array1, 'clone';
    ok my $array2 = $array1->clone,
        '... and trying to clone an array should succeed';
    is_deeply scalar $array2->get_array,
              scalar $array1->get_array,
              '... and the cloned array should have the same data';
}

