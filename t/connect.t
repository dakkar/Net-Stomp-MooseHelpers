#!perl
use strict;
use warnings;
{package CallBacks;
 our @calls;
 sub new { bless {},shift }
 for my $m (qw(connect
               subscribe unsubscribe
               receive_frame ack
               send send_frame)) {
     no strict 'refs';
     *$m=sub {
         push @calls,[$m,@_];
         return 1;
     };
 }
}
{package TestThing;
 use Moose;
 with 'Net::Stomp::MooseHelpers::CanConnect';

 has '+connection_builder' => (
     default => sub { sub {
         return CallBacks->new();
     } },
 );
}

package main;
use Test::More;
use Test::Fatal;
use Test::Deep;

my $obj;
is(exception {
    $obj = TestThing->new({
        servers => [ { hostname => 'test-host', port => 9999 } ],
        connect_headers => { foo => 'bar' },
    });

    $obj->connect;
},undef,'can build & connect');

cmp_deeply(\@CallBacks::calls,
           [ [
               'connect',
               ignore(),
               { foo => 'bar' },
           ] ],
           'STOMP connect called with expected params');

done_testing();


