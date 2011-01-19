package Net::Perloki::Log;

use strict;
use utf8;

use Exporter;

sub new
{
    my $class = shift;
    my $logfile = shift;
    my $self = { stdout => 0, @_ };

    if(!open(PLOG, ">>$logfile")) {
        print STDERR " $!\n";
        return undef;
    }

    return bless($self, $class);
}

sub write
{
    my ($self, $record) = @_;

    print PLOG localtime() . ": $record";

    if($self->{stdout}) {
        print localtime() . ": $record";
    }
}

sub close
{
    close(PLOG);
}

1;

