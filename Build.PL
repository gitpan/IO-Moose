#!/usr/bin/perl

use 5.006;
use Module::Build;

use strict;
use warnings;

my $build = Module::Build->new(
    module_name => 'IO::Moose',
    dist_version_from => 'lib/IO/Moose/Handle.pm',
    dist_author => 'Piotr Roszatycki <dexter@debian.org>',
    license => 'perl',
    requires => {
        'perl'                    => 5.006,
        'Exception::Base'         => 0.12,
        'Exception::System'       => 0.07,
        'File::Stat::Moose'       => 0,
	'MooseX::GlobRef::Object' => 0.02,
    },
    optional => {
    },
    build_requires => {
        'Test::Unit::Lite'        => 0.09,
    },
    create_makefile_pl => 'traditional',
    create_readme => 1,
    recursive_test_files => 1,
    add_to_cleanup => [
        'META.yml', '*.bak', '*.gz', '*.tgz', '*.ppd',
        'Makefile.PL', 'Makefile', 'pm_to_blib', 'README', 'cover_db',
        'IO-Moose-*',
    ],
);

$build->create_build_script;
