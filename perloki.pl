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

$SIG{INT} = \&destroyPerloki;
$SIG{TERM} = \&destroyPerloki;
$SIG{QUIT} = \&destroyPerloki;
$SIG{HUP} = \&destroyPerloki;

my $connect_result = $jabber->connect($perloki->{config}->{jabber});

destroyPerloki();

sub destroyPerloki
{
    $perloki->{storage}->disconnect() if $connect_result > 0;
    $jabber->disconnect();
    $perloki->{log}->close();

    exit 0;
}

exit 0;

