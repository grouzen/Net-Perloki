package Net::Perloki::XMPP;

use strict;
use utf8;
no warnings 'utf8';

use Net::Jabber;
use Net::Perloki;
use Net::Perloki::Jabber;

my $this;

sub new
{
    my ($class, $params) = @_;
    my $self = { params => $params };
    
    $self->{perloki} = Net::Perloki->new();
    $self->{jabber} = Net::Perloki::Jabber->new();
    
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

sub sendMessage
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

    if($self->{jabber}->{commands}->isFirstPost($user)) {
        $response = "This is your first post, now you can use the bot.\n";
        $response .= "Now you can type HELP for getting help about using the bot.";
    } elsif($body =~ /^HELP/) {
        $response = $self->{jabber}->{commands}->getHelp();
    } elsif($body =~ /^NICK /) {
        $response = $self->{jabber}->{commands}->changeNick($user, $body);
    } elsif($body =~ /^#(\+|\+\s+[0-9]+|\+\s+[0-9]+\s+[0-9]+)/) {
        $self->{jabber}->{commands}->getPosts($from, $body);        
        return;
    } elsif($body =~ /^#([0-9]+\+|[0-9]+\+\s+[0-9]+|[0-9]+\+\s+[0-9]+\s+[0-9]+)/) {
        $self->{jabber}->{commands}->getListCommentsToPost($from, $body);
        return;
    } elsif($body =~ /^#[0-9]+[\/]?[0-9]*\s+.*$/) {
        $response = $self->{jabber}->{commands}->addCommentToPost($from, $body);
    } elsif($body =~ /^#[0-9]+/) {
        $response = $self->{jabber}->{commands}->getPost($body);
    } elsif($body =~ /^D\s+#[0-9]+/) {
        $response = $self->{jabber}->{commands}->deletePost($user, $body);
    } elsif($body =~ /^S\s*$/) {
        $response = $self->{jabber}->{commands}->getSubscriptions($user);
    } elsif($body =~ /^S\s+@[0-9A-Za-zА-Яа-я_\-@.]+/) {
        $response = $self->{jabber}->{commands}->subscribeToUser($user, $body);
    } else {
        $response = $self->{jabber}->{commands}->addPost($user, $from, $body);
    }

    $self->sendMessage($from, $response);
}

sub _CBPresenceSubscribe
{
    my ($id, $presence) = @_;
    my $self = $this;
    my $from = $presence->GetFrom();
    my $jid = Net::Jabber::JID->new($from);
    my $user = $jid->GetUserID() . '@' . $jid->GetServer();

    $self->{connection}->Subscription(to => $from, type => 'subscribe');
    $self->{connection}->Subscription(to => $from, type => 'subscribed');
    
    $self->{perloki}->{log}->write("We have new subscriber: $user\n");
}

1;
