package IO::Moose::HandleImportTest;

use strict;
use warnings;

use parent 'Test::Unit::TestCase';
use Test::Assert ':all';

use IO::Handle;

use IO::Moose::Handle;


sub test_import_stdin {
    {
        package IO::Moose::HandleImportTest::TestStdin;
        IO::Moose::Handle->import('$STDIN');
    };
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestStdin::STDIN);
    assert_null($IO::Moose::HandleImportTest::TestStdin::STDOUT);
    assert_null($IO::Moose::HandleImportTest::TestStdin::STDERR);
};

sub test_import_stdout_stderr {
    {
        package IO::Moose::HandleImportTest::TestStdoutStderr;
        IO::Moose::Handle->import('$STDOUT', '$STDERR');
    };
    assert_null($IO::Moose::HandleImportTest::TestStdoutStderr::STDIN);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestStdoutStderr::STDOUT);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestStdoutStderr::STDERR);
};

sub test_import_std {
    {
        package IO::Moose::HandleImportTest::TestStd;
        IO::Moose::Handle->import(':std');
    };
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestStd::STDIN);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestStd::STDOUT);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestStd::STDERR);
};

sub test_import_all {
    {
        package IO::Moose::HandleImportTest::TestAll;
        IO::Moose::Handle->import(':all');
    };
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestAll::STDIN);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestAll::STDOUT);
    assert_isa('IO::Moose::Handle', $IO::Moose::HandleImportTest::TestAll::STDERR);
};

sub test_import_nothing {
    {
        package IO::Moose::HandleImportTest::TestNothing;
        IO::Moose::Handle->import();
    };
    assert_null($IO::Moose::HandleImportTest::TestNothing::STDIN);
    assert_null($IO::Moose::HandleImportTest::TestNothing::STDOUT);
    assert_null($IO::Moose::HandleImportTest::TestNothing::STDERR);
};

sub test_import_bad {
    assert_raises( ['Exception::Argument'], sub {
        package IO::Moose::HandleImportTest::TestBad;
        IO::Moose::Handle->import('bad');
    } );
    assert_null($IO::Moose::HandleImportTest::TestBad::STDIN);
    assert_null($IO::Moose::HandleImportTest::TestBad::STDOUT);
    assert_null($IO::Moose::HandleImportTest::TestBad::STDERR);
};

1;
