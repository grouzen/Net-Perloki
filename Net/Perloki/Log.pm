package Net::Perloki::Log;

use strict;
use utf8;

use FileHandle;

sub new
{
    my ($class, $self) = @_;

    if(!open(PLOG, ">>$self->{file}")) {
        print STDERR " $!\n";
        return undef;
    }

    PLOG->autoflush();

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

