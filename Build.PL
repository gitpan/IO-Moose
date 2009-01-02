#!/usr/bin/perl

use 5.008;
use Module::Build;

use strict;
use warnings;

my $build = Module::Build->new(
    module_name => 'IO::Moose',
    dist_author => 'Piotr Roszatycki <dexter@debian.org>',
    license => 'perl',
    requires => {
        'perl'                    => 5.008,
        'constant::boolean'       => 0,
        'maybe'                   => 0,
        'Exception::Argument'     => 0,
        'Exception::Base'         => 0.21,
        'Exception::Died'         => 0,
        'Exception::Fatal'        => 0,
        'Exception::System'       => 0.11,
        'File::Stat::Moose'       => 0.03,
        'MooseX::GlobRef::Object' => 0.03,
        'Task::Weaken'            => 0,
        'Test::Assert'            => 0.04,
    },
    optional => {
        'Smart::Comments'         => 0,
    },
    build_requires => {
        'parent'                  => 0,
        'Exception::Warning'      => 0,
        'Test::Unit::Lite'        => 0.11,
    },
    create_makefile_pl => 'traditional',
    create_readme => 1,
    recursive_test_files => 1,
    add_to_cleanup => [
        'Makefile.PL', 'Makefile', 'pm_to_blib', 'README', 'cover_db',
        'Debian_CPANTS.txt',
        'Test-Assert-*',
        'IO-Moose-*',
    ],
);

$build->create_build_script;
