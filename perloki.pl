#!/usr/bin/perl

use strict;

use Net::Perloki;

my $configfile = 'perloki.yml';
if($#ARGV > -1) {
    $configfile = $ARGV[0];
}

my $perloki = Net::Perloki->new($configfile);
unless($perloki) {
    exit 1;
}
my $jabber = Net::Perloki::Jabber->new();

$SIG{INT} = \&quitWithSignal;
$SIG{TERM} = \&quitWithSignal;
$SIG{QUIT} = \&quitWithSignal;
$SIG{HUP} = \&quitWithSignal;

my $connect_result = $jabber->connect($perloki->{config}->{jabber});
unless($connect_result) {
    quitWithSignal();
}

sub quitWithSignal
{
    $perloki->{storage}->disconnect() if $connect_result > 0;
    $jabber->disconnect();
    $perloki->{log}->close();

    exit 0;
}

exit 0;

