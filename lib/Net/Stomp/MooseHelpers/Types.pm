package Net::Stomp::MooseHelpers::Types;
{
  $Net::Stomp::MooseHelpers::Types::VERSION = '1.0';
}
{
  $Net::Stomp::MooseHelpers::Types::DIST = 'Net-Stomp-MooseHelpers';
}
use MooseX::Types -declare =>
    [qw(
           NetStompish
           Hostname PortNumber
           ServerConfig ServerConfigList
           Headers
           SubscriptionConfig SubscriptionConfigList
           Destination
   )];
use MooseX::Types::Moose qw(Str Value Int ArrayRef HashRef);
use MooseX::Types::Structured qw(Dict Optional Map);
use namespace::autoclean;

# ABSTRACT: type definitions for Net::Stomp::MooseHelpers


duck_type NetStompish, [qw(connect
                           subscribe unsubscribe
                           receive_frame ack
                           send send_frame)];


subtype Hostname, as Str; # maybe too lax?


subtype PortNumber, as Int,
    where { $_ > 0 and $_ < 65536 };


subtype ServerConfig, as Dict[
    hostname => Hostname,
    port => PortNumber,
    connect_headers => Optional[HashRef],
    subscribe_headers => Optional[HashRef],
];


subtype ServerConfigList, as ArrayRef[ServerConfig];
coerce ServerConfigList, from ServerConfig, via { [shift] };


subtype Headers, as Map[Str,Value];


subtype SubscriptionConfig, as Dict[
    destination => Destination,
    path_info => Optional[Str],
    headers => Optional[Map[Str,Value]],
];


subtype SubscriptionConfigList, as ArrayRef[SubscriptionConfig];
coerce SubscriptionConfigList, from SubscriptionConfig, via { [shift] };


subtype Destination, as Str,
    where { m{^/(?:queue|topic)/} };

__END__
=pod

=encoding utf-8

=head1 NAME

Net::Stomp::MooseHelpers::Types - type definitions for Net::Stomp::MooseHelpers

=head1 VERSION

version 1.0

=head1 TYPES

=head2 C<NetStompish>

Any object that can C<connect>, C<subscribe>, C<unsubscribe>,
C<receive_frame>, C<ack>, C<send>, C<send_frame>.

=head2 C<Hostname>

A string.

=head2 C<PortNumber>

An integer between 1 and 65535.

=head2 C<ServerConfig>

A hashref having a C<hostname> key (with value matching L</Hostname>),
a C<port> key (value matching L</PortNumber>), and optionally a
C<connect_headers> key (with a hashref value) and a
C<subscribe_headers> key (with a hashref value). See
L<Net::Stomp::MooseHelpers::CanConnect/connect>.

=head2 C<ServerConfigList>

An arrayref of L</ServerConfig> values. Can be coerced from a single
L</ServerConfig>.

=head2 C<Headers>

A hashref.

=head2 C<SubscriptionConfig>

A hashref having a C<destination> key (with a value matching
L</Destination>), and optionally a C<path_info> key (with value
matching L</Path>) and a C<headers> key (with a hashref value). See
L<Net::Stomp::MooseHelpers::CanSubscribe/subscribe>.

=head2 C<SubscriptionConfigList>

An arrayref of L</SubscriptionConfig> values. Can be coerced from a
single L</SubscriptionConfig>.

=head2 C<Destination>

A string starting with C</queue/> or C</topic/>.

=head1 AUTHOR

Gianni Ceccarelli <gianni.ceccarelli@net-a-porter.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Net-a-porter.com.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

