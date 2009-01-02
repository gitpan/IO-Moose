#!/usr/bin/perl -d:DProf

use lib 'lib', '../lib';	

use IO::Moose::File;

foreach (1..1000) {
    IO::Moose::File->new_tmpfile->say("OK");
};

print "tmon.out data collected. Call dprofpp\n";
