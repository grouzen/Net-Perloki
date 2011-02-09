package Net::Perloki::Mysql;

use strict;
use utf8;

use DBI;
use Net::Perloki;

sub new
{
    my ($class, $params) = @_;
    my $self = { params => $params };

    $self->{perloki} = Net::Perloki->new();

    return bless($self, $class);
}

sub connect
{
    my ($self) = @_;

    my $dsn = "DBI:mysql:database=$self->{params}->{dbname};host=$self->{params}->{dbhost};port=$self->{params}->{dbport}";
    $self->{dbh} = DBI->connect($dsn, $self->{params}->{dbuser}, $self->{params}->{dbpassword}, 
                                {RaiseError => 1, AutoCommit => 1, mysql_enable_utf8 => 1});
    if(!$self->{dbh}) {
        sleep(1);
        $self->{dbh} = DBI->connect($dsn, $self->{params}->{dbuser}, $self->{params}->{dbpassword},
                                    {RaiseError => 1, AutoCommit => 1, mysql_enable_utf8 => 1});
        if(!$self->{dbh}) {
            $self->{perloki}->{log}->write("$DBI::errstr\n");
            return 0;
        }
    }
    
    $self->_mysqlQueryDo("SET NAMES 'utf8'");

    return 1;
}

sub disconnect
{
    my ($self) = @_;
    $self->{dbh}->disconnect() if defined($self->{dbh});
}

sub _mysqlQuery
{
    my ($self, $query) = @_;

    my $sth = $self->{dbh}->prepare($query);
    return $sth if $sth->execute();

    $self->connect();
    $sth = $self->{dbh}->prepare($query);
    return $sth if $sth->execute();

    $self->{perloki}->{log}->write("$DBI::errstr\n");
    return undef;
}

sub _mysqlQueryDo
{
    my ($self, $query) = @_;

    my $rows = $self->{dbh}->do($query);
    return $rows if $rows;

    $self->connect();
    return $self->{dbh}->do($query);
}

sub _mysqlEscape
{
    shift;
    my $string = shift;

    $string =~ tr/\x00-\x1f//;
    $string =~ s/\\/\\\\/g;
    $string =~ s/'/\\'/g;
    
    return $string;
}

sub isFirstPost
{
    my ($self, $from) = @_;
    $from = $self->_mysqlEscape($from);

    my $sth = $self->_mysqlQuery("SELECT * FROM `users` WHERE `jid` = '$from' LIMIT 1");
    return 0 unless $sth;

    unless($sth->rows()) {
        $self->_mysqlQueryDo("INSERT INTO `users` (`jid`, `nick`) VALUES ('$from', '$from')");

        return 1;
    }
  
    return 0;
}

sub changeNick
{
    my ($self, $from, $nick) = @_;
    $from = $self->_mysqlEscape($from);
    $nick = $self->_mysqlEscape($nick);

    my $sth = $self->_mysqlQuery("SELECT * FROM `users` WHERE `nick` = '$nick'");
    return "exists" if $sth->rows();

    $self->_mysqlQueryDo("UPDATE `users` SET `nick` = '$nick' WHERE `jid` = '$from' LIMIT 1");

    return "ok";
}

sub getLastPublic
{
    my ($self) = @_;
    
    my $sth = $self->_mysqlQuery("SELECT * FROM `posts` `p` LEFT JOIN `users` `u` ON `p`.`users_id` = `u`.`id` WHERE `p`.`deleted` = 0 ORDER BY `p`.`order` DESC LIMIT 10");
    return undef unless $sth;
    
    my @posts = ();

    if($sth->rows()) {
        while(my $post = $sth->fetchrow_hashref()) {
            push(@posts, $post);
        }
    }

    return @posts;
}

sub getPost
{
    my ($self, $order) = @_;
    $order = int($order);

    my $sth = $self->_mysqlQuery("SELECT * FROM `posts` `p` LEFT JOIN `users` `u` ON `p`.`users_id` = `u`.`id` WHERE `p`.`order` = $order AND `p`.`deleted` = 0 LIMIT 1");

    return $sth->fetchrow_hashref();
}

sub getCommentToPost
{
    my ($self, $post_order, $comment_order) = @_;
    $post_order = int($post_order);
    $comment_order = int($comment_order);

    my $sth = $self->_mysqlQuery("SELECT * FROM `posts_comments` `p` LEFT JOIN `users` `u` ON `p`.`users_id` = `u`.`id` WHERE `p`.`order` = $comment_order AND `p`.`deleted` = 0 AND `p`.`posts_id` = (SELECT `id` FROM `posts` WHERE `order` = $post_order AND `deleted` = 0)");

    return $sth->fetchrow_hashref();
}

sub getListCommentsToPost
{
    my ($self, $post_order, $comments_from_order, $comment_to_order) = @_;
    $post_order = int($post_order);
    $comments_from_order = int($comments_from_order);
    $comments_to_order = int($comments_to_order);
    my $sth;

    if($comments_from_order > 0 && $comments_to_order > 0) {
        $sth = $self->_mysqlQuery("SELECT * FROM `posts_comments` `p` LEFT JOIN `users` `u` ON `p`.`users_id` = `u`.`id` WHERE `p`.`order` > $comments_from_order AND `p`.`order` < $comments_to_order AND `p`.`deleted` = 0 AND `p`.`posts_id` = (SELECT `id` FROM `posts` WHERE `order` = $post_order AND `deleted` = 0)");
    } elsif($comments_from_order > 0 && $comments_to_order == 0) {
        $sth = $self->_mysqlQuery("SELECT * FROM `posts_comments` `p` LEFT JOIN `users` `u` ON `p`.`users_id` = `u`.`id` WHERE `p`.`order` > $comments_from_order AND `p`.`deleted` = 0 AND `p`.`posts_id` = (SELECT `id` FROM `posts` WHERE `order` = $post_order AND `deleted` = 0)");
    } elsif($comments_from_order == 0 && $comments_to_order > 0) {
        $sth = $self->_mysqlQuery("SELECT * FROM `posts_comments` `p` LEFT JOIN `users` `u` ON `p`.`users_id` = `u`.`id` WHERE `p`.`order` < $comments_to_order AND `p`.`deleted` = 0 AND `p`.`posts_id` = (SELECT `id` FROM `posts` WHERE `order` = $post_order AND `deleted` = 0)");
    } else {
        $sth = $self->_mysqlQuery("SELECT * FROM `posts_comments` `p` LEFT JOIN `users` `u` ON `p`.`users_id` = `u`.`id` WHERE `p`.`deleted` = 0 AND `p`.`posts_id` = (SELECT `id` FROM `posts` WHERE `order` = $post_order AND `deleted` = 0)");
    }

    my @comments = ();
    
    if($sth->rows()) {
        while(my $comment = $sth->fetchrow_hashref()) {
           push(@comments, $comment); 
        }
    }
    
    return @comments;
}

sub addPost
{
    my ($self, $from, $text) = @_;
    $from = $self->_mysqlEscape($from);
    $text = $self->_mysqlEscape($text);
    my @rc = ();

    if(length(Encode::encode_utf8($text)) > 10240) {
        $rc[0] = "max length exceeded";
    } else {
        my $sth = $self->_mysqlQuery("SELECT * FROM `posts`");
        
        my $sth_order = $self->_mysqlQuery("SELECT MAX(`order`) AS `max_order` FROM `posts`");
        my $order = $sth_order->fetchrow_hashref()->{max_order} + 1;
        
        $self->_mysqlQueryDo("INSERT INTO `posts` (`order`, `text`, `users_id`) VALUES ($order, '$text', (SELECT `id` FROM `users` WHERE `jid` = '$from' LIMIT 1))");

        $rc[1] = $self->getPost($order);
        $rc[0] = "ok";
    }

    return @rc;
}

sub addCommentToPost
{
    my ($self, $from, $post_order, $comment_order, $text) = @_;
    $from = $self->_mysqlEscape($from);
    $post_order = int($post_order);
    $comment_order = int($comment_order);
    $text = $self->_mysqlEscape($text);
    my @rc = ();
    
    if(length(Encode::encode_utf8($text)) > 4096) {
        $rc[0] = "max length exceeded";
    } else {
        my $sth = $self->_mysqlQuery("SELECT * FROM `posts` WHERE `deleted` = 0 AND `order` = $post_order LIMIT 1");
        unless($sth->rows()) {
            $rc[0] = "post not exists";
        } else {
            my $posts_id = $sth->fetchrow_hashref()->{id};
            
            $sth = $self->_mysqlQuery("SELECT * FROM `posts_comments` WHERE `deleted` = 0 AND `order` = $comment_order");
            unless($sth->rows() && $comment_order > 0) {
                $rc[0] = "comment not exists";
            } else {
                my $comments_id = 0;
                my $sth_order = $self->_mysqlQuery("SELECT MAX(`order`) AS `max_order` FROM `posts_comments`");
                my $order = $sth_order->fetchrow_hashref()->{max_order} + 1;
                
                $comments_id = $sth->fetchrow_hashref()->{id} if $comment_order > 0;
                $self->_mysqlQueryDo("INSERT INTO `posts_comments` (`users_id`, `posts_id`, `posts_comments_id`, `text`, `order`) VALUES ((SELECT `id` FROM `users` WHERE `jid` = '$from'), $posts_id, $comments_id, '$text', $order)");
                
                $rc[1] = $self->getCommentToPost($post_order, $order);
                $rc[1]->{reply} = $self->getCommentToPost($post_order, $comment_order) if $comment_order > 0;
                $rc[0] = "ok";
            }
        }
    }

    return @rc;
}

sub deletePost
{
    my ($self, $from, $order) = @_;
    $from = $self->_mysqlEscape($from);
    $order = int($order);

    my $sth = $self->_mysqlQuery("SELECT * FROM `posts` WHERE `order` = $order AND `deleted` = 0 LIMIT 1");
    return "not exists" unless $sth->rows();

    $sth = $self->_mysqlQuery("SELECT * FROM `posts` WHERE `order` = $order AND `users_id` = (SELECT `id` FROM `users` WHERE `jid` = '$from' LIMIT 1)");
    return "not owner" unless $sth->rows();

    $self->_mysqlQueryDo("UPDATE `posts` SET `deleted` = 1 WHERE `order` = $order");

    return "ok";
}

sub getSubscriptions
{
    my ($self, $from) = @_;
    $from = $self->_mysqlEscape($from);

    my $sth = $self->_mysqlQuery("SELECT * FROM `users` WHERE `id` IN((SELECT `to` FROM `subscriptions_users` WHERE `from` = (SELECT `id` FROM `users` WHERE `jid` = '$from'))) ORDER BY `nick`");
    my @users = ();

    if($sth->rows()) {
        while(my $user = $sth->fetchrow_hashref()) {
            push(@users, $user);
        }
    }

    return @users;
}

sub subscribeToUser
{
    my ($self, $from, $to) = @_;
    $from = $self->_mysqlEscape($from);
    $to = $self->_mysqlEscape($to);

    my $sth = $self->_mysqlQuery("SELECT * FROM `users` WHERE `nick` = '$to' LIMIT 1");
    return "not exists" unless $sth->rows();

    my $sth_from = $self->_mysqlQuery("SELECT * FROM `users` WHERE `jid` = '$from' LIMIT 1");
    my $id_from = $sth_from->fetchrow_hashref()->{id};

    my $sth_to = $self->_mysqlQuery("SELECT * FROM `users` WHERE `nick` = '$to' LIMIT 1");
    my $id_to = $sth_to->fetchrow_hashref()->{id};

    $sth = $self->_mysqlQuery("SELECT * FROM `subscriptions_users` WHERE `from` = $id_from AND `to` = $id_to");
    return "subscribed" if $sth->rows();
    
    $self->_mysqlQueryDo("INSERT INTO `subscriptions_users` (`from`, `to`) VALUES ($id_from, $id_to)");

    return "ok";
}

sub subscribeToPost
{
    my ($self, $from, $to) = @_;
    $from = $self->_mysqlEscape($from);
    $to = int($to);

    my $sth = $self->_mysqlQuery("SELECT * FROM `posts` WHERE `order` = $to LIMIT 1");
    return "not exists" unless $sth->rows();

    my $sth_from = $self->_mysqlQuery("SELECT * FROM `users` WHERE `jid` = '$from' LIMIT 1");
    my $id_from = $sth_from->fetchrow_hashref()->{id};

    my $sth_to = $self->_mysqlQuery("SELECT * FROM `posts` WHERE `order` = $to LIMIT 1");
    my $id_to = $sth_to->fetchrow_hashref()->{id};

    my $sth_subscriptions = $self->_mysqlQuery("SELECT * FROM `subscriptions_posts` WHERE `from` = $id_from AND `to` = $id_to");
    unless($sth_subscriptions->rows()) {
        $self->_mysqlQueryDo("INSERT INTO `subscriptions_posts` (`from`, `to`) VALUES ($id_from, $id_to)");
    }

    return "ok";
}

sub getSubscribersToUser
{
    my ($self, $to) = @_;
    $to = $self->_mysqlEscape($to);

    my $sth = $self->_mysqlQuery("SELECT * FROM `users` WHERE `id` IN((SELECT `from` FROM `subscriptions_users` WHERE `to` = (SELECT `id` FROM `users` WHERE `jid` = '$to'))) ORDER BY `nick`");
    my @users = ();

    if($sth->rows()) {
        while(my $user = $sth->fetchrow_hashref()) {
            push(@users, $user);
        }
    }

    return @users;
}

sub getSubscribersToPost
{
    my ($self, $to) = @_;
    $to = int($to);

    my $sth = $self->_mysqlQuery("SELECT * FROM `users` WHERE `id` IN((SELECT `from` FROM `subscriptions_posts` WHERE `to` = (SELECT `id` FROM `posts` WHERE `order` = $to))) ORDER BY `nick`");
    my @users = ();

    if($sth->rows()) {
        while(my $user = $sth->fetchrow_hashref()) {
            push(@users, $user);
        }
    }

    return @users;
}

1;
