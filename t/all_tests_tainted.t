#!/usr/bin/perl

use 5.008;
use strict;
use warnings;

use Taint::Runtime 'enable';

BEGIN {
    if (eval { Devel::Cover->VERSION }) {
        print "1..0 # Skip Tainted mode doesn't work well with Devel::Cover";
        exit 0;
    };
};

use File::Spec;
use Cwd;

BEGIN {
    unshift @INC, map { /(.*)/; $1 } split(/:/, $ENV{PERL5LIB}) if defined $ENV{PERL5LIB} and ${^TAINT};

    my $cwd = ${^TAINT} ? do { local $_=getcwd; /(.*)/; $1 } : '.';
    unshift @INC, File::Spec->catdir($cwd, 'inc');
    unshift @INC, File::Spec->catdir($cwd, 'lib');
}

use Test::Unit::Lite 0.10;
use Test::Assert;

use Exception::Base max_arg_nums => 0, max_arg_len => 200, verbosity => 4;
use Exception::Warning '%SIG' => 'die', verbosity => 4;
use Exception::Died '%SIG', verbosity => 4;
use Exception::Assertion verbosity => 4;

Test::Unit::HarnessUnit->new->start('Test::Unit::Lite::AllTests');
