package Net::Stomp::MooseHelpers;

# ABSTRACT: set of helper roles and types to deal with Net::Stomp

=head1 DESCRIPTION

This distribution provides two roles,
L<Net::Stomp::MooseHelpers::CanConnect> and
L<Net::Stomp::MooseHelpers::CanSubscribe>, that you can consume in
your classes to simplify connecting and subscribing via Net::Stomp.

C<Net::Stomp::MooseHelpers::CanConnect> can be paired with
L<Net::Stomp::MooseHelpers::TraceStomp> to dump every frame to disk,
or with L<Net::Stomp::MooseHelpers::TraceOnly> to never touch the
network. L<Net::Stomp::MooseHelpers::ReadTrace> provides functions to
read back the dumped frames.

We also provide some types (L<Net::Stomp::MooseHelpers::Types>) and
exception classes (L<Net::Stomp::MooseHelpers::Exceptions>).

=cut

1;
