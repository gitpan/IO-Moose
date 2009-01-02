#!/usr/bin/perl -d:DProf

use lib 'lib', '../lib';	

use IO::Moose::File;

foreach (1..1000) {
    my @file = IO::Moose::File->new( file => $0, autochomp => 1 )->getlines;
};

print "tmon.out data collected. Call dprofpp\n";
