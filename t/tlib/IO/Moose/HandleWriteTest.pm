package IO::Moose::HandleWriteTest;

use strict;
use warnings;

use parent 'Test::Unit::TestCase';
use Test::Assert ':all';

use File::Temp;
use Scalar::Util 'reftype', 'tainted';

use IO::Moose::Handle;

my ($filename_out, $fh_out, $obj, @vars);

sub set_up {
    (undef, $filename_out) = File::Temp::tempfile;

    open $fh_out, '>', $filename_out or Exception::IO->throw;

    $obj = IO::Moose::Handle->new;
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);

    $obj->fdopen($fh_out, 'w');
    assert_not_null($obj->fileno);

    @vars = ($=, $-, $~, $^, $^L, $\, $,);
};

sub tear_down {
    ($=, $-, $~, $^, $^L, $\, $,) = @vars;

    $obj = undef;

    close $fh_out;

    unlink $filename_out;
};

sub test_eof_empty_file {
    # $fh_out is already opened by set_up
    close $fh_out or Exception::IO->throw;
    open my $fh_in, '<', $filename_out or Exception::IO->throw;

    $obj->close;
    assert_false($obj->opened);

    $obj->fdopen($fh_in, 'r');
    assert_not_null($obj->fileno);

    assert_true($obj->eof);
    $obj->close;

    assert_true($obj->eof);
};

sub test_eof_tied_empty_file {
    # $fh_out is already opened by set_up
    close $fh_out or Exception::IO->throw;
    open my $fh_in, '<', $filename_out or Exception::IO->throw;

    $obj->close;
    assert_false($obj->opened);

    $obj->fdopen($fh_in, 'r');
    assert_not_null($obj->fileno);

    assert_true(eof $obj);
    $obj->close;

    assert_true(eof $obj);
};

sub test_eof_error_io {
    assert_raises( ['Exception::Fatal'], sub {
        $obj->eof;
    } );
};

sub test_print {
    assert_not_null($obj->print('a'));
    assert_not_null($obj->print('b'));
    assert_not_null($obj->print('c'));

    $obj->close or Exception::IO->throw;

    open my $fh_in, '<', $filename_out or Exception::IO->throw;
    my $content = <$fh_in>;
    close $fh_in;
    assert_equals('abc', $content);

    assert_raises( ['Exception::Fatal'], sub {
        $obj->print('WARN');
    } );
};

sub test_print_tied {
    assert_not_null(print $obj 'a');
    assert_not_null(print $obj 'b');
    assert_not_null(print $obj 'c');

    $obj->close or Exception::IO->throw;

    open my $fh_in, '<', $filename_out or Exception::IO->throw;
    my $content = <$fh_in>;
    close $fh_in;
    assert_equals('abc', $content);

    assert_raises( ['Exception::Fatal'], sub {
        print $obj 'WARN';
    } );
};

sub test_print_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->print;
    } );
};

sub test_printf {
    assert_not_null($obj->printf('%s', 'a'));
    assert_not_null($obj->printf('%c', ord('b')));
    assert_not_null($obj->printf('c'));

    $obj->close or Exception::IO->throw;

    open my $fh_in, '<', $filename_out or Exception::IO->throw;
    my $content = <$fh_in>;
    close $fh_in;
    assert_equals('abc', $content);

    assert_raises( ['Exception::Fatal'], sub {
        $obj->printf('WARN');
    } );
};

sub test_printf_tied {
    assert_not_null(printf $obj '%s', 'a');
    assert_not_null(printf $obj '%c', ord('b'));
    assert_not_null(printf $obj 'c');

    $obj->close or Exception::IO->throw;

    open my $fh_in, '<', $filename_out or Exception::IO->throw;
    my $content = <$fh_in>;
    close $fh_in;
    assert_equals('abc', $content);

    assert_raises( ['Exception::Fatal'], sub {
        printf $obj 'WARN';
    } );
};

sub test_printf_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->printf;
    } );
};

sub test_format_write_format_name {
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

    my $old1 = $obj->format_lines_per_page(3);
    assert_equals(3, $obj->format_lines_per_page);
    my $old2 = $obj->format_lines_left(5);
    assert_equals(5, $obj->format_lines_left);
    my $old3 = $obj->format_formfeed(']');
    assert_equals(']', $obj->format_formfeed);

    $obj->format_write(__PACKAGE__ . '::FORMAT_TEST1');

    my $prev1 = $obj->format_lines_per_page;
    assert_equals(3, $prev1);

    my $prev2 = $obj->format_lines_per_page($old1);
    assert_equals(3, $prev2);

    $obj->close;

    open my $fh_in, '<', $filename_out;
    read $fh_in, (my $content), 99999;
    close $fh_in;
    my $string = "          header\nleft      middle      right\ncontent\n]"
               . "          header\ncontent\ncontent\n]"
               . "          header\ncontent\ncontent\n";
    assert_equals($string, $content);

    # Called on closed fh
    assert_raises( ['Exception::Fatal'], sub {
        $obj->format_write(__PACKAGE__ . '::FORMAT_TEST1');
    } );
};

sub test_format_write_error_not_a_format {
    assert_raises( ['Exception::Fatal'], sub {
        $obj->format_write;
    } );
};

sub test_format_write_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->format_write;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->format_write(1, 2);
    } );
};

sub test_output_record_separator {
    my $old1 = IO::Moose::Handle->output_record_separator(':');
    assert_equals(':', IO::Moose::Handle->output_record_separator);

    assert_not_null($obj->print('a'));
    assert_not_null($obj->print('b'));

    my $old2 = $obj->output_record_separator('-');
    assert_equals('-', $obj->output_record_separator);

    assert_not_null($obj->print('c'));
    assert_not_null($obj->print('d'));

    my $prev1 = IO::Moose::Handle->output_record_separator;
    assert_equals(':', $prev1);

    my $prev2 = $obj->output_record_separator;
    assert_equals('-', $prev2);

    $prev1 = IO::Moose::Handle->output_record_separator($old1);
    assert_equals(':', $prev1);

    $prev2 = $obj->output_record_separator($old2);
    assert_equals('-', $prev2);

    assert_not_null($obj->print('e'));
    assert_not_null($obj->print('f'));

    $obj->output_record_separator('!');
    $obj->clear_output_record_separator;

    assert_not_null($obj->print('g'));
    assert_not_null($obj->print('h'));

    $obj->close or Exception::IO->throw;

    open my $fh_in, '<', $filename_out;
    read $fh_in, (my $content), 99999;
    close $fh_in;
    assert_equals('a:b:c-d-efgh', $content);
};

sub test_output_field_separator {
    my $old1 = IO::Moose::Handle->output_field_separator(':');
    assert_equals(':', IO::Moose::Handle->output_field_separator);

    assert_not_null($obj->print('a', 'b'));

    my $old2 = $obj->output_field_separator('-');
    assert_equals('-', $obj->output_field_separator);

    assert_not_null($obj->print('c', 'd'));

    my $prev1 = IO::Moose::Handle->output_field_separator;
    assert_equals(':', $prev1);

    my $prev2 = $obj->output_field_separator;
    assert_equals('-', $prev2);

    $prev1 = IO::Moose::Handle->output_field_separator($old1);
    assert_equals(':', $prev1);

    $prev2 = $obj->output_field_separator($old2);
    assert_equals('-', $prev2);

    assert_not_null($obj->print('e', 'f'));

    $obj->output_field_separator('!');
    $obj->clear_output_field_separator;

    assert_not_null($obj->print('g', 'h'));

    $obj->close;

    open my $fh_in, '<', $filename_out;
    read $fh_in, (my $content), 99999;
    close $fh_in;
    assert_equals('a:bc-defgh', $content);
};

sub test_write {
    $obj->write('abcdef');
    $obj->write('ghijkl', 3);
    $obj->write('mnopqr', 3, 2);

    $obj->close;

    open my $fh_in, '<', $filename_out or Exception::IO->throw;
    my $content = <$fh_in>;
    close $fh_in;
    assert_equals('abcdefghiopq', $content);
};

sub test_write_error_io {
    $obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        $obj->write('CLOSED');
    } );
};

sub test_write_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->write('STATIC');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->write;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->write(1, 2, 3, 4);
    } );
};

sub test_syswrite {
    {
        my $s = $obj->syswrite('1234567890');
        assert_equals(10, $s);
    };

    {
        my $s = $obj->syswrite('1234567890', 5);
        assert_equals(5, $s);
    };

    {
        my $s = $obj->syswrite('1234567890', 5, 5);
        assert_equals(5, $s);
    };

    $obj->close;

    open my $fh_in, '<', $filename_out or Exception::IO->throw;
    read $fh_in, (my $content), 99999;
    close $fh_in;
    assert_equals('12345678901234567890', $content);
};

sub test_syswrite_tied {
    {
        my $s = syswrite $obj, '1234567890';
        assert_equals(10, $s);
    };

    {
        my $s = syswrite $obj, '1234567890', 5;
        assert_equals(5, $s);
    };

    {
        my $s = syswrite $obj, '1234567890', 5, 5;
        assert_equals(5, $s);
    };

    $obj->close;

    open my $fh_in, '<', $filename_out or Exception::IO->throw;
    read $fh_in, (my $content), 99999;
    close $fh_in;
    assert_equals('12345678901234567890', $content);
};

sub test_syswrite_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->syswrite('STATIC');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->syswrite;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->syswrite(1, 2, 3, 4);
    } );
};

sub test_getc {
    printf $fh_out "ABC\000" or Exception::IO->throw;
    close $fh_out or Exception::IO->throw;

    open my $fh_in, '<', $filename_out or Exception::IO->throw;

    $obj->close;
    assert_false($obj->opened);

    $obj->fdopen($fh_in, 'r');
    assert_not_null($obj->fileno);

    {
        if (${^TAINT}) {
            $obj->untaint;
        };

        my $c = $obj->getc;
        assert_equals('A', $c);

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };

    {
        my $c = $obj->getc;
        assert_equals('B', $c);
    };

    {
        my $c = $obj->getc;
        assert_equals('C', $c);
    };

    {
        my $c = $obj->getc;
        assert_equals(0, ord($c));
    };

    {
        my $c = $obj->getc;
        assert_null($c, '$c = $obj->getc');
    };

    {
        my $c = $obj->getc;
        assert_null($c, '$c = $obj->getc');

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };

    $obj->close;
    close $fh_in;
};

sub test_getc_tied {
    printf $fh_out "ABC\000" or Exception::IO->throw;
    close $fh_out or Exception::IO->throw;

    open my $fh_in, '<', $filename_out or Exception::IO->throw;

    $obj->close;
    assert_false($obj->opened);

    $obj->fdopen($fh_in, 'r');
    assert_not_null($obj->fileno);

    {
        my $c = getc $obj;
        assert_equals('A', $c);

        if (${^TAINT}) {
            assert_true(tainted $c);
        };
    };

    {
        if (${^TAINT}) {
            $obj->untaint;
        };

        my $c = getc $obj;
        assert_equals('B', $c);

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };

    {
        my $c = getc $obj;
        assert_equals('C', $c);
    };

    {
        my $c = getc $obj;
        assert_equals(0, ord($c));
    };

    {
        my $c = getc $obj;
        assert_null($c, '$c = getc $obj');
    };

    {
        my $c = getc $obj;
        assert_null($c, '$c = getc $obj');
    };

    $obj->close;
    close $fh_in;
};

sub test_getc_ungetc {
    printf $fh_out "ABC" or Exception::IO->throw;
    close $fh_out or Exception::IO->throw;

    open my $fh_in, '<', $filename_out or Exception::IO->throw;

    $obj->close;
    assert_false($obj->opened);

    $obj->fdopen($fh_in, 'r');
    assert_not_null($obj->fileno);

    {
        my $c = $obj->getc;
        assert_equals('A', $c);
    };

    $obj->ungetc(ord('1'));
    $obj->ungetc(ord('2'));

    {
        my $c = $obj->getc;
        assert_equals('2', $c);
    };

    {
        my $c = $obj->getc;
        assert_equals('1', $c);
    };

    {
        my $c = $obj->getc;
        assert_equals('B', $c);
    };

    {
        my $c = $obj->getc;
        assert_equals('C', $c);
    };

    {
        my $c = $obj->getc;
        assert_null($c, '$c = $obj->getc');
    };

    $obj->ungetc(ord('3'));

    {
        my $c = $obj->getc;
        assert_equals('3', $c);
    };

    {
        my $c = $obj->getc;
        assert_null($c, '$c = $obj->getc');
    };

    $obj->close;
    close $fh_in;
}

sub test_getc_error_io {
    # Filehandle $fh opened only for output
    assert_raises( ['Exception::Fatal'], sub {
        $obj->getc;
    } );
};

sub test_getc_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->getc('ARG');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->getc('ARG');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->getc(1, 2);
    } );
};

sub test_say {
    assert_not_null($obj->say('a'));
    assert_not_null($obj->say('b'));
    assert_not_null($obj->say('c'));

    $obj->close;

    open my $fh_in, '<', $filename_out or Exception::IO->throw;
    read $fh_in, (my $content), 99999;
    close $fh_in;
    assert_equals("a\nb\nc\n", $content);
};

sub test_say_error_io {
    $obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        $obj->say('WARN');
    } );
};

sub test_say_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->say('ARG');
    } );
};

sub test_truncate {
    $obj->close;
    assert_false($obj->opened);

    print $fh_out "ABCDEFGHIJ" or Exception::IO->throw;
    close $fh_out or Exception::IO->throw;
    open $fh_out, '>>', $filename_out or Exception::IO->throw;

    $obj->fdopen($fh_out, 'w');
    assert_true($obj->opened);

    assert_not_null($obj->truncate(5));
    assert_not_null($obj->truncate(10));

    $obj->close;

    open my $fh_in, '<', $filename_out or Exception::IO->throw;
    read $fh_in, (my $content), 99999;
    close $fh_in;
    assert_equals("ABCDE\000\000\000\000\000", $content);
};

sub test_truncate_error_io {
    $obj->close;

    assert_raises( ['Exception::IO'], sub {
        $obj->truncate(1);
    } );
};

sub test_truncate_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->truncate(1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->truncate;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->truncate('STRING');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->truncate(1, 2);
    } );
};

sub test_error {
    assert_false($obj->error);

    assert_not_null($obj->print('a'));
    assert_false($obj->error);

    # trying to write to read-only file handler
    assert_raises( ['Exception::Fatal'], sub {
        $obj->getline;
    } );

    assert_true($obj->error);
    assert_true($obj->error);
    assert_true($obj->clearerr);
    assert_false($obj->error);

    $obj->close;

    assert_true($obj->error);
    assert_false($obj->clearerr);
    assert_true($obj->error);
};

sub test_error_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->error;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->error(1);
    } );
};

sub test_error_clearerr_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->clearerr;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->clearerr(1);
    } );
};

sub test_sync {
    assert_not_null($obj->print('a'));

    {
        my $c = eval {
            $obj->sync;
        };
        if ($@) {
            my $e = Exception::Base->catch;
            if ($e->isa('Exception::Unimplemented')) {
                # skip: unimplemented
            }
            elsif ($e) {
                $e->throw;
            }
        }
        else {
            assert_true($c, '$c');
        };
    };

    $obj->close;

    assert_raises( ['Exception::Unimplemented', 'Exception::IO'], sub {
        $obj->sync;
    } );
};

sub test_error_sync_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->sync;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->sync(1);
    } );
};

sub test_flush {
    assert_not_null($obj->print('a'));
    assert_not_null($obj->print('b'));

    {
        open my $fh_in, '<', $filename_out or Exception::IO->throw;
        read $fh_in, (my $content), 99999;
        close $fh_in;
        assert_equals('', $content);

        my $c = $obj->flush;
        assert_not_null($c);
    };

    {
        open my $fh_in, '<', $filename_out or Exception::IO->throw;
        read $fh_in, (my $content), 99999;
        close $fh_in;
        assert_equals('ab', $content);
    };

    $obj->close;

    {
        open my $fh_in, '<', $filename_out or Exception::IO->throw;
        read $fh_in, (my $content), 99999;
        close $fh_in;
        assert_equals('ab', $content);
    };

    assert_raises( ['Exception::Fatal'], sub {
        $obj->flush;
    } );
};

sub test_error_flush_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->flush;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->flush(1);
    } );
};

sub test_printflush {
    assert_true($obj->printflush('a'), "$obj->printflush('a')");

    {
        open my $fh_in, '<', $filename_out or Exception::IO->throw;
        read $fh_in, (my $content), 99999;
        close $fh_in;
        assert_equals('a', $content);
    };

    assert_true($obj->printflush('b'), "$obj->printflush('b')");

    {
        open my $fh_in, '<', $filename_out or Exception::IO->throw;
        read $fh_in, (my $content), 99999;
        close $fh_in;
        assert_equals('ab', $content);
    };

    $obj->close;

    # Bad file descriptor
    assert_raises( ['Exception::Fatal'], sub {
        $obj->printflush('c');
    } );
};

sub test_printflush_static {
    IO::Moose::Handle->printflush;
};

1;
