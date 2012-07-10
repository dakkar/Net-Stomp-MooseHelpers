package Net::Stomp::MooseHelpers::ReconnectOnFailure;
use Moose::Role;
use Net::Stomp::MooseHelpers::Exceptions;
use Carp;
use Try::Tiny;
use Time::HiRes 'sleep';
use namespace::autoclean;

# ABSTRACT: provide a reconnect-on-failure wrapper method

=head1 SYNOPSIS

  package MyThing;
  use Moose;
  with 'Net::Stomp::MooseHelpers::CanConnect',
       'Net::Stomp::MooseHelpers::ReconnectOnFailure';

  sub foo {
    my ($self) = @_;

    $self->reconnect_on_failure('connect');

    # do something
  }

=head1 DESCRIPTION

This role wraps the logic shown in the synopsis for
L<Net::Stomp::MooseHelpers::CanConnect> into a simple wrapper method.

Just call L</reconnect_on_failure> passing the method name (or a
coderef) and all the arguments. See below for details.

=attr C<connect_retry_delay>

How many seconds to wait between connection attempts. Defaults to 15.

=cut

 connect_retry_delay => (
    is => 'ro',
    isa => PositiveInt,
    default => 15,
);

requires 'connect';
requires 'clear_connection';
requires '_set_disconnected';

=method C<reconnect_on_failure>

  $self->reconnect_on_failure($method,@args);

C<$method> can be a method name or a coderef (anything that you'd
write just after C<< $self-> >>). C<@args> are passed untouched.

First of all, this calls C<< $self->connect() >>, then it calls C<<
$self->$method(@args) >>, returning whatever it returns (preserves
context).

If an exception is raised, warns about it, sleeps for
L</connect_retry_delay> seconds, then tries again.

=cut

sub reconnect_on_failure {
    my ($self,$method,@args) = @_;

    my $wantarray=wantarray;
    my @ret;my $done_it=0;

    while (!$done_it) {
        try {
            $self->connect;

            if ($wantarray) {
                @ret = $self->$method(@args);
            }
            elsif (defined $wantarray) {
                @ret = scalar $self->$method(@args);
            }
            else {
                $self->$method(@args);
            }
            $done_it = 1;
        }
        catch {
            my $err = $_;

            {
                local $"=', ';
                local $Carp::CarpInternal{'Try::Tiny'}=1;
                carp "connection problems calling ${self}->${method}(@args): $err; reconnecting";
            }
            $self->clear_connection;
            $self->_set_disconnected;
            sleep($self->connect_retry_delay);
        };
    }

    if ($wantarray) { return @ret }
    elsif (defined $wantarray) { return $ret[0] }
    else { return };
}

1;
