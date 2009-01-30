package IO::Moose::HandleTest;

use strict;
use warnings;

use Test::Unit::Lite;
use parent 'Test::Unit::TestCase';

use Test::Assert ':all';

use Scalar::Util 'reftype', 'tainted';

use IO::Handle;

use IO::Moose::Handle;

{
    package IO::Moose::HandleTest::Test1;

    sub new {
        my ($class, $mode, $fd) = @_;
        my $fileno = fileno $fd;
        open my $fh, "$mode&=$fileno";
        bless $fh => $class;
    };
};

my ($filename_in, $fh_in, $obj, @vars);

sub set_up {
    $filename_in = __FILE__;

    open $fh_in, '<', $filename_in or Exception::IO->throw;

    $obj = IO::Moose::Handle->new;
    assert_isa('IO::Moose::Handle', $obj);
};

sub tear_down {
    $obj = undef;

    close $fh_in;
};

sub test___isa {
    my $obj = IO::Moose::Handle->new;
    assert_isa('IO::Handle', $obj);
    assert_isa('IO::Moose::Handle', $obj);
    assert_isa('Moose::Object', $obj);
    assert_isa('MooseX::GlobRef::Object', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test_fdopen_fh {
    $obj->fdopen($fh_in);
    assert_not_null($obj->fileno);
};

sub test_new_file_globref {
    my $obj = IO::Moose::Handle->new( file => $fh_in );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test_new_file_globref_strict_accessors {
    my $obj = IO::Moose::Handle->new( file => $fh_in, strict_accessors => 1 );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test_new_file_globref_copyfh {
    my $obj = IO::Moose::Handle->new( file => $fh_in, copyfh => 1 );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
    assert_equals($obj->fileno, fileno $fh_in);
};

sub test_new_file_globref_copyfh_strict_accessors {
    my $obj = IO::Moose::Handle->new( file => $fh_in, copyfh => 1, strict_accessors => 1 );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
    assert_equals($obj->fileno, fileno $fh_in);
};

sub test_new_file_io_handle_copyfh {
    my $io = IO::Handle->new_from_fd($fh_in, 'r');
    my $obj = IO::Moose::Handle->new( file => $io, copyfh => 1 );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
    assert_equals($obj->fileno, $io->fileno);
};

sub test_new_file_io_moose_handle_copyfh {
    my $io = IO::Moose::Handle->new_from_fd($fh_in, 'r');
    my $obj = IO::Moose::Handle->new( file => $io, copyfh => 1 );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
    assert_equals($obj->fileno, $io->fileno);
};

sub test_new_file_io_moose_handle_copyfh_strict_accessors {
    my $io = IO::Moose::Handle->new_from_fd($fh_in, 'r');
    my $obj = IO::Moose::Handle->new( file => $io, copyfh => 1, strict_accessors => 1 );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
    assert_equals($obj->fileno, $io->fileno);
};

sub test_new_file_mode {
    my $obj = IO::Moose::Handle->new( file => $fh_in, mode => 'r' );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test_new_open_tied {
    my $obj = IO::Moose::File->new( file => $filename_in, tied => 1 );
    assert_isa('IO::Moose::File', $obj);

    assert_equals("package IO::Moose::HandleTest;\n", $obj->readline);

    assert_equals("\n", <$obj>);
};

sub test_new_open_no_tied {
    my $obj = IO::Moose::File->new( file => $filename_in, tied => 0 );
    assert_isa('IO::Moose::File', $obj);

    assert_equals("package IO::Moose::HandleTest;\n", $obj->readline);

    assert_raises( ['Exception::Warning'], sub {
        <$obj>;
    } );
};

sub test_new_from_fd {
    my $obj = IO::Moose::Handle->new_from_fd($fh_in);
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test_new_from_fd_mode {
    my $obj = IO::Moose::Handle->new_from_fd($fh_in, 'r');
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test_new_from_fd_error {
    assert_raises( qr/does not pass the type constraint/, sub {
        IO::Moose::Handle->new_from_fd('badfd');
    } );
};

sub test_new_error_args {
    assert_raises( qr/does not pass the type constraint/, sub {
        IO::Moose::Handle->new( file => 'badfd' );
    } );

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->new( file => 1, copyfh => 1 );
    } );
};

sub test_fdopen_globref_obj {
    my $io = IO::Moose::HandleTest::Test1->new('<', $fh_in);
    assert_isa('IO::Moose::HandleTest::Test1', $io);
    $obj->fdopen($io);
    assert_not_null($obj->fileno);
};

sub test_fdopen_io_handle {
    my $io = IO::Handle->new_from_fd($fh_in, 'r');
    assert_isa('IO::Handle', $io);
    $obj->fdopen($io);
    assert_not_null($obj->fileno);
};

sub test_fdopen_io_moose_handle {
    my $io = IO::Moose::Handle->new_from_fd($fh_in, 'r');
    assert_isa('IO::Moose::Handle', $io);
    $obj->fdopen($io);
    assert_not_null($obj->fileno);
};

sub test_fdopen_fileno {
    my $fileno = fileno $fh_in;
    $obj->fdopen($fileno);
    assert_not_null($obj->fileno);
};

sub test_fdopen_glob {
    $obj->fdopen(\*STDIN);
    assert_not_null($obj->fileno);
};

sub test_fdopen_error_args {
    assert_raises( ['Exception::Argument'], sub {
        $obj->fdopen;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->fdopen($fh_in, '<', 'extra_arg');
    } );

    assert_raises( qr/does not pass the type constraint/, sub {
        $obj->fdopen('STRING');
    } );

    assert_raises( qr/does not pass the type constraint/, sub {
        no warnings 'once';
        $obj->fdopen(\*BADGLOB);
    } );

    assert_raises( qr/does not pass the type constraint/, sub {
        $obj->fdopen($fh_in, 'bad_flag');
    } );

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->fdopen;
    } );
};

sub test_opened {
    assert_false($obj->opened, '$obj->opened');

    $obj->fdopen($fh_in);
    assert_true($obj->opened, '$obj->opened');

    $obj->close;

    assert_false($obj->opened, '$obj->opened');
};

sub test_opened_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->opened;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->opened(1);
    } );
};

sub test_close_error_io {
    assert_raises( ['Exception::IO'], sub {
        $obj->close;
    } );
};

sub test_close_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->close;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->close(1);
    } );
};

sub test_slurp_from_fd_wantscalar_static_tainted {
    my $c = IO::Moose::Handle->slurp( file => $fh_in, tainted => 1 );
    assert_true(length $c > 1, 'length $c > 1');
    assert_true($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');

    if (${^TAINT}) {
        assert_true(tainted $c);
    };
};

sub test_slurp_from_fd_wantscalar_static_untainted {
    my $c = IO::Moose::Handle->slurp( file => $fh_in, tainted => 0 );
    assert_true(length $c > 1, 'length $c > 1');
    assert_true($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');

    if (${^TAINT}) {
        assert_false(tainted $c);
    };
};

sub test_slurp_from_fd_error_io {
    assert_raises( ['Exception::Fatal'], sub {
        IO::Moose::Handle->slurp( file => $fh_in, mode => '>' );
    } );
};

sub test_input_line_number_with_close {
    $obj->fdopen( $fh_in );
    my $c1 = $obj->slurp;
    my $l1 = length $c1;
    assert_num_not_equals(0, $l1);
    assert_equals(1, $obj->input_line_number);
    $obj->close;

    open $fh_in, '<', $filename_in or Exception::IO->throw;
    $obj->fdopen( $fh_in );
    my $c2 = $obj->slurp;
    my $l2 = length $c2;
    assert_num_not_equals(0, $l2);
    assert_equals(1, $obj->input_line_number);
};

sub test_input_line_number_without_close {
    $obj->fdopen( $fh_in );
    my $c1 = $obj->slurp;
    my $l1 = length $c1;
    assert_num_not_equals(0, $l1);
    assert_equals(1, $obj->input_line_number);

    open $fh_in, '<', $filename_in or Exception::IO->throw;
    $obj->fdopen( $fh_in );
    my $c2 = $obj->slurp;
    my $l2 = length $c2;
    assert_num_not_equals(0, $l2);
    assert_equals(2, $obj->input_line_number);
};

1;
