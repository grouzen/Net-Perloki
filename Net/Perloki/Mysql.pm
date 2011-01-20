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
    my ($self, $p) = @_;

    my $dsn = "DBI:mysql:database=$p->{dbname};host=$p->{dbhost};port=$p->{dbport}";
    $self->{dbh} = DBI->connect($dsn, $p->{dbuser}, $p->{dbpassword}, 
                                {RaiseError => 1, AutoCommit => 1, mysql_enable_utf8 => 1});
    if(!$self->{dbh}) {
        sleep(1);
        $self->{dbh} = DBI->connect($dsn, $p->{dbuser}, $p->{dbpassword},
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
    my $self = shift;
    $self->{dbh}->disconnect() if defined($self->{dbh});
}

sub _mysqlQuery
{
    my ($self, $query) = @_;

    my $sth = $self->{dbh}->prepare($query);
    return $sth if $sth->execute();

    $self->connect($self->{params});
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

    $self->connect($self->{params});
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

    $self->_mysqlQueryDo("UPDATE `users` SET `nick` = '$nick' WHERE `jid` = '$from' LIMIT 1");
}

sub getLastPublic
{
    my $self = shift;
    
    my $sth = $self->_mysqlQuery("SELECT * FROM `posts` `p` LEFT JOIN `users` `u` ON `p`.`users_id` = `u`.`id` WHERE `p`.`deleted` = 0 GROUP BY `p`.`order` LIMIT 10");
    return undef unless $sth;
    
    my @posts = ();

    if($sth->rows()) {
        for(my $i = 0; my $post = $sth->fetchrow_hashref(); $i++) {
            $posts[$i] = $post;
        }
    }

    return @posts;
}

sub getPost
{
    my ($self, $order) = @_;

    my $sth = $self->_mysqlQuery("SELECT * FROM `posts` `p` LEFT JOIN `users` `u` ON `p`.`users_id` = `u`.`id` WHERE `p`.`order` = $order AND `p`.`deleted` = 0 LIMIT 1");
    return undef unless $sth;

    return $sth->fetchrow_hashref();
}

sub addPost
{
    my ($self, $from, $text) = @_;
    $from = $self->_mysqlEscape($from);
    $text = $self->_mysqlEscape($text);
    
    my $sth_order = $self->_mysqlQuery("SELECT * FROM `posts`");
    return undef unless $sth_order;
    my $order = $sth_order->rows() + 1;

    my $sth_users_id = $self->_mysqlQuery("SELECT * FROM `users` WHERE `jid` = '$from' AND `deleted` = 0 LIMIT 1");
    return undef unless $sth_users_id;
    my $users_id = $sth_users_id->fetchrow_hashref()->{id};

    $self->_mysqlQueryDo("INSERT INTO `posts` (`order`, `text`, `users_id`) VALUES ($order, '$text', $users_id)");

    return $self->getPost($order);
}

1;
