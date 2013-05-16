#!perl
use strict;
use warnings;
use File::Temp 'tempdir';
use File::Find;
use Test::Deep;
use Net::Stomp::MooseHelpers::ReadTrace;

my $dir = tempdir(CLEANUP => ( $ENV{TEST_VERBOSE} ? 0 : 1 ));

{package TestThing;
 use Moose;
 with 'Net::Stomp::MooseHelpers::CanConnect';
 with 'Net::Stomp::MooseHelpers::ReconnectOnFailure';
 with 'Net::Stomp::MooseHelpers::TraceOnly';

 has '+trace_basedir' => ( default => $dir );
 has '+trace_permissions' => ( default => '0644' );
}

package main;
use Test::More;

my $obj = TestThing->new();
ok($obj->trace,'tracing is on by default with TraceOnly');
$obj->connect();
$obj->connection->send({
    type => 'foo',
    destination => '/topic/test',
    body => 'argh',
});
my @files;
find({
    wanted => sub {
        return unless -f;
        is((stat($_))[2]&07777,0644,"correct file permissions for $_");
        push @files,$_;
    },
    no_chdir => 1,
},$dir);
is(scalar(@files),1,'only one frame dumped');

my $reader = Net::Stomp::MooseHelpers::ReadTrace->new({
    trace_basedir => $dir,
});

my @frames = $reader->sorted_frames();
is(scalar(@frames),1,'only one frame read back');

cmp_deeply($frames[0],
           all(isa('Net::Stomp::Frame'),
               methods(
                   command => 'SEND',
                   headers => {
                       type => 'foo',
                       destination => '/topic/test',
                   },
                   body => 'argh',
               )),
           'correct contents');

done_testing();
