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
    my ($self, $from, $nick) = @_;
    
    $self->{perloki}->{storage}->changeNick($from, $nick);
}

sub getLastPublic
{
    my ($self, $from_order, $to_order) = @_;

    return $self->{perloki}->{storage}->getLastPublic($from_order, $to_order);
}

sub getPost
{
    my ($self, $order) = @_;

    return $self->{perloki}->{storage}->getPost($order);
}

sub getListCommentsToPost
{
    my ($self, $post_order, $comments_from_order, $comments_to_order) = @_;

    return $self->{perloki}->{storage}->getListCommentsToPost($post_order, $comments_from_order, $comments_to_order);
}

sub addPost
{
    my ($self, $from, $text) = @_;

    return $self->{perloki}->{storage}->addPost($from, $text);
}

sub addCommentToPost
{
    my ($self, $from, $post_order, $comment_order, $text) = @_;

    return $self->{perloki}->{storage}->addCommentToPost($from, $post_order, $comment_order, $text);
}

sub deletePost
{
    my ($self, $from, $order) = @_;

    return $self->{perloki}->{storage}->deletePost($from, $order);
}

sub getSubscriptions
{
    my ($self, $from) = @_;

    return $self->{perloki}->{storage}->getSubscriptions($from);
}

sub subscribeToUser
{
    my ($self, $from, $to) = @_;

    return $self->{perloki}->{storage}->subscribeToUser($from, $to);
}

sub addTags
{
    my ($self, $from, $order, @tags) = @_;

    return $self->{perloki}->{storage}->addTags($from, $order, @tags);
}

sub getTagsFromPost
{
    my ($self, $order) = @_;

    return $self->{perloki}->{storage}->getTagsFromPost($order);
}

sub getHelp
{
    my ($self) = @_;
    
    my $help = << "EOF";
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
EOF
; # for correct indentation of emacs

    return $help;
}

1;
