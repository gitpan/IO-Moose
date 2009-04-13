package IO::Moose::Handle::ImportTest;

use Test::Unit::Lite;

use Moose;
extends 'Test::Unit::TestCase';

use Test::Assert ':all';

use IO::Handle;

use IO::Moose::Handle;


sub test_import_stdin {
    {
        package IO::Moose::Handle::ImportTest::TestStdin;
        IO::Moose::Handle->import('$STDIN');
    };
    no warnings 'once';
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestStdin::STDIN);
    assert_null($IO::Moose::Handle::ImportTest::TestStdin::STDOUT);
    assert_null($IO::Moose::Handle::ImportTest::TestStdin::STDERR);
};

sub test_import_stdout_stderr {
    {
        package IO::Moose::Handle::ImportTest::TestStdoutStderr;
        IO::Moose::Handle->import('$STDOUT', '$STDERR');
    };
    no warnings 'once';
    assert_null($IO::Moose::Handle::ImportTest::TestStdoutStderr::STDIN);
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestStdoutStderr::STDOUT);
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestStdoutStderr::STDERR);
};

sub test_import_std {
    {
        package IO::Moose::Handle::ImportTest::TestStd;
        IO::Moose::Handle->import(':std');
    };
    no warnings 'once';
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestStd::STDIN);
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestStd::STDOUT);
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestStd::STDERR);
};

sub test_import_all {
    {
        package IO::Moose::Handle::ImportTest::TestAll;
        IO::Moose::Handle->import(':all');
    };
    no warnings 'once';
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestAll::STDIN);
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestAll::STDOUT);
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestAll::STDERR);
};

sub test_import_nothing {
    {
        package IO::Moose::Handle::ImportTest::TestNothing;
        IO::Moose::Handle->import();
    };
    no warnings 'once';
    assert_null($IO::Moose::Handle::ImportTest::TestNothing::STDIN);
    assert_null($IO::Moose::Handle::ImportTest::TestNothing::STDOUT);
    assert_null($IO::Moose::Handle::ImportTest::TestNothing::STDERR);
};

sub test_import_bad {
    assert_raises( ['Exception::Argument'], sub {
        package IO::Moose::Handle::ImportTest::TestBad;
        IO::Moose::Handle->import('bad');
    } );
    no warnings 'once';
    assert_null($IO::Moose::Handle::ImportTest::TestBad::STDIN);
    assert_null($IO::Moose::Handle::ImportTest::TestBad::STDOUT);
    assert_null($IO::Moose::Handle::ImportTest::TestBad::STDERR);
};

sub test_import_into {
    {
        package IO::Moose::Handle::ImportTest::TestInto;
    };
    IO::Moose::Handle->import({into => 'IO::Moose::Handle::ImportTest::TestInto'}, ':all');
    no warnings 'once';
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestInto::STDIN);
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestInto::STDOUT);
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestInto::STDERR);
};

sub test_import_into_level {
    {
        package IO::Moose::Handle::ImportTest::TestIntoLevel;
        sub import {
            IO::Moose::Handle->import({into_level => 1}, ':all');
        };
    };
    {
        package IO::Moose::Handle::ImportTest::TestIntoLevel::Target;
        sub import {
            IO::Moose::Handle::ImportTest::TestIntoLevel->import;
        };
    };
    no warnings 'once';
    IO::Moose::Handle::ImportTest::TestIntoLevel::Target->import;
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestIntoLevel::Target::STDIN);
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestIntoLevel::Target::STDOUT);
    assert_isa('IO::Moose::Handle', $IO::Moose::Handle::ImportTest::TestIntoLevel::Target::STDERR);
};

1;
