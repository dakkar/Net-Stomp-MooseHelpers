package Net::Stomp::MooseHelpers::TraceStomp;
use Moose::Role;
use Moose::Util 'apply_all_roles';
use namespace::autoclean;

# ABSTRACT: role to wrap the Net::Stomp connection in tracing code

with 'Net::Stomp::MooseHelpers::TracerRole';

=head1 SYNOPSIS

  package MyThing;
  use Moose;with 'Net::Stomp::MooseHelpers::CanConnect';
  with 'Net::Stomp::MooseHelpers::TraceStomp';

  $self->trace_basedir('/tmp/stomp_dumpdir');
  $self->trace(1);

=head1 DESCRIPTION

This module wraps the connection object provided by
L<Net::Stomp::MooseHelpers::CanConnect> and writes to disk every
outgoing and incoming frame.

The frames are written as they are "on the wire" (no encoding
conversion happens), one file per frame. Each frame is written into a
directory under L</trace_basedir> with a name derived from the frame
destination.

=attr C<trace_basedir>

The directory under which frames will be dumped. Accepts strings and
L<Path::Class::Dir> objects. If it's not specified and you enable
L</trace>, every frame will generate a warning.

=attr C<trace>

Boolean attribute to enable or disable tracing / dumping of frames. If
you enable tracing but don't set L</trace_basedir>, every frame will
generate a warning.

=cut

around '_build_connection' => sub {
    my ($orig,$self,@etc) = @_;

    my $conn = $self->$orig(@etc);
    apply_all_roles($conn,'Net::Stomp::MooseHelpers::TraceStomp::ConnWrapper');
    $conn->_tracing_object($self);
    return $conn;
};

{
package Net::Stomp::MooseHelpers::TraceStomp::ConnWrapper;
use Moose::Role;

has _tracing_object => ( is => 'rw' );

before send_frame => sub {
    my ($self,$frame,@etc) = @_;

    if (my $o=$self->_tracing_object) {
        $o->_save_frame($frame,'send');
    }

    return;
};

around receive_frame => sub {
    my ($orig,$self,@etc) = @_;

    my $frame = $self->$orig(@etc);

    if (my $o=$self->_tracing_object) {
        $o->_save_frame($frame,'recv');
    }

    return $frame;
};
}

1;
