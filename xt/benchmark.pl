#!/usr/bin/perl

use lib 'lib', '../lib';

package My::CoreIO;
our $n = 0;
sub test {
    open my($f), $0;
    my @file;
    while (defined (my $line = <$f>)) {
        chomp $line;
	push @file, $line;
    }
    close $f;
    $n++;
}


package My::IOFile;
use IO::File;
our $n = 0;
sub test {
    my $io = IO::File->new($0);
    my @file = $io->getlines;
    foreach (@file) {
	chomp;
    }
    $n++;
}


package My::IOMooseFile;
use IO::Moose::File;
our $n = 0;
sub test {
    my @file = IO::Moose::File->new( file => $0, autochomp => 1 )->getlines;
    $n++;
}



package main;

use Benchmark ':all';

my $result = timethese(-1, {
    '1_CoreIO'               => sub { My::CoreIO::test; },
    '2_IOFile'               => sub { My::IOFile::test; },
    '3_IOMooseFile'          => sub { My::IOMooseFile::test; },
});

cmpthese($result);
