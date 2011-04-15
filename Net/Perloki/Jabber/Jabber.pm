package Net::Perloki::Jabber;

use strict;
use utf8;
no warnings 'utf8';

use Net::Perloki::XMPP;
use Net::Perloki::Commands;

my $singleton = undef;

sub new
{
    unless($singleton) {
        my ($class, $params) = @_;
        my $self = { params => $params };
        
        $self->{xmpp} = Net::Perloki::XMPP->new($params);
        $self->{commands} = Net::Perloki::Commands->new();
        
        return bless($self, $class);
    }

    return $singleton;
}

1;
