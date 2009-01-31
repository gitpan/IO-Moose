#!/usr/bin/perl

use 5.008;

use strict;
use warnings;

use Module::Build;

my $module = 'IO::Moose';

(my $dist = $module) =~ s/::/-/g;

my $build = Module::Build->new(
    module_name => $module,
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
        'MooseX::GlobRef::Object' => 0.05,
        'Task::Weaken'            => 0,
        'Test::Assert'            => 0.04,
    },
    optional => {
        'Smart::Comments'         => 0,
    },
    build_requires => {
        'parent'                  => 0,
        'Exception::Warning'      => 0,
        'Taint::Runtime'          => 0,
        'Test::Unit::Lite'        => 0.11,
    },
    create_makefile_pl => 'traditional',
    create_readme => 1,
    create_license => 1,
    sign => 1,
    recursive_test_files => 1,
    add_to_cleanup => [
        '*.bak', '*.gz', '*.tgz', '*.ppd', '*.ppmx', '*.deb', '*.bat',
        'Makefile', 'pm_to_blib', 'cover_db', 'Debian_CPANTS.txt',
        "$dist-*",
    ],
    meta_merge => {
        resources => {
            bugtracker => "http://rt.cpan.org/NoAuth/Bugs.html?Dist=$dist",
            repository => "http://dexter-cpan.googlecode.com/svn/$dist",
        },
    },
);

$build->create_build_script;
