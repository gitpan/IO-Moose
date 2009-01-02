package IO::Moose::HandleTest;

use strict;
use warnings;

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
    my $obj = IO::Moose::File->new;
    assert_isa('IO::Moose::Handle', $obj);
    assert_isa('IO::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test_fdopen_fh {
    $obj->fdopen($fh_in);
    assert_not_null($obj->fileno);
};

sub test_new_file {
    my $obj = IO::Moose::Handle->new( file => $fh_in );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test_new_file_mode {
    my $obj = IO::Moose::Handle->new( file => $fh_in, mode => 'r' );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
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

sub test_new_fd_deprecated {
    assert_raises( ['Exception::Warning'], sub {
        IO::Moose::Handle->new( fd => $fh_in );
    } );

    local $SIG{__WARN__} = sub { };
    my $obj = IO::Moose::Handle->new( fd => $fh_in );
    assert_isa('IO::Moose::Handle', $obj);
};

sub test_new_error_args {
    assert_raises( qr/does not pass the type constraint/, sub {
        IO::Moose::Handle->new( file => 'badfd' );
    } );
};

sub test_fdopen_io_handle_moose {
    $obj->fdopen($obj);
    assert_not_null($obj->fileno);
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

1;
