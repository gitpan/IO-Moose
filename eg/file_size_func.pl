#!/usr/bin/perl

use lib 'lib', '../lib';

# Usage: file_size.pl < file

{
    package My::IO;

    use Moose;

    extends 'IO::Moose::Handle';

    with 'IO::Moose::Seekable';
};


my $stdin = My::IO->new( file => \*STDIN, mode => 'r' );

$stdin->slurp;

print tell($stdin), "\n";

close $stdin;
