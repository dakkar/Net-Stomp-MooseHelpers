package Net::Stomp::MooseHelpers::TracerRole;
{
  $Net::Stomp::MooseHelpers::TracerRole::VERSION = '1.0';
}
{
  $Net::Stomp::MooseHelpers::TracerRole::DIST = 'Net-Stomp-MooseHelpers';
}
use Moose::Role;
use MooseX::Types::Path::Class;
use Time::HiRes ();
use File::Temp ();
use namespace::autoclean;

# ABSTRACT: role to dump Net::Stomp frames to disk


has trace_basedir => (
    is => 'rw',
    isa => 'Path::Class::Dir',
    coerce => 1,
);


has trace => (
    is => 'rw',
    isa => 'Bool',
    default => 0,
);


sub _dirname_from_destination {
    my ($self,$destination) = @_;

    return '' unless defined $destination;

    my $ret = $destination;
    $ret =~ s/\W+/_/g;
    return $ret;
}


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

__END__
=pod

=encoding utf-8

=head1 NAME

Net::Stomp::MooseHelpers::TracerRole - role to dump Net::Stomp frames to disk

=head1 VERSION

version 1.0

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

=head1 ATTRIBUTES

=head2 C<trace_basedir>

The directory under which frames will be dumped. Accepts strings and
L<Path::Class::Dir> objects. If it's not specified and you enable
L</trace>, every frame will generate a warning.

=head2 C<trace>

Boolean attribute to enable or disable tracing / dumping of frames. If
you enable tracing but don't set L</trace_basedir>, every frame will
generate a warning.

=head1 METHODS

=head2 C<_dirname_from_destination>

Generate a directory name from a frame destination. By default,
replaces every sequence of non-word characters with C<'_'>.

=head2 C<_filename_from_frame>

Returns a filehandle / filename pair for the file to write the frame
into. Avoids duplicates by using L<Time::HiRes>'s C<time> as a
starting filename, and L<File::Temp>.

=head1 AUTHOR

Gianni Ceccarelli <gianni.ceccarelli@net-a-porter.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Net-a-porter.com.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

