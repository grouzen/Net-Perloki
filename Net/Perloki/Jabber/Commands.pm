package Net::Perloki::Commands;

use strict;
use utf8;

use Net::Perloki;

sub new
{
    my ($class) = @_;
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
    my ($self, $user, $command) = @_;
    my $response;

    $command =~ s/NICK//;
    #TODO: limit symbol range
    $command =~ s/^\s*([0-9A-Za-zА-Яа-я_\-@.]+)\s*$/$1/;
    if($command eq "") {
        $response = $self->{perloki}->{commands}->getHelp();
    } else {
        my $rc = $self->{perloki}->{storage}->changeNick($user, $command);
        if($rc eq "exists") {
            $response = "You cannot use this nick, nick already exists";
        } else {
            $response = "Your nick has been changed";
        }
    }

    return $response;
}

sub getPosts
{
    my ($self, $from, $command) = @_;
    my ($from_order, $to_order) = $command =~ /^#\+\s+([0-9]+)\s*([0-9]*)/;
    
    my @posts = $self->{perloki}->{storage}->getPosts($from_order, $to_order);

    while(@posts) {
        my $post = pop(@posts);
        my @tags = $self->{perloki}->{storage}->getTagsFromPost($post->{order});
        my $with_tags = "";
        if($#tags >= 0) {
            foreach my $tag (@tags) {
                $with_tags .= "*$tag ";
            }
        }

        $response = "\@$post->{nick}: $with_tags\n";
        $response .= "$post->{text}\n\n";
        $response .= "#$post->{order}";

        $self->{perloki}->{jabber}->sendMessage($from, $response);
    }
    
    $self->{perloki}->{jabber}->sendMessage($from, "Total posts: " . $self->{perloki}->{storage}->getPostsCount() . "."); 
}

sub getPost
{
    my ($self, $command) = @_;
    my $response;

    $command =~ s/^#([0-9]+)/$1/;

    my $post = $self->{perloki}->{storage}->getPost($command);
    my @tags = $self->{perloki}->{storage}->getTagsFromPost($post->{order});

    my $with_tags = "";
    if($#tags >= 0) {
        foreach my $tag (@tags) {
            $with_tags .= "*$tag ";
        }
    }

    $response = "\@$post->{nick}: $with_tags\n";
    $response .= "$post->{text}\n\n";
    $response .= "#$post->{order}";

    return $response;
}

sub getListCommentsToPost
{
    my ($self, $from, $command) = @_;
    my ($post_order, $comments_from_order, $comments_to_order) = $command =~ /^#([0-9]+)\+\s*([0-9]*)\s*([0-9]*)/;
    my $response;

    my @tags = $self->{perloki}->{storage}->getTagsFromPost($post_order);

    my $with_tags = "";
    if($#tags >= 0) {
        foreach my $tag (@tags) {
            $with_tags .= "*$tag ";
        }
    }

    my $post = $self->{perloki}->{storage}->getPost($post_order);
    $response = "\@$post->{nick}: $with_tags\n";
    $response .= "$post->{text}\n\n";
    $response .= "#$post->{order}";
    $self->{perloki}->{jabber}->sendMessage($from, $response);

    my @comments = $self->{perloki}->{storage}->getListCommentsToPost($post_order, $comments_from_order, $comments_to_order);
    
    foreach my $comment (@comments) {
        $comment->{reply} = $self->{perloki}->{storage}->getCommentToPost($post_order, $comment->{order}) if $comment->{posts_comments_id} > 0;

        $response = "\@$comment->{nick}:\n";
        if(defined($comment->{reply})) {
            $response .= "\@$comment->{reply}->{nick} ";
        }
        $response .= "$comment->{text}\n\n";
        $response .= "#$post_order/$comment->{order}";

        $self->{perloki}->{jabber}->sendMessage($from, $response);
    }

    $self->{perloki}->{jabber}->sendMessage($from, "Total comments: " . $self->{perloki}->{storage}->getCommentsToPostCount($post_order) . ".");
}

sub addPost
{
    my ($self, $user, $from, $command) = @_;
    my $post_tags = $command;
    my $response;

    $post_tags =~ s/^\s*((\*[\S]+\s*)*)\s+[^\*]?.+$/$1/;
    
    my @tags = $post_tags =~ /\*([\S]+)/g;

    $command =~ s/^\s*(\*[\S]+\s*)*\s*([^\*]?.+)$/$2/;

    my @rc = $self->{perloki}->{storage}->addPost($user, $command);
    if($rc[0] eq "max length exceeded") {
        $response = "Maximal length of the post must be less than 10240 bytes";
    } else {
        $self->{perloki}->{storage}->addTags($user, $rc[1]->{order}, @tags);
        $response = "New message posted #$rc[1]->{order}";
        
        @tags = $self->{perloki}->{storage}->getTagsFromPost($rc[1]->{order});
        my $with_tags = "";
        if($#tags >= 0) {
            foreach my $tag (@tags) {
                $with_tags .= "*$tag ";
            }
        }

        my $message = "\@$rc[1]->{nick}: $with_tags\n";
        $message .= "$rc[1]->{text}\n\n";
        $message .= "#$rc[1]->{order}";
        
        my @susers = $self->{perloki}->{storage}->getSubscribersToUser($user);
        
        foreach my $suser (@susers) {
            $self->{perloki}->{jabber}->sendMessage($suser->{jid}, $message);
        }
    }

    return $response;
}

sub addCommentToPost
{
    my ($self, $from, $command) = @_;
    my $post_order = 0;
    my $comment_order = 0;
    my $text = "";
    my $response;

    ($post_order) = $command =~ /^#([0-9]+)/;
    if($command =~ /^#[0-9]+\/([0-9]+)/) {
        $comment_order = $1;
    }
    ($text) = $command =~ /^#[0-9]+[\/]?[0-9]*\s+(.*)$/;

    my @rc = $this->{perloki}->{storage}->addCommentToPost($user, $post_order, $comment_order, $text);
    if($rc[0] eq "post not exists") {
        $response = "Post, you are replying to, not found";
    } elsif($rc[0] eq "comment not exists") {
        $response = "Comment, you are replying to, not found";
    } elsif($rc[0] eq "max length exceeded") { 
        $response = "Maximal length of the message must be less than 4096 bytes";
    } else {
        $response = "Reply posted #$post_order/$rc[1]->{order}";

        $self->{perloki}->{storage}->subscribeToPost($user, $post_order);

        my $message = "\@$rc[1]->{nick}:\n";
        if(defined($rc[1]->{reply})) {
            $message .= "\@$rc[1]->{reply}->{nick} ";
        }
        $message .= "$rc[1]->{text}\n\n";
        $message .= "#$post_order/$rc[1]->{order}";

        my @susers = $self->{perloki}->{storage}->getSubscribersToPost($post_order);

        foreach my $suser (@susers) {
            $self->{perloki}->{jabber}->sendMessage($suser->{jid}, $message) unless $suser->{jid} eq $user;
        }
    }

    return $response;
}

sub deletePost
{
    my ($self, $user, $command) = @_;
    $command =~ s/^D\s+#([0-9]+)/$1/;

    my $rc = $self->{perloki}->{storage}->deletePost($user, $command);
    if($rc eq "not exists") {
        $response = "Post with such order doesn't exist";
    } elsif($rc eq "not owner") {
        $response = "This is not your post";
    } else {
        $response = "Post deleted";
    }

    return $response;
}

sub getSubscriptions
{
    my ($self, $user) = @_;
    my $response;

    my @susers = $self->{perloki}->{commands}->getSubscriptions($user);
    
    $response = "You are subscribed to users:\n";
    foreach my $suser (@susers) {
        $response .= "\@$suser->{nick}\n";
    }

    return $response;
}

sub subscribeToUser
{
    my ($self, $user, $command) = @_;

    $command =~ s/^S\s+@([0-9A-Za-zА-Яа-я_\-@.]+)/$1/;

    my $rc = $self->{perloki}->{storage}->subscribeToUser($user, $command);
    if($rc eq "not exists") {
        $response = "User with such nick doesn't exist";
    } elsif($rc eq "subscribed") {
        $response = "You have already subscribed to \@$command";
    } else {
        $response = "Subscribed to \@$command";
    }

    return $response;
}

#sub addTags
#{
#    my ($self, $from, $order, @tags) = @_;
#
#    return $self->{perloki}->{storage}->addTags($from, $order, @tags);
#}

#sub getTagsFromPost
#{
#    my ($self, $order) = @_;
#
#    return $self->{perloki}->{storage}->getTagsFromPost($order);
#}

sub getHelp
{
    my $response = << "EOF";
HELP - show this message.
NICK nickname - change your nick.
post's text - just add new post.
*tag1 *tag2 *tagN post's text - add new post with tags.
#+ - show last 10 posts from public.
#+ 3 5 - show posts with orders between 3 and 5.
#123456 - show posts with order 123456.
#123456 comment's text - add comment to post with order 123456.
#123456/123 comment's text - add comment to comment with order 123 from post with order 123456.
#123456+ - show all comments from post with order 123456.
#123456+ 12 34 - show comments with orders between 12 and 34 from post with order 123456.
S - show your subscriptions to users, tags, and clubs.
S \@nick - subscribe to user \@nick.
D #123456 - delete post with order #123456.
EOF
; # for correct indentation of emacs

    return $response;
}

1;
