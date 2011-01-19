package Net::Perloki::Commands;

use strict;
use utf8;

use Net::Perloki;

sub new
{
    my $class = shift;
    my $self = {};
    
    $self->{perloki} = Net::Perloki->new();

    return bless($self, $class);
}

sub isFirstPost
{
    my ($self, $from) = @_;

    return $self->{perloki}->{storage}->isFirstPost($from);
}

sub changeNick
{
    my ($self, $from, $nick) = @_;
    
    $self->{perloki}->{storage}->changeNick($from, $nick);
}

sub getLastPublic
{
    my $self = shift;

    return $self->{perloki}->{storage}->getLastPublic();
}

sub getPost
{
    my ($self, $order) = @_;

    return $self->{perloki}->{storage}->getPost($order);
}

sub addPost
{
    my ($self, $from, $text) = @_;

    return $self->{perloki}->{storage}->addPost($from, $text);
}

sub usage
{
    my $self = shift;
    
    my $usage = << "EOF";
NICK nickname - change your nick.
#+ - show last 10 posts from public.
#123456 - show posts with order 123456.
EOF
;

    return $usage;
}

1;
