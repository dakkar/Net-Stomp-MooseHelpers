package Net::Stomp::MooseHelpers::TraceOnly;
use Moose::Role;
use Net::Stomp::Frame;
use namespace::autoclean;

# ABSTRACT: role to replace the Net::Stomp connection with tracing code

with 'Net::Stomp::MooseHelpers::TracerRole';

=head1 SYNOPSIS

  package MyThing;
  use Moose;with 'Net::Stomp::MooseHelpers::CanConnect';
  with 'Net::Stomp::MooseHelpers::TraceOnly';

  $self->trace_basedir('/tmp/stomp_dumpdir');

B<NOTE>: a C<CanConnect> consuming this role will never talk to the
network, and will C<die> if asked to receive frames.

=head1 DESCRIPTION

This module I<replaces> the connection object provided by
L<Net::Stomp::MooseHelpers::CanConnect> so that it writes to disk
every outgoing frame, I<without actually talking to the network>. It
will also C<die> if the connection is asked to receive frames.

The frames are written as they would be "on the wire" (no encoding
conversion happens), one file per frame. Each frame is written into a
directory under L</trace_basedir> with a name derived from the frame
destination.

=attr C<trace_basedir>

The directory under which frames will be dumped. Accepts strings and
L<Path::Class::Dir> objects. If it's not specified, every frame will
generate a warning.

=cut

sub trace { 1 }

around '_build_connection' => sub {
    my ($orig,$self,@etc) = @_;

    my $conn = Net::Stomp::MooseHelpers::TraceOnly::Connection->new({
        _tracing_object => $self,
    });
    return $conn;
};

package Net::Stomp::MooseHelpers::TraceOnly::Connection;{
use Moose;
use Carp;

has _tracing_object => ( is => 'rw' );

sub connect { return 1 }
sub subscribe { return 1 }
sub unsubscribe { return 1 }
sub ack { return 1 }

sub receive_frame {
    croak "This a Net::Stomp::MooseHelpers::TraceOnly::Connection, we don't talk to the network";
}

sub send_frame {
    my ($self,$frame,@etc) = @_;

    if (my $o=$self->_tracing_object) {
        $o->_save_frame($frame,'send');
    }

    return;
};

# this is from Net::Stomp
sub send {
    my ($self,$conf) = @_;

    my $body = $conf->{body};
    delete $conf->{body};
    my $frame = Net::Stomp::Frame->new({
        command => 'SEND', headers => $conf, body => $body,
    });
    $self->send_frame($frame);
}

__PACKAGE__->meta->make_immutable;
}


=begin Pod::Coverage

trace

connect
subscribe
unsubscribe
ack
receive_frame
send_frame
send

=end Pod::Coverage

1;
