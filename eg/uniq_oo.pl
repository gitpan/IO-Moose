#!/usr/bin/perl -I../lib

# Usage: uniq_oo.pl < file

use IO::Moose::Handle;

$IO::Moose::Handle::Debug = $ENV{DEBUG};

my $stdin  = IO::Moose::Handle->new(fd=>\*STDIN,  mode=>'r');
my $stdout = IO::Moose::Handle->new(fd=>\*STDOUT, mode=>'w');

my $prev = '';
while (not $stdin->eof) {
    my $line = $stdin->getline;
    $stdout->print($line) if $line ne $prev;
    $prev = $line;
}
