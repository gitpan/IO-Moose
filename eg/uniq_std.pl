#!/usr/bin/perl -Ilib -I../lib

# Usage: uniq_std.pl < file

use IO::Moose::Handle ':std';

my $prev = '';
while (not $STDIN->eof) {
    my $line = $STDIN->getline;
    $STDOUT->print($line) if $line ne $prev;
    $prev = $line;
};
