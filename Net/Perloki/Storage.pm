package Net::Perloki::Storage;

use strict;
use utf8;

use Net::Perloki;

sub new
{
    shift;
    my $p = shift;

    return $p->{class}->new($p);
}

1;
