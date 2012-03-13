#!perl
use strict;
use warnings;
{package CallBacks;
 our @calls;
 sub new {
     my ($class,@args) = @_;
     push @calls,['new',$class,@args];
     bless {},$class;
 }
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
         return CallBacks->new(@_);
     } },
 );
}

package main;
use Test::More;
use Test::Fatal;
use Test::Deep;
use Data::Printer;

my $obj;
is(exception {
    $obj = TestThing->new({
        servers => [ { hostname => 'test-host', port => 9999 } ],
        connect_headers => { foo => 'bar' },
    });

    $obj->connect;
},undef,'can build & connect');

cmp_deeply(\@CallBacks::calls,
           [
               [
                   'new',
                   'CallBacks',
                   { hostname => 'test-host', port => 9999 },
               ],
               [
                   'connect',
                   ignore(),
                   { foo => 'bar' },
               ],
           ],
           'STOMP connect called with expected params')
    or note p @CallBacks::calls;

done_testing();


