package Net::Perloki::Jabber;

use strict;
use utf8;
no warnings 'utf8';

use Net::Perloki::Jabber::XMPP;
use Net::Perloki::Jabber::Commands;

my $singleton = undef;

sub new
{
    unless($singleton) {
        my ($class, $params) = @_;
        my $self = { params => $params };
        
        $singleton = bless($self, $class);

        $self->{xmpp} = Net::Perloki::XMPP->new($params);
        $self->{commands} = Net::Perloki::Commands->new();        
    }

    return $singleton;
}

1;
