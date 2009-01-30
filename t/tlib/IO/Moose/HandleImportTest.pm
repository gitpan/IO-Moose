package IO::Moose::HandleImportTest;

use strict;
use warnings;

use Test::Unit::Lite;
use parent 'Test::Unit::TestCase';

use Test::Assert ':all';

use IO::Handle;

use IO::Moose::Handle;


sub test_import_stdin {
    {
        package IO::Moose::HandleImportTest::TestStdin;
        IO::Moose::Handle->import('$STDIN');
    };
    no warnings 'once';
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestStdin::STDIN);
    assert_null($IO::Moose::HandleImportTest::TestStdin::STDOUT);
    assert_null($IO::Moose::HandleImportTest::TestStdin::STDERR);
};

sub test_import_stdout_stderr {
    {
        package IO::Moose::HandleImportTest::TestStdoutStderr;
        IO::Moose::Handle->import('$STDOUT', '$STDERR');
    };
    no warnings 'once';
    assert_null($IO::Moose::HandleImportTest::TestStdoutStderr::STDIN);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestStdoutStderr::STDOUT);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestStdoutStderr::STDERR);
};

sub test_import_std {
    {
        package IO::Moose::HandleImportTest::TestStd;
        IO::Moose::Handle->import(':std');
    };
    no warnings 'once';
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestStd::STDIN);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestStd::STDOUT);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestStd::STDERR);
};

sub test_import_all {
    {
        package IO::Moose::HandleImportTest::TestAll;
        IO::Moose::Handle->import(':all');
    };
    no warnings 'once';
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestAll::STDIN);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestAll::STDOUT);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestAll::STDERR);
};

sub test_import_nothing {
    {
        package IO::Moose::HandleImportTest::TestNothing;
        IO::Moose::Handle->import();
    };
    no warnings 'once';
    assert_null($IO::Moose::HandleImportTest::TestNothing::STDIN);
    assert_null($IO::Moose::HandleImportTest::TestNothing::STDOUT);
    assert_null($IO::Moose::HandleImportTest::TestNothing::STDERR);
};

sub test_import_bad {
    assert_raises( ['Exception::Argument'], sub {
        package IO::Moose::HandleImportTest::TestBad;
        IO::Moose::Handle->import('bad');
    } );
    no warnings 'once';
    assert_null($IO::Moose::HandleImportTest::TestBad::STDIN);
    assert_null($IO::Moose::HandleImportTest::TestBad::STDOUT);
    assert_null($IO::Moose::HandleImportTest::TestBad::STDERR);
};

sub test_import_into {
    {
        package IO::Moose::HandleImportTest::TestInto;
    };
    IO::Moose::Handle->import({into => 'IO::Moose::HandleImportTest::TestInto'}, ':all');
    no warnings 'once';
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestInto::STDIN);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestInto::STDOUT);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestInto::STDERR);
};

sub test_import_into_level {
    {
        package IO::Moose::HandleImportTest::TestIntoLevel;
        sub import {
            IO::Moose::Handle->import({into_level => 1}, ':all');
        };
    };
    {
        package IO::Moose::HandleImportTest::TestIntoLevel::Target;
        sub import {
            IO::Moose::HandleImportTest::TestIntoLevel->import;
        };
    };
    no warnings 'once';
    IO::Moose::HandleImportTest::TestIntoLevel::Target->import;
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestIntoLevel::Target::STDIN);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestIntoLevel::Target::STDOUT);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestIntoLevel::Target::STDERR);
};

1;
