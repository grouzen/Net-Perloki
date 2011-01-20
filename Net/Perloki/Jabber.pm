package Net::Perloki::Jabber;

use strict;
use utf8;

use Net::Jabber;
use Net::Perloki;

my $this;

sub new
{
    my ($class, $params) = @_;
    my $self = { params => $params };
    
    $self->{perloki} = Net::Perloki->new();
    
    $this = bless($self, $class);

    return $this;
}

sub connect
{
    my ($self) = @_;
    
    $self->{connection} = Net::Jabber::Client->new(debuglevel => $self->{params}->{debuglevel}, 
                                                   debugfile => $self->{params}->{debugfile});
    $self->{connection}->SetMessageCallBacks(chat => \&_CBMessageChat);
    $self->{connection}->SetPresenceCallBacks(subscribe => \&_CBPresenceSubscribe);
    my $jid = Net::Jabber::JID->new($self->{params}->{jid});
    
    my $status = $self->{connection}->Connect(hostname => $self->{params}->{server}, 
                                              port => $self->{params}->{port});
    unless(defined($status)) {
        $self->{perloki}->{log}->write("Couldn't connect to server: $!\n");
        return 0;
    }

    my @auth_result = $self->{connection}->AuthSend(username => $jid->GetUserID(),
                                                    password => $self->{params}->{password},
                                                    resource => $jid->GetResource());
    if($auth_result[0] ne "ok") {
        $self->{perloki}->{log}->write("Auth failed: $auth_result[0]: $auth_result[1]\n");
        return 0;
    }

    $self->{connection}->RosterRequest();
    $self->{connection}->Process(3);
    $self->{connection}->PresenceSend();
    $self->{connection}->Process(3);

    return 1;
}

sub process
{
    my ($self) = @_;

    return 0 unless $self->connect();

    # TODO: reconnection.
    while(defined($self->{connection}->Process())) {}

    return 1;
}

sub disconnect
{
    my ($self) = @_;
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
    my $jid = Net::Jabber::JID->new($from);
    my $user = $jid->GetUserID() . '@' . $jid->GetServer();

    if($self->{perloki}->{commands}->isFirstPost($user)) {
        $response = "This is your first post, now you can use the bot";
    } elsif($body =~ /^NICK /) {
        $body =~ s/NICK//;
        $body =~ s/^\s*(.*?)\s*$/$1/;
        if($body eq "") {
            $response = $self->{perloki}->{commands}->usage();
        } else {
            $self->{perloki}->{commands}->changeNick($user, $body);
            $response = "Your nick has been changed";
        }
    } elsif($body =~ /^#\+/) {
        my @posts = $self->{perloki}->{commands}->getLastPublic();
        
        foreach my $post (@posts) {
            $response = "\@$post->{nick}:\n";
            $response .= "$post->{text}\n\n";
            $response .= "#$post->{order}\n";

            $self->_sendMessage($user, $response);
        }
        
        return;
    } elsif($body =~ /^#[0-9]+/) {
        $body =~ s/^#([0-9]+)/$1/;
        my $post = $self->{perloki}->{commands}->getPost($body);

        $response = "\@$post->{nick}:\n";
        $response .= "$post->{text}\n\n";
        $response .= "#$post->{order}\n";
    } else {
        my $post = $self->{perloki}->{commands}->addPost($user, $body);

        $response = "New message posted #$post->{order}";
    }

    $self->_sendMessage($user, $response);
}

sub _CBPresenceSubscribe
{
    my ($id, $presence) = @_;
    my $self = $this;
    my $from = $presence->GetFrom();

    $self->{connection}->Subscription(to => $from, type => 'subscribe');
    $self->{connection}->Subscription(to => $from, type => 'subscribed');
    
    $self->{perloki}->{log}->write("We have subscriber: $from\n");
}

1;
