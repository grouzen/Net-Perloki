package Net::Perloki::Jabber;

use strict;
use utf8;

use Net::Jabber;
use Net::Perloki;

my $this;

sub new
{
    my $class = shift;
    my $self = {};
    
    $self->{perloki} = Net::Perloki->new();
    
    $this = bless($self, $class);

    return $this;
}

sub connect
{
    my ($self, $params) = @_;
    
    $self->{connection} = Net::Jabber::Client->new(debuglevel => 2, debugfile => "stdout");
    $self->{connection}->SetMessageCallBacks(chat => \&_CBMessageChat);
    $self->{connection}->SetPresenceCallBacks(subscribe => \&_CBPresenceSubscribe,
                                              subscribed => \&_CBPresenceSubscribed);
    my $jid = Net::Jabber::JID->new($params->{jid});
    
    my $status = $self->{connection}->Connect(hostname => $params->{server}, port => $params->{port});
    unless(defined($status)) {
        $self->{perloki}->{log}->write("Couldn't connect to server: $!\n");
        return 0;
    }

    my @auth_result = $self->{connection}->AuthSend(username => $jid->GetUserID(),
                                             password => $params->{password},
                                             resource => $jid->GetResource());
    if($auth_result[0] ne "ok") {
        $self->{perloki}->{log}->write("Auth failed: $auth_result[0]: $auth_result[1]\n");
        return 0;
    }

    $self->{connection}->RosterRequest();
    $self->{connection}->Process(3);
    $self->{connection}->PresenceSend();
    $self->{connection}->Process(3);

    # TODO: reconnection.
    while(defined($self->{connection}->Process())) {}
}

sub disconnect
{
    my $self = shift;
    $self->{connection}->Disconnect();
}

sub _sendMessage
{
    my ($self, $to, $body) = @_;

    $self->{connection}->MessageSend(to => $to, body => $body, type => 'chat');
}

sub _CBMessageChat
{
    my ($id, $message) = @_;
    my $self = $this;
    my $from = $message->GetFrom();
    my $body = $message->GetBody();
    my $response = '';

    if($self->{perloki}->{commands}->isFirstPost($from)) {
        $response = "This is your first post, now you can use the bot";
    } elsif($body =~ /^NICK /) {
        $body =~ s/NICK//;
        $body =~ s/^\s*(.*?)\s*$/$1/;
        if($body eq "") {
            $response = $self->{perloki}->{commands}->usage();
        } else {
            $self->{perloki}->{commands}->changeNick($from, $body);
            $response = "Your nick has been changed";
        }
    } elsif($body =~ /^#\+/) {
        my @posts = $self->{perloki}->{commands}->getLastPublic();
        
        foreach my $post (@posts) {
            $response = "\@$post->{nick}:\n";
            $response .= "$post->{text}\n\n";
            $response .= "#$post->{order}\n";

            $self->_sendMessage($from, $response);
        }
        
        return;
    } elsif($body =~ /^#[0-9]+/) {
        $body =~ s/^#([0-9]+)/$1/;
        my $post = $self->{perloki}->{commands}->getPost($body);

        $response = "\@$post->{nick}:\n";
        $response .= "$post->{text}\n\n";
        $response .= "#$post->{order}\n";
    } else {
        my $post = $self->{perloki}->{commands}->addPost($from, $body);

        $response = "New message posted #$post->{order}";
    }

    $self->_sendMessage($from, $response);
}

sub _CBPresenceSubscribe
{
    print "Subscribe\n";
}

sub _CBPresenceSubscribed
{
    print "Subscribed\n";
}

1;
