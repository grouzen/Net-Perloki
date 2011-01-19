package Net::Perloki::Storage;

use strict;
use utf8;

use Net::Perloki;

sub new
{
    shift;
    my $p = { @_ };

    return $p->{storage}->new($p->{params});
}

1;
