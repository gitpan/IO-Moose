package IO::Moose::HandleReadTest;

use strict;
use warnings;

use Test::Unit::Lite;
use parent 'Test::Unit::TestCase';

use Test::Assert ':all';

use Scalar::Util 'reftype', 'tainted';

use IO::Moose::Handle;

my ($filename_in, $fh_in, $obj, @vars);

sub set_up {
    $filename_in = __FILE__;

    open $fh_in, '<', $filename_in or Exception::IO->throw;

    $obj = IO::Moose::Handle->new;
    assert_isa('IO::Moose::Handle', $obj);
    assert_equals('GLOB', reftype $obj);

    $obj->fdopen($fh_in, 'r');
    assert_true($obj->opened);

    @vars = ($/);
};

sub tear_down {
    ($/) = @vars;

    $obj = undef;

    close $fh_in;
};

sub test_fdopen_io_handle_moose {
    my $io = IO::Moose::Handle->new;
    assert_isa('IO::Moose::Handle', $io);
    $io->fdopen($obj);
    assert_not_null($io->fileno);
};

sub test_close {
    $obj->close;

    # close closed fh
    assert_raises( ['Exception::IO'], sub {
        $obj->close;
    } );
};

sub test_close_tied {
    close $obj;

    # close closed fh
    assert_raises( ['Exception::IO'], sub {
        close $obj;
    } );
};

sub test_eof_not_empty_file {
    assert_false($obj->eof);

    $obj->close;

    assert_true($obj->eof);
};

sub test_eof_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->eof;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->eof(1);
    } );
};

sub test_fileno {
    assert_not_null($obj->fileno);

    $obj->close;

    assert_raises( ['Exception::IO'], sub {
        $obj->fileno;
    } );
};

sub test_fileno_tied {
    assert_not_null(fileno $obj);

    $obj->close;

    assert_raises( ['Exception::IO'], sub {
        fileno $obj;
    } );
};

sub test_fileno_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->fileno;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->fileno(1);
    } );
};

sub test_readline_wantscalar {
    if (${^TAINT}) {
        $obj->untaint;
    };

    my $c = $obj->readline;
    assert_true(length $c > 1, 'length $c > 1');
    assert_true($c =~ tr/\n// == 1, '$c =~ tr/\n// == 1');

    if (${^TAINT}) {
        assert_false(tainted $c);
    };
};

sub test_readline_wantarray {
    if (${^TAINT}) {
        $obj->untaint;
    };

    {
        my @c = $obj->readline;
        assert_true(scalar @c > 1, 'scalar @c > 1');

        if (${^TAINT}) {
            assert_false(tainted $c[0]);
        };
    };

    # returns undef on eof in scalar context
    {
        my $c = $obj->readline;
        assert_null($c, '$c');
    };

    # returns empty list on eof in array context 
    {
        my @c = $obj->readline;
        assert_equals(0, scalar @c);
    }; 
};

sub test_readline_ungetc_wantscalar {
    $obj->ungetc(ord('A'));
    $obj->ungetc(ord("\n"));
    $obj->ungetc(ord('B'));

    {
        my $c = $obj->readline;
        assert_equals(2, length $c);
        assert_true($c eq "B\n");
    };

    {
        my $c = $obj->readline;
        assert_true(length $c > 1, 'length $c > 1');
        assert_matches(qr/^A/, $c);
    };
};

sub test_readline_ungetc_wantarray {
    $obj->ungetc(ord('A'));
    $obj->ungetc(ord("\n"));
    $obj->ungetc(ord('B'));

    my @c = $obj->readline;
    assert_true(scalar @c > 2, 'scalar @c > 2');
    assert_equals("B\n", $c[0]);
    assert_matches(qr/^A/, $c[1]);
};

sub test_readline_global_input_record_separator {
    my $old = IO::Moose::Handle->input_record_separator(undef);
    assert_null(IO::Moose::Handle->input_record_separator);

    my $l = (stat __FILE__)[7];
    assert_true($l > 1, '$l > 1');
    my $c = $obj->readline;
    assert_equals($l, length $c);
    assert_true($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');

    $obj->close;

    my $prev = IO::Moose::Handle->input_record_separator;
    assert_null($prev);

    $prev = IO::Moose::Handle->input_record_separator($old);
    assert_null($prev);
};

sub test_readline_filehandle_input_record_separator {
    my $old = $obj->input_record_separator(\1000);
    assert_equals('SCALAR', ref $obj->input_record_separator);
    assert_equals(1000, ${ $obj->input_record_separator });

    {
        my $c = $obj->readline;
        assert_equals(1000, length $c);
    };

    my $prev = $obj->input_record_separator;
    assert_equals('SCALAR', ref $prev);
    assert_equals(1000, ${$prev});

    $prev = $obj->input_record_separator($old);
    assert_equals('SCALAR', ref $prev);
    assert_equals(1000, ${$prev});

    $obj->input_record_separator('!');
    $obj->clear_input_record_separator;

    {
        my $c = $obj->readline;
        assert_not_equals(1000, length $c);
        assert_true($c =~ tr/\n// == 1, '$c =~ tr/\n// == 1');
    };
};

sub test_readline_error_io {
    $obj->close;
    assert_false($obj->opened);

    assert_raises( ['Exception::Fatal'], sub {
        $obj->readline;
    } );
};

sub test_readline_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->readline;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->readline(1);
    } );
};

sub test_getline_wantscalar {
    my $c = $obj->getline;
    assert_true(length $c > 1, 'length $c > 1');
    assert_true($c =~ tr/\n// == 1, '$c =~ tr/\n// == 1');
};

sub test_getline_wantarray {
    my @c = $obj->getline;
    assert_true(scalar @c == 1, 'scalar @c == 1');
    assert_true($c[0] =~ tr/\n// == 1, '$c[0] =~ tr/\n// == 1');
};

sub test_getline_wantscalar_error_io {
    $obj->close;
    assert_false($obj->opened);

    assert_raises( ['Exception::Fatal'], sub {
        my $c = $obj->getline;
    } );
};

sub test_getline_wantscalar_error_args {
    assert_raises( ['Exception::Argument'], sub {
        my $c = IO::Moose::Handle->getline;
    } );

    assert_raises( ['Exception::Argument'], sub {
        my $c = $obj->getline(1);
    } );
};

sub test_getlines_wantscalar_error_scalar {
    assert_raises( ['Exception::Argument'], sub {
        my $c = $obj->getlines;
    } );
};

sub test_getlines_wantscalar_error_args {
    assert_raises( ['Exception::Argument'], sub {
        my $c = $obj->getlines(1);
    } );
};

sub test_getlines_wantarray {
    my @c = $obj->getlines;
    assert_true(scalar @c > 1, 'scalar @c > 1');
};

sub test_getlines_wantarray_error_io {
    $obj->close;
    assert_false($obj->opened);

    assert_raises( ['Exception::Fatal'], sub {
        my @c = $obj->getlines;
    } );
};

sub test_getlines_wantarray_error_args {
    assert_raises( ['Exception::Argument'], sub {
        my @c = IO::Moose::Handle->getlines;
    } );

    assert_raises( ['Exception::Argument'], sub {
        my @c = $obj->getlines(1);
    } );
};

sub test_ungetc_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->ungetc(123);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->ungetc('A');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->ungetc();
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->ungetc(1, 2);
    } );
};

sub test_sysread {
    {
        my $s = $obj->sysread(my $c, 10);
        assert_equals(10, $s);
        assert_equals(10, length($c));
    };

    {
        if (${^TAINT}) {
            $obj->untaint;
        };

        my $s = $obj->sysread(my $c, 10, 10);
        assert_equals(10, $s);
        assert_equals(20, length($c));

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };
};

sub test_sysread_tied {
    {
        my $s = sysread $obj, (my $c), 10;
        assert_equals(10, $s);
        assert_equals(10, length($c));
    };

    {
        if (${^TAINT}) {
            $obj->untaint;
        };

        my $s = sysread $obj, (my $c), 10, 10;
        assert_equals(10, $s);
        assert_equals(20, length($c));

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };
};

sub test_sysread_error_io {
    assert_raises( ['Exception::Fatal'], sub {
        my $s = $obj->sysread('CONST', 10);
    } );

    $obj->close;
    assert_false($obj->opened);

    assert_raises( ['Exception::Fatal'], sub {
        my $s = $obj->sysread(my $c, 10)
    } );
};

sub test_sysread_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->sysread(my $c, 1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->sysread();
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->sysread(1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->sysread(1, 2, 3, 4);
    } );
};

sub test_read {
    {
        my $s = $obj->read(my $c, 10);
        assert_equals(10, $s);
        assert_equals(10, length($c));
    };

    {
        if (${^TAINT}) {
            $obj->untaint;
        };

        my $s = $obj->read(my $c, 10, 10);
        assert_equals(10, $s);
        assert_equals(20, length($c));

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };
};

sub test_read_tied {
    {
        my $s = read $obj, my $c, 10;
        assert_equals(10, $s);
        assert_equals(10, length($c));
    };

    {
        if (${^TAINT}) {
            $obj->untaint;
        };

        my $s = read $obj, my $c, 10, 10;
        assert_equals(10, $s);
        assert_equals(20, length($c));

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };
};

sub test_read_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->read(my $c, 1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->read();
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->read(1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->read(1, 2, 3, 4);
    } );
};

sub test_slurp_wantscalar {
    if (${^TAINT}) {
        $obj->untaint;
    };

    my $c = $obj->slurp;
    assert_true(length $c > 1, 'length $c > 1');
    assert_true($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');

    if (${^TAINT}) {
        assert_false(tainted $c);
    };
};

sub test_slurp_wantarray {
    if (${^TAINT}) {
        $obj->untaint;
    };

    my @c = $obj->slurp;
    assert_true(@c > 1, '@c > 1');
    assert_true($c[0] =~ tr/\n// == 1, '$c[0] =~ tr/\n// == 1');

    if (${^TAINT}) {
        assert_false(tainted $c[0]);
    };
};

sub test_slurp_error_io {
    assert_raises( ['Exception::Fatal'], sub {
        IO::Moose::Handle->slurp( file => \*STDOUT );
    } );
};

sub test_slurp_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->slurp;
    } );

    # no file
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->slurp(1, 2);
    } );

    assert_raises( qr/Odd number of elements in hash/, sub {
        $obj->slurp(1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->slurp(1, 2);
    } );

    assert_raises( qr/does not pass the type constraint/, sub {
        IO::Moose::Handle->slurp( file => 'STRING' );
    } );
};

sub test_stat {
    my $st = $obj->stat();
    assert_not_null($st);
    assert_isa('File::Stat::Moose', $st);

    read $fh_in, (my $content), 99999;
    assert_equals(length($content), $st->size);
};

sub test_stat_error_io {
    $obj->close;

    # Bad file descriptor
    assert_raises( ['Exception::Fatal'], sub {
        $obj->stat;
    } );
};

sub test_stat_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->stat;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->stat(1);
    } );
};

sub test_blocking {
    {
        my $c = eval {
            $obj->blocking(0);
        };
        if ($@) {
            my $e = Exception::Base->catch;
            # Unimplemented on MSWin32
            return if $e->isa('Exception::IO');
        };
        assert_equals(1, $c);
    };

    {
        my $c = $obj->blocking;
        assert_equals(0, $c);
    };

    {
        my $c = $obj->blocking(1);
        assert_equals(0, $c);
    };

    {
        my $c = $obj->blocking;
        assert_equals(1, $c);

    };
};

sub test_blocking_error_io {
    $obj->close;

    # Bad file descriptor
    assert_raises( ['Exception::IO'], sub {
        $obj->blocking;
    } );
};

sub test_blocking_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->blocking;
    } );

    assert_raises( qr/does not pass the type constraint/, sub {
        $obj->blocking('STRING');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->blocking(1, 2);
    } );
};

sub test_untaint {
    if (${^TAINT}) {
        assert_true($obj->tainted);
    }
    else {
        assert_false($obj->tainted);
    };

    {
        my $c = $obj->getline;
        assert_not_equals('', $c);

        if (${^TAINT}) {
            assert_true(tainted $c);
        };
    };

    $obj->untaint;
    assert_false($obj->tainted);

    {
        my $c = $obj->getline;

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };
};

sub test_untaint_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->untaint;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->untaint(1);
    } );
};

sub test_accessors_error_args {
    assert_raises( ['Exception::Argument'], sub {
        $obj->output_field_separator(1, 2);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->output_autoflush(1, 2);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->format_top_name(1, 2);
    } );
};

1;
