#!/usr/bin/perl -I../lib

# Usage: file_size.pl < file

BEGIN { $IO::Moose::Seekable::Debug = $ENV{DEBUG}; }


package My::IO;

use Moose;

extends 'IO::Moose::Handle';

with 'IO::Moose::Seekable';


package main;

my $stdin = My::IO->new( fd=>\*STDIN, mode=>'r' );

$stdin->slurp;

print $stdin->tell, "\n";
