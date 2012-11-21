package Net::Stomp::MooseHelpers::ReadTrace;
use Moose;
use MooseX::Types::Path::Class;
use Net::Stomp::Frame;
use Path::Class;
use Carp;
require Net::Stomp::MooseHelpers::TraceStomp;
use namespace::autoclean;

# ABSTRACT: class to read the output of L<Net::Stomp::MooseHelpers::TraceStomp>

=head1 SYNOPSIS

  my $reader = Net::Stomp::MooseHelpers::ReadTrace->new({
     trace_basedir => '/tmp/mq',
  });

  my @frames = $reader->sorted_frames('/queue/somewhere');

=head1 DESCRIPTION

L<Net::Stomp::MooseHelpers::TraceStomp> and
L<Net::Stomp::MooseHelpers::TraceOnly> write STOMP frames to
disk. This class helps you read them back.

=attr C<trace_basedir>

The directory from which frames will be read. Accepts strings and
L<Path::Class::Dir> objects.

=cut

has trace_basedir => (
    is => 'rw',
    isa => 'Path::Class::Dir',
    coerce => 1,
    required => 1,
);

=method C<read_frame_from_filename>

  my $stomp_frame = $reader->read_frame_from_filename('/a/path');

Given a filename (I<unrelated> to L</trace_basedir>), returns a
L<Net::Stomp::Frame> object parsed from it, using
L</read_frame_from_fh>.

=cut

sub read_frame_from_filename {
    my ($self,$filename) = @_;

    my $fh=file($filename)->openr;
    binmode $fh;
    return $self->read_frame_from_fh($fh);
}

=method C<read_frame_from_fh>

  my $stomp_frame = $reader->read_frame_from_fh($fh);

Given a filehandle (C<binmode> it first!), returns a
L<Net::Stomp::Frame> object parsed from it. If the filehandle contains
more than one frame, reads the first one and leaves the read position
just after it.

If the file was not a dumped STOMP frame, this function will probably
return nothing; if it looked enough like a STOMP frame, you'll get
back whatever could be parsed.

=cut

sub read_frame_from_fh {
    my ($self,$fh) = @_;

    local $/="\x0A";
    my $command=<$fh>;chomp $command;
    my %headers;
    while (defined(my $header_line=<$fh>)) {
        chomp $header_line;
        last if $header_line eq '';

        my ($key,$value) = split ':',$header_line,2;
        $headers{$key}=$value;
    }

    local $/=undef;

    my $body=<$fh>;

    return unless $body =~ s{\x00$}{}; # 0 marks the end of the frame

    return Net::Stomp::Frame->new({
        command => $command,
        headers => \%headers,
        body => $body,
    });
}

=method C<trace_subdir_for_destination>

  my $dir = $reader->trace_subdir_for_destination($destination);

Returns a L<Path::Class::Dir> object pointing at the (possibly
non-existent) directory used to store frames for the given
destination.

C<< ->trace_subdir_for_destination() >> is the same as C<<
->trace_basedir >>.

Passing an explicit C<undef> or an empty string will throw an
exception, see L</sorted_filenames> and L</clear_destination> for the
reason.

=cut

sub trace_subdir_for_destination {
    my ($self,$destination) = @_;

    if (@_==1) {
        return $self->trace_basedir;
    }

    confess "You must pass a defined, non-empty destination"
        if !length($destination);

    return $self->trace_basedir->subdir(
        Net::Stomp::MooseHelpers::TracerRole->
              _dirname_from_destination($destination)
          );
}

=method C<sorted_filenames>

  my @names = $reader->sorted_filenames();
  my @names = $reader->sorted_filenames($destination);

Given a destination (C</queue/something> or similar), returns all
frame dump filenames found under the corresponding dump directory
under L</trace_basedir>, sorted by filename (that is, by timestamp).

If you don't specify a destination, all filenames from all
destinations will be returned. Passing an explicit C<undef> or an
empty string will throw an exception, to save you when you try doing
things like:

  my $dest = get_something_from_config;
  my @names = $reader->sorted_filenames($dest);

and end up getting way more items than you thought.

=cut

sub sorted_filenames {
    my $self=shift;

    my $dir = $self->trace_subdir_for_destination(@_);

    return unless -e $dir;

    my @files;
    $dir->recurse(
        callback=>sub{
            my ($f) = @_;
            return if $f->is_dir;
            return unless $f->basename =~ /^\d+\.\d+-\w+-/;
            push @files,$f;
        },
    );
    @files = sort { $a->basename cmp $b->basename } @files;

    return @files;
}

=method C<clear_destination>

  $reader->clear_destination();
  $reader->clear_destination($destination);

Given a destination (C</queue/something> or similar), removes all
stored frames for it.

If you don't specify a destination, all frames for all destinations
will be removed. Passing an explicit C<undef> or an empty string will
throw an exception, to save you when you try doing things like:

  my $dest = get_something_from_config;
  $reader->clear_destination($dest);

and end up deleting way more than you thought.

=cut

sub clear_destination {
    my $self=shift;

    my $dir = $self->trace_subdir_for_destination(@_);

    $dir->rmtree({keep_root=>1});$dir->mkpath;

    return;
}

=method C<sorted_frames>

  my @frames = $reader->sorted_frames();
  my @frames = $reader->sorted_frames($destination);

Same as L</sorted_filenames>, but returns the parsed frames instead of
the filenames.

=cut

sub sorted_frames {
    my $self=shift;

    return map {
        $self->read_frame_from_filename($_)
    } $self->sorted_filenames(@_);
}

1;
