#!/usr/bin/perl -Ilib -I../lib

# Usage: uniq_oo.pl < file

use IO::Moose::Handle;

my $stdin  = IO::Moose::Handle->new( file => \*STDIN,  mode => 'r' );
my $stdout = IO::Moose::Handle->new( file => \*STDOUT, mode => 'w' );

my $prev = '';
while (not $stdin->eof) {
    my $line = $stdin->getline;
    $stdout->print($line) if $line ne $prev;
    $prev = $line;
};
