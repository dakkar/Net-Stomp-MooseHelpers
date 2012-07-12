package Net::Stomp::MooseHelpers::TracerRole;
use Moose::Role;
use MooseX::Types::Path::Class;
use Time::HiRes ();
use File::Temp ();
use namespace::autoclean;

# ABSTRACT: role to dump Net::Stomp frames to disk

=head1 DESCRIPTION

This role is not to be used directly, look at
L<Net::Stomp::MooseHelpers::TraceStomp> and
L<Net::Stomp::MooseHelpers::TraceOnly>.

This role provides attributes and methods to write to disk every
outgoing and incoming STOMP frame.

The frames are written as they are "on the wire" (no encoding
conversion happens), one file per frame. Each frame is written into a
directory under L</trace_basedir> with a name derived from the frame
destination.

=attr C<trace_basedir>

The directory under which frames will be dumped. Accepts strings and
L<Path::Class::Dir> objects. If it's not specified and you enable
L</trace>, every frame will generate a warning.

=cut

has trace_basedir => (
    is => 'rw',
    isa => 'Path::Class::Dir',
    coerce => 1,
);

=attr C<trace>

Boolean attribute to enable or disable tracing / dumping of frames. If
you enable tracing but don't set L</trace_basedir>, every frame will
generate a warning.

=cut

has trace => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);

=method C<_dirname_from_destination>

Generate a directory name from a frame destination. By default,
replaces every sequence of non-word characters with C<'_'>.

=cut

sub _dirname_from_destination {
    my ($self,$destination) = @_;

    return '' unless defined $destination;

    my $ret = $destination;
    $ret =~ s{^(queue|topic)/}{/$1/};
    $ret =~ s/\W+/_/g;
    return $ret;
}

=method C<_filename_from_frame>

Returns a filehandle / filename pair for the file to write the frame
into. Avoids duplicates by using L<Time::HiRes>'s C<time> as a
starting filename, and L<File::Temp>.

=cut

sub _filename_from_frame {
    my ($self,$frame,$direction) = @_;

    my $base = sprintf '%0.5f',Time::HiRes::time();
    my $dir = $self->trace_basedir->subdir(
        $self->_dirname_from_destination($frame->headers->{destination})
    );
    $dir->mkpath;

    return File::Temp::tempfile("${base}-${direction}-XXXX",
                                DIR => $dir->stringify);
}

sub _save_frame {
    my ($self,$frame,$direction) = @_;

    return unless $self->trace;
    return unless $frame;
    $direction||='';

    if (!$self->trace_basedir) {
        warn "trace_basedir not set, but tracing requested, ignoring\n";
        return;
    }

    my ($fh,$filename) = $self->_filename_from_frame($frame,$direction);
    binmode $fh;
    syswrite $fh,$frame->as_string;
    close $fh;
    return;
}

1;
