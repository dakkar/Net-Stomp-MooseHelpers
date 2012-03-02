package Net::Stomp::MooseHelpers::Exceptions;
# ABSTRACT: exception classes for Plack::Handler::Stomp

=head1 DESCRIPTION

This file defines the following exception classes:

=over 4

=item C<Net::Stomp::MooseHelpers::Exceptions::Stringy>

Exception I<role> to overload stringification delegating it to a
C<as_string> method.

=item C<Net::Stomp::MooseHelpers::Exceptions::Stomp>

Thrown whenever the STOMP library (usually L<Net::Stomp>) dies; has a
C<previous_exception> attribute containing the exception that the
library threw.

=back

=cut

{package Net::Stomp::MooseHelpers::Exceptions::Stringy;
 use Moose::Role;
 use MooseX::Role::WithOverloading;
  use overload
  q{""}    => 'as_string',
  fallback => 1;
 requires 'as_string';
}
{package Net::Stomp::MooseHelpers::Exceptions::Stomp;
 use Moose;with 'Throwable','Net::Stomp::MooseHelpers::Exceptions::Stringy';
 use namespace::autoclean;
 has '+previous_exception' => (
     init_arg => 'stomp_error',
 );
 sub as_string {
     return 'STOMP protocol/network error:'.$_[0]->previous_exception;
 }
 __PACKAGE__->meta->make_immutable;
}

1;
