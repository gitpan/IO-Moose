package IO::Moose::Handle::Test;

use Test::Unit::Lite;

use Moose;
extends 'Test::Unit::TestCase';

with 'IO::Moose::ReadableTestRole';

use Test::Assert ':all';

use Class::Inspector;
use Scalar::Util 'reftype', 'tainted';

use IO::Handle;

use IO::Moose::Handle;

{
    package IO::Moose::Handle::Test::Test1;

    sub new {
        my ($class, $mode, $fd) = @_;
        my $fileno = fileno $fd;
        open my $fh, "$mode&=$fileno";
        bless $fh => $class;
    };
};

sub test___isa {
    my ($self) = @_;
    assert_isa('IO::Handle', $self->obj);
    assert_isa('IO::Moose::Handle', $self->obj);
    assert_isa('Moose::Object', $self->obj);
    assert_isa('MooseX::GlobRef::Object', $self->obj);
    assert_equals('GLOB', reftype $self->obj);
};

sub test___api {
    my @api = grep { ! /^_/ } @{ Class::Inspector->functions('IO::Moose::Handle') };
    assert_deep_equals( [ qw{
        BUILD
        CLOSE
        DESTROY
        EOF
        FILENO
        GETC
        PRINT
        PRINTF
        READ
        READLINE
        TIEHANDLE
        UNTIE
        WRITE
        autochomp
        autoflush
        blocking
        clear_format_formfeed
        clear_format_line_break_characters
        clear_input_record_separator
        clear_output_field_separator
        clear_output_record_separator
        clearerr
        close
        copyfh
        eof
        error
        fdopen
        fh
        file
        fileno
        flush
        format_formfeed
        format_line_break_characters
        format_lines_left
        format_lines_per_page
        format_name
        format_page_number
        format_top_name
        format_write
        getc
        getline
        getlines
        has_file
        has_format_formfeed
        has_format_line_break_characters
        has_input_record_separator
        has_mode
        has_output_field_separator
        has_output_record_separator
        import
        input_line_number
        input_record_separator
        meta
        mode
        new
        new_from_fd
        opened
        output_autoflush
        output_field_separator
        output_record_separator
        print
        printf
        printflush
        read
        readline
        say
        slurp
        stat
        strict_accessors
        sync
        sysread
        syswrite
        tainted
        tied
        truncate
        ungetc
        untaint
        write
    } ], \@api );
};

sub test_fdopen_fh {
    my ($self) = @_;
    $self->obj->fdopen($self->fh_in);
    assert_not_null($self->obj->fileno);
};

sub test_new_file_globref {
    my ($self) = @_;
    my $obj = IO::Moose::Handle->new( file => $self->fh_in );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test_new_file_globref_strict_accessors {
    my ($self) = @_;
    my $obj = IO::Moose::Handle->new( file => $self->fh_in, strict_accessors => 1 );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test_new_file_globref_copyfh {
    my ($self) = @_;
    my $obj = IO::Moose::Handle->new( file => $self->fh_in, copyfh => 1 );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
    assert_equals($obj->fileno, fileno $self->fh_in);
};

sub test_new_file_globref_copyfh_strict_accessors {
    my ($self) = @_;
    my $obj = IO::Moose::Handle->new( file => $self->fh_in, copyfh => 1, strict_accessors => 1 );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
    assert_equals($obj->fileno, fileno $self->fh_in);
};

sub test_new_file_io_handle_copyfh {
    my ($self) = @_;
    my $io = IO::Handle->new_from_fd($self->fh_in, 'r');
    my $obj = IO::Moose::Handle->new( file => $io, copyfh => 1 );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
    assert_equals($obj->fileno, $io->fileno);
};

sub test_new_file_io_moose_handle_copyfh {
    my ($self) = @_;
    my $io = IO::Moose::Handle->new_from_fd($self->fh_in, 'r');
    my $obj = IO::Moose::Handle->new( file => $io, copyfh => 1 );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
    assert_equals($obj->fileno, $io->fileno);
};

sub test_new_file_io_moose_handle_copyfh_strict_accessors {
    my ($self) = @_;
    my $io = IO::Moose::Handle->new_from_fd($self->fh_in, 'r');
    my $obj = IO::Moose::Handle->new( file => $io, copyfh => 1, strict_accessors => 1 );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
    assert_equals($obj->fileno, $io->fileno);
};

sub test_new_file_mode {
    my ($self) = @_;
    my $obj = IO::Moose::Handle->new( file => $self->fh_in, mode => 'r' );
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test_new_open_tied {
    my ($self) = @_;
    my $obj = IO::Moose::File->new( file => $self->filename_in, autochomp => 1, tied => 1 );
    assert_isa('IO::Moose::File', $obj);

    assert_matches(qr/^package IO::Moose::/, $obj->readline);

    assert_equals("", <$obj>);
};

sub test_new_open_no_tied {
    my ($self) = @_;
    my $obj = IO::Moose::File->new( file => $self->filename_in, autochomp => 1, tied => 0 );
    assert_isa('IO::Moose::File', $obj);

    assert_matches(qr/^package IO::Moose::/, $obj->readline);

    assert_equals("\n", <$obj>);
};

sub test_new_from_fd {
    my ($self) = @_;
    my $obj = IO::Moose::Handle->new_from_fd($self->fh_in);
    assert_not_null($obj->fileno);
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test_new_from_fd_mode {
    my ($self) = @_;
    my $obj = IO::Moose::Handle->new_from_fd($self->fh_in, 'r');
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
    my ($self) = @_;
    my $io = IO::Moose::Handle::Test::Test1->new('<', $self->fh_in);
    assert_isa('IO::Moose::Handle::Test::Test1', $io);
    $self->obj->fdopen($io);
    assert_not_null($self->obj->fileno);
};

sub test_fdopen_io_handle {
    my ($self) = @_;
    my $io = IO::Handle->new_from_fd($self->fh_in, 'r');
    assert_isa('IO::Handle', $io);
    $self->obj->fdopen($io);
    assert_not_null($self->obj->fileno);
};

sub test_fdopen_io_moose_handle {
    my ($self) = @_;
    my $io = IO::Moose::Handle->new_from_fd($self->fh_in, 'r');
    assert_isa('IO::Moose::Handle', $io);
    $self->obj->fdopen($io);
    assert_not_null($self->obj->fileno);
};

sub test_fdopen_fileno {
    my ($self) = @_;
    my $fileno = fileno $self->fh_in;
    $self->obj->fdopen($fileno);
    assert_not_null($self->obj->fileno);
};

sub test_fdopen_glob {
    my ($self) = @_;
    $self->obj->fdopen(\*STDIN);
    assert_not_null($self->obj->fileno);
};

sub test_fdopen_error_args {
    my ($self) = @_;
    assert_raises( ['Exception::Argument'], sub {
        $self->obj->fdopen;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->fdopen($self->fh_in, '<', 'extra_arg');
    } );

    assert_raises( qr/does not pass the type constraint/, sub {
        $self->obj->fdopen('STRING');
    } );

    assert_raises( qr/does not pass the type constraint/, sub {
        no warnings 'once';
        $self->obj->fdopen(\*BADGLOB);
    } );

    assert_raises( qr/does not pass the type constraint/, sub {
        $self->obj->fdopen($self->fh_in, 'bad_flag');
    } );

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->fdopen;
    } );
};

sub test_opened {
    my ($self) = @_;
    assert_false($self->obj->opened, '$self->obj->opened');

    $self->obj->fdopen($self->fh_in);
    assert_true($self->obj->opened, '$self->obj->opened');

    $self->obj->close;

    assert_false($self->obj->opened, '$self->obj->opened');
};

sub test_opened_error_args {
    my ($self) = @_;
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->opened;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->opened(1);
    } );
};

sub test_close_error_io {
    my ($self) = @_;
    assert_raises( ['Exception::IO'], sub {
        $self->obj->close;
    } );
};

sub test_close_error_args {
    my ($self) = @_;
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->close;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->close(1);
    } );
};

sub test_slurp_from_fd_wantscalar_static_tainted {
    my ($self) = @_;
    my $c = IO::Moose::Handle->slurp( file => $self->fh_in, tainted => 1 );
    assert_true(length $c > 1, 'length $c > 1');
    assert_true($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');

    if (${^TAINT}) {
        assert_true(tainted $c);
    };
};

sub test_slurp_from_fd_wantscalar_static_untainted {
    my ($self) = @_;
    my $c = IO::Moose::Handle->slurp( file => $self->fh_in, tainted => 0 );
    assert_true(length $c > 1, 'length $c > 1');
    assert_true($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');

    if (${^TAINT}) {
        assert_false(tainted $c);
    };
};

sub test_slurp_from_fd_error_io {
    my ($self) = @_;
    assert_raises( ['Exception::Fatal'], sub {
        IO::Moose::Handle->slurp( file => $self->fh_in, mode => '>' );
    } );
};

sub test_input_line_number_with_close {
    my ($self) = @_;
    $self->obj->fdopen( $self->fh_in );
    my $c1 = $self->obj->slurp;
    my $l1 = length $c1;
    assert_num_not_equals(0, $l1);
    assert_equals(1, $self->obj->input_line_number);
    $self->obj->close;

    open $self->fh_in, '<', $self->filename_in or Exception::IO->throw;
    $self->obj->fdopen( $self->fh_in );
    my $c2 = $self->obj->slurp;
    my $l2 = length $c2;
    assert_num_not_equals(0, $l2);
    assert_equals(1, $self->obj->input_line_number);
};

sub test_input_line_number_without_close {
    my ($self) = @_;
    $self->obj->fdopen( $self->fh_in );
    my $c1 = $self->obj->slurp;
    my $l1 = length $c1;
    assert_num_not_equals(0, $l1);
    assert_equals(1, $self->obj->input_line_number);

    open $self->fh_in, '<', $self->filename_in or Exception::IO->throw;
    $self->obj->fdopen( $self->fh_in );
    my $c2 = $self->obj->slurp;
    my $l2 = length $c2;
    assert_num_not_equals(0, $l2);
    assert_equals(2, $self->obj->input_line_number);
};

1;
