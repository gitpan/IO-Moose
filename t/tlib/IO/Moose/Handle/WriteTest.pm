package IO::Moose::Handle::WriteTest;

use Test::Unit::Lite;

use Moose;
extends 'Test::Unit::TestCase';

with 'IO::Moose::WritableOpenedTestRole';

use Test::Assert ':all';

use Scalar::Util 'reftype', 'tainted';

use IO::Moose::Handle;

sub test_eof_empty_file {
    my ($self) = @_;

    # $self->fh_out is already opened by set_up
    close $self->fh_out or Exception::IO->throw;
    open my $fh_in, '<', $self->filename_out or Exception::IO->throw;

    $self->obj->close;
    assert_false($self->obj->opened);

    $self->obj->fdopen($fh_in, 'r');
    assert_not_null($self->obj->fileno);

    assert_true($self->obj->eof);
    $self->obj->close;

    assert_true($self->obj->eof);
};

sub test_eof_tied_empty_file {
    my ($self) = @_;

    # $self->fh_out is already opened by set_up
    close $self->fh_out or Exception::IO->throw;
    open my $fh_in, '<', $self->filename_out or Exception::IO->throw;

    $self->obj->close;
    assert_false($self->obj->opened);

    $self->obj->fdopen($fh_in, 'r');
    assert_not_null($self->obj->fileno);

    assert_true(eof $self->obj);
    $self->obj->close;

    assert_true(eof $self->obj);
};

sub test_eof_error_io {
    my ($self) = @_;

    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->eof;
    } );
};

sub test_print {
    my ($self) = @_;

    assert_not_null($self->obj->print('a'));
    assert_not_null($self->obj->print('b'));
    assert_not_null($self->obj->print('c'));

    $self->obj->close or Exception::IO->throw;

    open my $fh_in, '<', $self->filename_out or Exception::IO->throw;
    my $content = <$fh_in>;
    close $fh_in;
    assert_equals('abc', $content);

    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->print('WARN');
    } );
};

sub test_print_tied {
    my ($self) = @_;

    assert_not_null(print { $self->obj } 'a');
    assert_not_null(print { $self->obj } 'b');
    assert_not_null(print { $self->obj } 'c');

    $self->obj->close or Exception::IO->throw;

    open my $fh_in, '<', $self->filename_out or Exception::IO->throw;
    my $content = <$fh_in>;
    close $fh_in;
    assert_equals('abc', $content);

    assert_raises( ['Exception::Fatal'], sub {
        print { $self->obj } 'WARN';
    } );
};

sub test_print_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->print;
    } );
};

sub test_printf {
    my ($self) = @_;

    assert_not_null($self->obj->printf('%s', 'a'));
    assert_not_null($self->obj->printf('%c', ord('b')));
    assert_not_null($self->obj->printf('c'));

    $self->obj->close or Exception::IO->throw;

    open my $fh_in, '<', $self->filename_out or Exception::IO->throw;
    my $content = <$fh_in>;
    close $fh_in;
    assert_equals('abc', $content);

    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->printf('WARN');
    } );
};

sub test_printf_tied {
    my ($self) = @_;

    assert_not_null(printf { $self->obj } '%s', 'a');
    assert_not_null(printf { $self->obj } '%c', ord('b'));
    assert_not_null(printf { $self->obj } 'c');

    $self->obj->close or Exception::IO->throw;

    open my $fh_in, '<', $self->filename_out or Exception::IO->throw;
    my $content = <$fh_in>;
    close $fh_in;
    assert_equals('abc', $content);

    assert_raises( ['Exception::Fatal'], sub {
        printf { $self->obj } 'WARN';
    } );
};

sub test_printf_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->printf;
    } );
};

sub test_format_write_format_name {
    my ($self) = @_;

    our $format_content = "content\n" x 5;

    format FORMAT_TEST1_TOP =
@||||||||||||||||||||||||||
"header"
.

    format FORMAT_TEST1 =
@<<<<<<   @||||||   @>>>>>>
"left",   "middle", "right"
@*
$format_content
.

    my $old1 = $self->obj->format_lines_per_page(3);
    assert_equals(3, $self->obj->format_lines_per_page);
    my $old2 = $self->obj->format_lines_left(5);
    assert_equals(5, $self->obj->format_lines_left);
    my $old3 = $self->obj->format_formfeed(']');
    assert_equals(']', $self->obj->format_formfeed);

    $self->obj->format_write(__PACKAGE__ . '::FORMAT_TEST1');

    my $prev1 = $self->obj->format_lines_per_page;
    assert_equals(3, $prev1);

    my $prev2 = $self->obj->format_lines_per_page($old1);
    assert_equals(3, $prev2);

    $self->obj->close;

    open my $fh_in, '<', $self->filename_out;
    read $fh_in, (my $content), 99999;
    close $fh_in;
    my $string = "          header\nleft      middle      right\ncontent\n]"
               . "          header\ncontent\ncontent\n]"
               . "          header\ncontent\ncontent\n";
    assert_equals($string, $content);

    # Called on closed fh
    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->format_write(__PACKAGE__ . '::FORMAT_TEST1');
    } );
};

sub test_format_write_error_not_a_format {
    my ($self) = @_;

    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->format_write;
    } );
};

sub test_format_write_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->format_write;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->format_write(1, 2);
    } );
};

sub test_output_record_separator {
    my ($self) = @_;

    my $old1 = IO::Moose::Handle->output_record_separator(':');
    assert_equals(':', IO::Moose::Handle->output_record_separator);

    assert_not_null($self->obj->print('a'));
    assert_not_null($self->obj->print('b'));

    my $old2 = $self->obj->output_record_separator('-');
    assert_equals('-', $self->obj->output_record_separator);

    assert_not_null($self->obj->print('c'));
    assert_not_null($self->obj->print('d'));

    my $prev1 = IO::Moose::Handle->output_record_separator;
    assert_equals(':', $prev1);

    my $prev2 = $self->obj->output_record_separator;
    assert_equals('-', $prev2);

    $prev1 = IO::Moose::Handle->output_record_separator($old1);
    assert_equals(':', $prev1);

    $prev2 = $self->obj->output_record_separator($old2);
    assert_equals('-', $prev2);

    assert_not_null($self->obj->print('e'));
    assert_not_null($self->obj->print('f'));

    $self->obj->output_record_separator('!');
    $self->obj->clear_output_record_separator;

    assert_not_null($self->obj->print('g'));
    assert_not_null($self->obj->print('h'));

    $self->obj->close or Exception::IO->throw;

    open my $fh_in, '<', $self->filename_out;
    read $fh_in, (my $content), 99999;
    close $fh_in;
    assert_equals('a:b:c-d-efgh', $content);
};

sub test_output_field_separator {
    my ($self) = @_;

    my $old1 = IO::Moose::Handle->output_field_separator(':');
    assert_equals(':', IO::Moose::Handle->output_field_separator);

    assert_not_null($self->obj->print('a', 'b'));

    my $old2 = $self->obj->output_field_separator('-');
    assert_equals('-', $self->obj->output_field_separator);

    assert_not_null($self->obj->print('c', 'd'));

    my $prev1 = IO::Moose::Handle->output_field_separator;
    assert_equals(':', $prev1);

    my $prev2 = $self->obj->output_field_separator;
    assert_equals('-', $prev2);

    $prev1 = IO::Moose::Handle->output_field_separator($old1);
    assert_equals(':', $prev1);

    $prev2 = $self->obj->output_field_separator($old2);
    assert_equals('-', $prev2);

    assert_not_null($self->obj->print('e', 'f'));

    $self->obj->output_field_separator('!');
    $self->obj->clear_output_field_separator;

    assert_not_null($self->obj->print('g', 'h'));

    $self->obj->close;

    open my $fh_in, '<', $self->filename_out;
    read $fh_in, (my $content), 99999;
    close $fh_in;
    assert_equals('a:bc-defgh', $content);
};

sub test_write {
    my ($self) = @_;

    $self->obj->write('abcdef');
    $self->obj->write('ghijkl', 3);
    $self->obj->write('mnopqr', 3, 2);

    $self->obj->close;

    open my $fh_in, '<', $self->filename_out or Exception::IO->throw;
    my $content = <$fh_in>;
    close $fh_in;
    assert_equals('abcdefghiopq', $content);
};

sub test_write_error_io {
    my ($self) = @_;

    $self->obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->write('CLOSED');
    } );
};

sub test_write_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->write('STATIC');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->write;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->write(1, 2, 3, 4);
    } );
};

sub test_syswrite {
    my ($self) = @_;

    {
        my $s = $self->obj->syswrite('1234567890');
        assert_equals(10, $s);
    };

    {
        my $s = $self->obj->syswrite('1234567890', 5);
        assert_equals(5, $s);
    };

    {
        my $s = $self->obj->syswrite('1234567890', 5, 5);
        assert_equals(5, $s);
    };

    $self->obj->close;

    open my $fh_in, '<', $self->filename_out or Exception::IO->throw;
    read $fh_in, (my $content), 99999;
    close $fh_in;
    assert_equals('12345678901234567890', $content);
};

sub test_syswrite_tied {
    my ($self) = @_;

    {
        my $s = syswrite $self->obj, '1234567890';
        assert_equals(10, $s);
    };

    {
        my $s = syswrite $self->obj, '1234567890', 5;
        assert_equals(5, $s);
    };

    {
        my $s = syswrite $self->obj, '1234567890', 5, 5;
        assert_equals(5, $s);
    };

    $self->obj->close;

    open my $fh_in, '<', $self->filename_out or Exception::IO->throw;
    read $fh_in, (my $content), 99999;
    close $fh_in;
    assert_equals('12345678901234567890', $content);
};

sub test_syswrite_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->syswrite('STATIC');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->syswrite;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->syswrite(1, 2, 3, 4);
    } );
};

sub test_getc {
    my ($self) = @_;

    printf { $self->fh_out } "ABC\000" or Exception::IO->throw;
    close $self->fh_out or Exception::IO->throw;

    open my $fh_in, '<', $self->filename_out or Exception::IO->throw;

    $self->obj->close;
    assert_false($self->obj->opened);

    $self->obj->fdopen($fh_in, 'r');
    assert_not_null($self->obj->fileno);

    {
        if (${^TAINT}) {
            $self->obj->untaint;
        };

        my $c = $self->obj->getc;
        assert_equals('A', $c);

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };

    {
        my $c = $self->obj->getc;
        assert_equals('B', $c);
    };

    {
        my $c = $self->obj->getc;
        assert_equals('C', $c);
    };

    {
        my $c = $self->obj->getc;
        assert_equals(0, ord($c));
    };

    {
        my $c = $self->obj->getc;
        assert_null($c, '$c = $self->obj->getc');
    };

    {
        my $c = $self->obj->getc;
        assert_null($c, '$c = $self->obj->getc');

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };

    $self->obj->close;
    close $fh_in;
};

sub test_getc_tied {
    my ($self) = @_;

    printf { $self->fh_out } "ABC\000" or Exception::IO->throw;
    close $self->fh_out or Exception::IO->throw;

    open my $fh_in, '<', $self->filename_out or Exception::IO->throw;

    $self->obj->close;
    assert_false($self->obj->opened);

    $self->obj->fdopen($fh_in, 'r');
    assert_not_null($self->obj->fileno);

    {
        my $c = getc $self->obj;
        assert_equals('A', $c);

        if (${^TAINT}) {
            assert_true(tainted $c);
        };
    };

    {
        if (${^TAINT}) {
            $self->obj->untaint;
        };

        my $c = getc $self->obj;
        assert_equals('B', $c);

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };

    {
        my $c = getc $self->obj;
        assert_equals('C', $c);
    };

    {
        my $c = getc $self->obj;
        assert_equals(0, ord($c));
    };

    {
        my $c = getc $self->obj;
        assert_null($c, '$c = getc $self->obj');
    };

    {
        my $c = getc $self->obj;
        assert_null($c, '$c = getc $self->obj');
    };

    $self->obj->close;
    close $fh_in;
};

sub test_getc_ungetc {
    my ($self) = @_;

    printf { $self->fh_out } "ABC" or Exception::IO->throw;
    close $self->fh_out or Exception::IO->throw;

    open my $fh_in, '<', $self->filename_out or Exception::IO->throw;

    $self->obj->close;
    assert_false($self->obj->opened);

    $self->obj->fdopen($fh_in, 'r');
    assert_not_null($self->obj->fileno);

    {
        my $c = $self->obj->getc;
        assert_equals('A', $c);
    };

    $self->obj->ungetc(ord('1'));
    {
        my $c = $self->obj->getc;
        assert_equals('1', $c);
    };

    {
        my $c = $self->obj->getc;
        assert_equals('B', $c);
    };

    {
        my $c = $self->obj->getc;
        assert_equals('C', $c);
    };

    {
        my $c = $self->obj->getc;
        assert_null($c, '$c = $self->obj->getc');
    };

    $self->obj->ungetc(ord('3'));

    {
        my $c = $self->obj->getc;
        assert_equals('3', $c);
    };

    {
        my $c = $self->obj->getc;
        assert_null($c, '$c = $self->obj->getc');
    };

    $self->obj->close;
    close $fh_in;
}

sub test_getc_error_io {
    my ($self) = @_;

    # Filehandle $fh opened only for output
    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->getc;
    } );
};

sub test_getc_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->getc('ARG');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->getc('ARG');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->getc(1, 2);
    } );
};

sub test_say {
    my ($self) = @_;

    assert_not_null($self->obj->say('a'));
    assert_not_null($self->obj->say('b'));
    assert_not_null($self->obj->say('c'));

    $self->obj->close;

    open my $fh_in, '<', $self->filename_out or Exception::IO->throw;
    read $fh_in, (my $content), 99999;
    close $fh_in;
    assert_equals("a\nb\nc\n", $content);
};

sub test_say_error_io {
    my ($self) = @_;

    $self->obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->say('WARN');
    } );
};

sub test_say_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->say('ARG');
    } );
};

sub test_truncate {
    my ($self) = @_;

    $self->obj->close;
    assert_false($self->obj->opened);

    print { $self->fh_out } "ABCDEFGHIJ" or Exception::IO->throw;
    close $self->fh_out or Exception::IO->throw;
    open $self->fh_out, '>>', $self->filename_out or Exception::IO->throw;

    $self->obj->fdopen($self->fh_out, 'w');
    assert_true($self->obj->opened);

    assert_not_null($self->obj->truncate(5));
    assert_not_null($self->obj->truncate(10));

    $self->obj->close;

    open my $fh_in, '<', $self->filename_out or Exception::IO->throw;
    read $fh_in, (my $content), 99999;
    close $fh_in;
    assert_equals("ABCDE\000\000\000\000\000", $content);
};

sub test_truncate_error_io {
    my ($self) = @_;

    $self->obj->close;

    assert_raises( ['Exception::IO'], sub {
        $self->obj->truncate(1);
    } );
};

sub test_truncate_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->truncate(1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->truncate;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->truncate('STRING');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->truncate(1, 2);
    } );
};

sub test_error {
    my ($self) = @_;

    assert_false($self->obj->error);

    assert_not_null($self->obj->print('a'));
    assert_false($self->obj->error);

    # trying to write to read-only file handler
    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->getline;
    } );

    assert_true($self->obj->error);
    assert_true($self->obj->error);
    assert_true($self->obj->clearerr);
    assert_false($self->obj->error);

    $self->obj->close;

    assert_true($self->obj->error);
    assert_false($self->obj->clearerr);
    assert_true($self->obj->error);
};

sub test_error_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->error;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->error(1);
    } );
};

sub test_error_clearerr_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->clearerr;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->clearerr(1);
    } );
};

sub test_sync {
    my ($self) = @_;

    assert_not_null($self->obj->print('a'));

    {
        my $c = eval {
            $self->obj->sync;
        };
        if ($@) {
            my $e = Exception::Died->catch;
            # Unimplemented on MSWin32
            return if $e->eval_error =~ /not implemented/;
        };
        assert_true($c, '$c');
    };

    $self->obj->close;

    assert_raises( ['Exception::Unimplemented', 'Exception::IO'], sub {
        $self->obj->sync;
    } );
};

sub test_error_sync_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->sync;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->sync(1);
    } );
};

sub test_flush {
    my ($self) = @_;

    assert_not_null($self->obj->print('a'));
    assert_not_null($self->obj->print('b'));

    {
        open my $fh_in, '<', $self->filename_out or Exception::IO->throw;
        read $fh_in, (my $content), 99999;
        close $fh_in;
        assert_equals('', $content);

        my $c = $self->obj->flush;
        assert_not_null($c);
    };

    {
        open my $fh_in, '<', $self->filename_out or Exception::IO->throw;
        read $fh_in, (my $content), 99999;
        close $fh_in;
        assert_equals('ab', $content);
    };

    $self->obj->close;

    {
        open my $fh_in, '<', $self->filename_out or Exception::IO->throw;
        read $fh_in, (my $content), 99999;
        close $fh_in;
        assert_equals('ab', $content);
    };

    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->flush;
    } );
};

sub test_error_flush_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->flush;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->flush(1);
    } );
};

sub test_printflush {
    my ($self) = @_;

    assert_true($self->obj->printflush('a'), "$self->obj->printflush('a')");

    {
        open my $fh_in, '<', $self->filename_out or Exception::IO->throw;
        read $fh_in, (my $content), 99999;
        close $fh_in;
        assert_equals('a', $content);
    };

    assert_true($self->obj->printflush('b'), "$self->obj->printflush('b')");

    {
        open my $fh_in, '<', $self->filename_out or Exception::IO->throw;
        read $fh_in, (my $content), 99999;
        close $fh_in;
        assert_equals('ab', $content);
    };

    $self->obj->close;

    # Bad file descriptor
    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->printflush('c');
    } );
};

sub test_printflush_static {
    IO::Moose::Handle->printflush;
};

1;
