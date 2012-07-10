package Net::Stomp::MooseHelpers::CanConnect;
use Moose::Role;
use Net::Stomp::MooseHelpers::Exceptions;
use Net::Stomp::MooseHelpers::Types qw(NetStompish
                                       ServerConfigList
                                       Headers
                                  );
use MooseX::Types::Common::Numeric qw(PositiveInt);
use MooseX::Types::Moose qw(CodeRef Bool);
use Try::Tiny;
use namespace::autoclean;

# ABSTRACT: role for classes that connect via Net::Stomp

=head1 SYNOPSIS

  package MyThing;
  use Moose; with 'Net::Stomp::MooseHelpers::CanConnect';
  use Try::Tiny;

  sub foo {
    my ($self) = @_;
    SERVER_LOOP:
    while (1) {
      my $exception;
      try {
        $self->connect();

        # do something

      } catch {
        $exception = $_;
      };
      if ($exception) {
        if (blessed $exception &&
            $exception->isa('Net::Stomp::MooseHelpers::Exceptions::Stomp')) {
          warn "connection died, trying next server\n";
          $self->clear_connection;
          next SERVER_LOOP;
        }
        die "unhandled exception $exception";
      }
    }
  }

=head1 DESCRIPTION

This role provides your class with a flexible way to connect to a
STOMP server. It supports connecting to one of many server in a
round-robin fashion.

=attr C<connection>

The connection to the STOMP server. It's built using the
L</connection_builder> (passing C<hostname> and C<port>), rotating
servers via L</next_server>. It's usually a L<Net::Stomp> object.

=cut

has connection => (
    is => 'rw',
    isa => NetStompish,
    lazy_build => 1,
);

=attr C<is_connected>

True if a call to C</connect>
succeded. L<Net::Stomp::MooseHelpers::ReconnectOnFailure> resets this
when reconnecting; you should not care much about it.

=cut

has is_connected => (
    traits => ['Bool'],
    is => 'ro',
    isa => Bool,
    default => 0,
    handles => {
      _set_disconnected => 'unset',
      _set_connected => 'set',
    },
);

=attr C<connection_builder>

Coderef that, given a hashref of options, returns a connection. The
default builder just passes the hashref to the constructor of
L<Net::Stomp>.

=cut

has connection_builder => (
    is => 'rw',
    isa => CodeRef,
    default => sub {
        sub {
            require Net::Stomp;
            my $ret = Net::Stomp->new($_[0]);
            return $ret;
        }
    },
);

sub _build_connection {
    my ($self) = @_;

    my $server = $self->next_server;

    return $self->connection_builder->({
        hostname => $server->{hostname},
        port => $server->{port},
    });
}

=attr C<servers>

A L<ServerConfigList|Net::Stomp::MooseHelpers::Types/ServerConfigList>,
that is, an arrayref of hashrefs, each of which describes how to
connect to a single server. Defaults to C<< [ { hostname =>
'localhost', port => 61613 } ] >>.

=cut

has servers => (
    is => 'ro',
    isa => ServerConfigList,
    lazy => 1,
    coerce => 1,
    builder => '_default_servers',
    traits => ['Array'],
    handles => {
        _shift_servers => 'shift',
        _push_servers => 'push',
    },
);
sub _default_servers {
    [ { hostname => 'localhost', port => 61613 } ]
};

=method C<next_server>

Rotates L</servers>, returning the element that was just moved from
the front to the back.

=cut

sub next_server {
    my ($self) = @_;

    my $ret = $self->_shift_servers;
    $self->_push_servers($ret);
    return $ret;
}

=method C<current_server>

Returns whatever the last call to L</next_server> returned, i.e. the
last element of L</servers>.

=cut

sub current_server {
    my ($self) = @_;

    return $self->servers->[-1];
}

=attr C<connect_headers>

Global setting for connection headers (passed to
L<Net::Stomp/connect>). Can be overridden by the C<connect_headers>
slot in each element of L</servers>. Defaults to the empty hashref.

=cut

has connect_headers => (
    is => 'ro',
    isa => Headers,
    lazy => 1,
    builder => '_default_connect_headers',
);
sub _default_connect_headers { { } }

=method C<connect>

Call the C<connect> method on L</connection>, passing the generic
L</connect_headers> and the per-server connect headers (from
L</current_server>, slot C<connect_headers>). Throws a
L<Net::Stomp::MooseHelpers::Exceptions::Stomp> if anything goes wrong.

If the L</connection> attribute is set, and L</is_connected>, returns
without doing anything.

=cut

sub connect {
    my ($self) = @_;

    return if $self->has_connection and $self->is_connected;

    try {
        # the connection will be created by the lazy builder
        $self->connection; # needed to make sure that 'current_server'
                           # is the right one
        my $server = $self->current_server;
        my %headers = (
            %{$self->connect_headers},
            %{$server->{connect_headers} || {}},
        );
        $self->connection->connect(\%headers);
        $self->_set_connected;
    } catch {
        Net::Stomp::MooseHelpers::Exceptions::Stomp->throw({
            stomp_error => $_
        });
    };
}

1;
