#!/usr/bin/perl -I../lib

# Usage: slurp < file

use IO::Handle::Moose;

$IO::Handle::Moose::Debug = $ENV{DEBUG};

print IO::Handle::Moose->slurp(\*STDIN);
