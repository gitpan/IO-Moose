#!/usr/bin/perl -I../lib

# Usage: uniq_func.pl < file

BEGIN { $IO::Moose::Handle::Debug = $ENV{DEBUG}; }

use IO::Moose::Handle;

my $stdin  = IO::Moose::Handle->new_from_fd( \*STDIN,  '<' );
my $stdout = IO::Moose::Handle->new_from_fd( \*STDOUT, '>' );

my $prev = '';
while (not eof $stdin) {
    my $line = <$stdin>;
    print $stdout $line if $line ne $prev;
    $prev = $line;
}

close $stdin;
close $stdout;
