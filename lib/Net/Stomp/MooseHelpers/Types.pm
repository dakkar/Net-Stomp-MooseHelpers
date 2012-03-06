package Net::Stomp::MooseHelpers::Types;
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

=head1 TYPES

=head2 C<NetStompish>

Any object that can C<connect>, C<subscribe>, C<unsubscribe>,
C<receive_frame>, C<ack>, C<send>, C<send_frame>.

=cut

duck_type NetStompish, [qw(connect
                           subscribe unsubscribe
                           receive_frame ack
                           send send_frame)];

=head2 C<Hostname>

A string.

=cut

subtype Hostname, as Str; # maybe too lax?

=head2 C<PortNumber>

An integer between 1 and 65535.

=cut

subtype PortNumber, as Int,
    where { $_ > 0 and $_ < 65536 };

=head2 C<ServerConfig>

A hashref having a C<hostname> key (with value matching L</Hostname>),
a C<port> key (value matching L</PortNumber>), and optionally a
C<connect_headers> key (with a hashref value) and a
C<subscribe_headers> key (with a hashref value). See
L<Plack::Handler::Stomp/connect> and
L<Plack::Handler::Stomp/subscribe>.

=cut

subtype ServerConfig, as Dict[
    hostname => Hostname,
    port => PortNumber,
    connect_headers => Optional[HashRef],
    subscribe_headers => Optional[HashRef],
];

=head2 C<ServerConfigList>

An arrayref of L</ServerConfig> values. Can be coerced from a single
L</ServerConfig>.

=cut

subtype ServerConfigList, as ArrayRef[ServerConfig];
coerce ServerConfigList, from ServerConfig, via { [shift] };

=head2 C<Headers>

A hashref.

=cut

subtype Headers, as Map[Str,Value];

=head2 C<SubscriptionConfig>

A hashref having a C<destination> key (with a value matching
L</Destination>), and optionally a C<path_info> key (with value
matching L</Path>) and a C<headers> key (with a hashref value). See
L<Plack::Handler::Stomp/subscribe>.

=cut

subtype SubscriptionConfig, as Dict[
    destination => Destination,
    path_info => Optional[Str],
    headers => Optional[Map[Str,Value]],
];

=head2 C<SubscriptionConfigList>

An arrayref of L</SubscriptionConfig> values. Can be coerced from a
single L</SubscriptionConfig>.

=cut

subtype SubscriptionConfigList, as ArrayRef[SubscriptionConfig];
coerce SubscriptionConfigList, from SubscriptionConfig, via { [shift] };

=head2 C<Destination>

A string starting with C</queue/> or C</topic/>.

=cut

subtype Destination, as Str,
    where { m{^/(?:queue|topic)/} };
