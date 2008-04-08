#!/usr/bin/perl -I../lib

# Usage: file_size.pl < file

package My::IO;

use Moose;

extends 'IO::Moose::Handle';

with 'IO::Moose::Seekable';


package main;

{ no warnings; $IO::Moose::Seekable::Debug = $ENV{DEBUG}; }

my $stdin = new My::IO fd=>\*STDIN, mode=>'r';

$stdin->slurp;

print tell($stdin), "\n";

close $stdin;
