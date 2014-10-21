#!/usr/bin/perl

use strict;
use warnings;

use File::Basename;
use File::Spec;
use Cwd;

BEGIN {
    chdir dirname(__FILE__) or die "$!";
    chdir '..' or die "$!";

    unshift @INC, map { /(.*)/; $1 } split(/:/, $ENV{PERL5LIB}) if defined $ENV{PERL5LIB} and ${^TAINT};

    my $cwd = ${^TAINT} ? do { local $_=getcwd; /(.*)/; $1 } : '.';
    unshift @INC, File::Spec->catdir($cwd, 'inc');
    unshift @INC, File::Spec->catdir($cwd, 'lib');
}

use Test::Unit::Lite;

use Exception::Base
    max_arg_nums => 0, max_arg_len => 200, verbosity => 3,
    '+ignore_package' => [ qr/^Test::Unit::/, 'File::Find', 'main' ];
use Exception::Warning '%SIG' => 'die';
use Exception::Died    '%SIG';

all_tests;
