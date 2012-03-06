package Net::Stomp::MooseHelpers::ReadTrace;
use Moose;
use MooseX::Types::Path::Class;
use Net::Stomp::Frame;
use Path::Class;
require Net::Stomp::MooseHelpers::TraceStomp;
use namespace::autoclean;

# ABSTRACT: class to read the output of L<Net::Stomp::MooseHelpers::TraceStomp>

has trace_basedir => (
    is => 'rw',
    isa => 'Path::Class::Dir',
    coerce => 1,
    required => 1,
);

sub read_frame_from_filename {
    my ($self,$filename) = @_;

    my $fh=file($filename)->openr;
    binmode $fh;
    return $self->read_frame_from_fh($fh);
}

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

    local $/="\x00";
    my $body=<$fh>;

    return Net::Stomp::Frame->new({
        command => $command,
        headers => \%headers,
        body => $body,
    });
}

sub sorted_filenames {
    my ($self,$destination) = @_;

    my $dir = $self->trace_basedir->subdir(
        Net::Stomp::MooseHelpers::TraceStomp->
              _dirname_from_destination($destination)
          );

    my @files;
    $dir->recurse(
        callback=>sub{
            my ($f) = @_;
            return if $f->is_dir;
            push @files,$f;
        },
    );
    @files = sort { $a->basename cmp $b->basename } @files;

    return @files;
}

sub sorted_frames {
    my ($self,$destination) = @_;

    return map {
        $self->read_frame_from_filename($_)
    } $self->sorted_filenames($destination);
}

1;
