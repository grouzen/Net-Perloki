package Net::Perloki;

use strict;
use utf8;

use YAML::Tiny;
use Net::Perloki::Jabber;
use Net::Perloki::Storage;
use Net::Perloki::Mysql;
use Net::Perloki::Commands;
use Net::Perloki::Log;

my $singleton = undef;

sub new
{
    unless($singleton) {
        my $class = shift;
        my $config = shift;
        
        my $yaml = YAML::Tiny->new();
        $yaml = YAML::Tiny->read($config);
        if(!$yaml) {
            print STDERR "YAML::Tiny error: " . YAML::Tiny->errstr() . "\n";
            return undef;
        }
        
        my $self = { config => $yaml->[0] };
        
        $singleton = bless($self, $class);

        $self->{log} = Net::Perloki::Log->new($self->{config}->{logfile});
        return undef unless $self->{log};

        $self->{storage} = Net::Perloki::Storage->new($self->{config}->{storage});
        return undef unless $self->{storage}->connect();

        $self->{commands} = Net::Perloki::Commands->new();
    }
    
    return $singleton;
}

1;
