#!/usr/bin/perl -d:Trace

use lib 'lib', '../lib';	

use IO::Moose::File;

foreach (1..10) {
    my @file = IO::Moose::File->new( file => $0, autochomp => 1 )->getlines;
};
