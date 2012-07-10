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
 with 'Net::Stomp::MooseHelpers::ReconnectOnFailure';

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

subtest 'simple' => sub {
    my $obj;
    is(exception {
        $obj = TestThing->new({
            servers => [ { hostname => 'test-host', port => 9999 } ],
            connect_headers => { foo => 'bar' },
        });

        $obj->connect;
    },undef,'can build & connect');
    ok($obj->is_connected,"it knows it's connected");

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
};

subtest 'on failure' => sub {
    no warnings 'redefine','once';
    my $fail_count=0;
    local *CallBacks::connect = sub {
        push @CallBacks::calls,['connect',@_];
        die "planned death" if $fail_count++ < 4;
        return 1;
    };

    my $obj;
    my @servers = (
        { hostname => 'test-host', port => 9999 },
        { hostname => 'test-host-2', port => 8888 },
    );
    $obj = TestThing->new({
        servers => \@servers,
        connect_retry_delay => 1,
    });

    @CallBacks::calls=();

    my @warns;
    is(exception {
        local $SIG{__WARN__} = sub {
            push @warns,@_;
        };
        $obj->reconnect_on_failure('connect');
    },undef,'can build & connect');
    ok($obj->is_connected,"it knows it's connected");

    my $connect_call = [
        'connect',
        ignore(),
        {},
    ];
    cmp_deeply(\@CallBacks::calls,
               [
                   map {
                       [
                           'new',
                           'CallBacks',
                           $_,
                       ],
                       $connect_call,
                   } @servers[0,1,0,1,0]
               ],
               'STOMP connect called with expected params')
        or note p @CallBacks::calls;

    cmp_deeply(\@warns,
               [ (re(qr{
                          \A
                          connection\ problems\ calling\ TestThing=.*?->connect\(\)
                          .*?
                          \bplanned\ death\b
                          .*?
                          at\ t/connect\.t
                  }xm)) x 4 ],
               'warns were issued correctly')
        or note p @warns;
};

done_testing();


