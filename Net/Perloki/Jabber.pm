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
    } elsif($body =~ /^HELP/) {
        $response = $self->{perloki}->{commands}->getHelp();
    } elsif($body =~ /^NICK /) {
        $body =~ s/NICK//;
        #TODO: limit symbol range
        $body =~ s/^\s*([0-9A-Za-zА-Яа-я_\-@.]+)\s*$/$1/;
        if($body eq "") {
            $response = $self->{perloki}->{commands}->getHelp();
        } else {
            my $rc = $self->{perloki}->{commands}->changeNick($user, $body);
            if($rc eq "exists") {
                $response = "You cannot use this nick, nick already exists";
            } else {
                $response = "Your nick has been changed";
            }
        }
    } elsif($body =~ /^#\+/) {
        my @posts = $self->{perloki}->{commands}->getLastPublic();

        while(@posts) {
            my $post = pop(@posts);

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
    } elsif($body =~ /^D\s+#[0-9]+/) {
        $body =~ s/^D\s+#([0-9]+)/$1/;

        my $rc = $self->{perloki}->{commands}->deletePost($user, $body);
        if($rc eq "not exists") {
             $response = "Post with such order doesn't exist";
        } elsif($rc eq "not owner") {
            $response = "This is not your post";
        } else {
            $response = "Post deleted";
        }
    } elsif($body =~ /^S\s*$/) {
        my @susers = $self->{perloki}->{commands}->getSubscriptions($user);
        
        $response = "You are subscribed to users:\n";
        
        foreach my $suser (@susers) {
            $response .= "\@$suser->{nick}\n";
        }
    } elsif($body =~ /^S\s+@[0-9A-Za-zА-Яа-я_\-@.]+/) {
        $body =~ s/^S\s+@([0-9A-Za-zА-Яа-я_\-@.]+)/$1/;

        my $rc = $self->{perloki}->{commands}->subscribeToUser($user, $body);
        if($rc eq "not exists") {
            $response = "User with such nick doesn't exist";
        } elsif($rc eq "subscribed") {
            $response = "You have already subscribed to \@$body";
        } else {
            $response = "Subscribed to \@$body";
        }
    } else { 
        my $post = $self->{perloki}->{commands}->addPost($user, $body);

        $response = "New message posted #$post->{order}";
        
        my $message = "\@$post->{nick}:\n";
        $message .= "$post->{text}\n\n";
        $message .= "#$post->{order}\n";

        my @susers = $self->{perloki}->{storage}->getSubscribersToUser($user);

        while(@susers) {
            my $suser = pop(@susers);

            $self->_sendMessage($suser->{jid}, $message);
        }
    }

    $self->_sendMessage($from, $response);
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
    
    $self->{perloki}->{log}->write("We have subscriber: $user\n");
}

1;
