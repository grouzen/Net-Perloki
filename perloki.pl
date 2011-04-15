#!/usr/bin/perl

use strict;

use Net::Perloki;
use Net::Perloki::Jabber;

my $configfile = 'perloki.yml';
if($#ARGV > -1) {
    $configfile = $ARGV[0];
}

my $perloki = Net::Perloki->new($configfile);
unless($perloki) {
    exit 1;
}

$SIG{INT} = \&destroyPerloki;
$SIG{TERM} = \&destroyPerloki;
$SIG{QUIT} = \&destroyPerloki;
$SIG{HUP} = \&destroyPerloki;

my $jabber = Net::Perloki::Jabber->new($perloki->{config}->{jabber});

my $process_result = $jabber->{xmpp}->process();

destroyPerloki();

sub destroyPerloki
{
    $perloki->{storage}->disconnect();
    $jabber->{xmpp}->disconnect() if defined($process_result) && $process_result > 0;
    $perloki->{log}->close();

    exit 0;
}
