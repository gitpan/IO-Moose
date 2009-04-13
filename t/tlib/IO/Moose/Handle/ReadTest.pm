package IO::Moose::Handle::ReadTest;

use Test::Unit::Lite;

use Moose;
extends 'Test::Unit::TestCase';

with 'IO::Moose::ReadableOpenedTestRole';

use Test::Assert ':all';

use Scalar::Util 'reftype', 'tainted';

use IO::Moose::Handle;

sub test_fdopen_io_handle_moose {
    my ($self) = @_;

    my $io = IO::Moose::Handle->new;
    assert_isa('IO::Moose::Handle', $io);
    $io->fdopen($self->obj);
    assert_not_null($io->fileno);
};

sub test_close {
    my ($self) = @_;

    $self->obj->close;

    # close closed fh
    assert_raises( ['Exception::IO'], sub {
        $self->obj->close;
    } );
};

sub test_close_tied {
    my ($self) = @_;

    close $self->obj;

    # close closed fh
    assert_raises( ['Exception::IO'], sub {
        close $self->obj;
    } );
};

sub test_eof_not_empty_file {
    my ($self) = @_;

    assert_false($self->obj->eof);

    $self->obj->close;

    assert_true($self->obj->eof);
};

sub test_eof_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->eof;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->eof(1);
    } );
};

sub test_fileno {
    my ($self) = @_;

    assert_not_null($self->obj->fileno);

    $self->obj->close;

    assert_raises( ['Exception::IO'], sub {
        $self->obj->fileno;
    } );
};

sub test_fileno_tied {
    my ($self) = @_;

    assert_not_null(fileno $self->obj);

    $self->obj->close;

    assert_raises( ['Exception::IO'], sub {
        fileno $self->obj;
    } );
};

sub test_fileno_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->fileno;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->fileno(1);
    } );
};

sub test_readline_wantscalar {
    my ($self) = @_;

    if (${^TAINT}) {
        $self->obj->untaint;
    };

    my $c = $self->obj->readline;
    assert_true(length $c > 1, 'length $c > 1');
    assert_true($c =~ tr/\n// == 1, '$c =~ tr/\n// == 1');

    if (${^TAINT}) {
        assert_false(tainted $c);
    };
};

sub test_readline_wantarray {
    my ($self) = @_;

    if (${^TAINT}) {
        $self->obj->untaint;
    };

    {
        my @c = $self->obj->readline;
        assert_true(scalar @c > 1, 'scalar @c > 1');

        if (${^TAINT}) {
            assert_false(tainted $c[0]);
        };
    };

    # returns undef on eof in scalar context
    {
        my $c = $self->obj->readline;
        assert_null($c, '$c');
    };

    # returns empty list on eof in array context 
    {
        my @c = $self->obj->readline;
        assert_equals(0, scalar @c);
    }; 
};

sub test_readline_ungetc_wantscalar {
    my ($self) = @_;

    $self->obj->ungetc(ord('A'));
    $self->obj->ungetc(ord("\n"));
    $self->obj->ungetc(ord('B'));

    {
        my $c = $self->obj->readline;
        assert_equals(2, length $c);
        assert_true($c eq "B\n");
    };

    {
        my $c = $self->obj->readline;
        assert_true(length $c > 1, 'length $c > 1');
        assert_matches(qr/^A/, $c);
    };
};

sub test_readline_ungetc_wantarray {
    my ($self) = @_;

    $self->obj->ungetc(ord('A'));
    $self->obj->ungetc(ord("\n"));
    $self->obj->ungetc(ord('B'));

    my @c = $self->obj->readline;
    assert_true(scalar @c > 2, 'scalar @c > 2');
    assert_equals("B\n", $c[0]);
    assert_matches(qr/^A/, $c[1]);
};

sub test_readline_global_input_record_separator {
    my ($self) = @_;

    my $old = IO::Moose::Handle->input_record_separator(undef);
    assert_null(IO::Moose::Handle->input_record_separator);

    my $l = (stat $self->filename_in)[7];
    assert_true($l > 1, '$l > 1');
    my $c = $self->obj->readline;
    assert_equals($l, length $c);
    assert_true($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');

    $self->obj->close;

    my $prev = IO::Moose::Handle->input_record_separator;
    assert_null($prev);

    $prev = IO::Moose::Handle->input_record_separator($old);
    assert_null($prev);
};

sub test_readline_filehandle_input_record_separator {
    my ($self) = @_;

    my $old = $self->obj->input_record_separator(\200);
    assert_equals('SCALAR', ref $self->obj->input_record_separator);
    assert_equals(200, ${ $self->obj->input_record_separator });

    {
        my $c = $self->obj->readline;
        assert_equals(200, length $c);
    };

    my $prev = $self->obj->input_record_separator;
    assert_equals('SCALAR', ref $prev);
    assert_equals(200, ${$prev});

    $prev = $self->obj->input_record_separator($old);
    assert_equals('SCALAR', ref $prev);
    assert_equals(200, ${$prev});

    $self->obj->input_record_separator('!');
    $self->obj->clear_input_record_separator;

    {
        my $c = $self->obj->readline;
        assert_not_equals(200, length $c);
        assert_true($c =~ tr/\n// == 1, '$c =~ tr/\n// == 1');
    };
};

sub test_readline_error_io {
    my ($self) = @_;

    $self->obj->close;
    assert_false($self->obj->opened);

    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->readline;
    } );
};

sub test_readline_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->readline;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->readline(1);
    } );
};

sub test_getline_wantscalar {
    my ($self) = @_;
    my $c = $self->obj->getline;
    assert_true(length $c > 1, 'length $c > 1');
    assert_true($c =~ tr/\n// == 1, '$c =~ tr/\n// == 1');
};

sub test_getline_wantarray {
    my ($self) = @_;
    my @c = $self->obj->getline;
    assert_true(scalar @c == 1, 'scalar @c == 1');
    assert_true($c[0] =~ tr/\n// == 1, '$c[0] =~ tr/\n// == 1');
};

sub test_getline_wantscalar_error_io {
    my ($self) = @_;

    $self->obj->close;
    assert_false($self->obj->opened);

    assert_raises( ['Exception::Fatal'], sub {
        my $c = $self->obj->getline;
    } );
};

sub test_getline_wantscalar_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        my $c = IO::Moose::Handle->getline;
    } );

    assert_raises( ['Exception::Argument'], sub {
        my $c = $self->obj->getline(1);
    } );
};

sub test_getlines_wantscalar_error_scalar {
    my ($self) = @_;
    assert_raises( ['Exception::Argument'], sub {
        my $c = $self->obj->getlines;
    } );
};

sub test_getlines_wantscalar_error_args {
    my ($self) = @_;
    assert_raises( ['Exception::Argument'], sub {
        my $c = $self->obj->getlines(1);
    } );
};

sub test_getlines_wantarray {
    my ($self) = @_;
    my @c = $self->obj->getlines;
    assert_true(scalar @c > 1, 'scalar @c > 1');
};

sub test_getlines_wantarray_error_io {
    my ($self) = @_;

    $self->obj->close;
    assert_false($self->obj->opened);

    assert_raises( ['Exception::Fatal'], sub {
        my @c = $self->obj->getlines;
    } );
};

sub test_getlines_wantarray_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        my @c = IO::Moose::Handle->getlines;
    } );

    assert_raises( ['Exception::Argument'], sub {
        my @c = $self->obj->getlines(1);
    } );
};

sub test_ungetc_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->ungetc(123);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->ungetc('A');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->ungetc();
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->ungetc(1, 2);
    } );
};

sub test_sysread {
    my ($self) = @_;

    {
        my $s = $self->obj->sysread(my $c, 10);
        assert_equals(10, $s);
        assert_equals(10, length($c));
    };

    {
        if (${^TAINT}) {
            $self->obj->untaint;
        };

        my $s = $self->obj->sysread(my $c, 10, 10);
        assert_equals(10, $s);
        assert_equals(20, length($c));

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };
};

sub test_sysread_tied {
    my ($self) = @_;

    {
        my $s = sysread $self->obj, (my $c), 10;
        assert_equals(10, $s);
        assert_equals(10, length($c));
    };

    {
        if (${^TAINT}) {
            $self->obj->untaint;
        };

        my $s = sysread $self->obj, (my $c), 10, 10;
        assert_equals(10, $s);
        assert_equals(20, length($c));

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };
};

sub test_sysread_error_io {
    my ($self) = @_;

    assert_raises( ['Exception::Fatal'], sub {
        my $s = $self->obj->sysread('CONST', 10);
    } );

    $self->obj->close;
    assert_false($self->obj->opened);

    assert_raises( ['Exception::Fatal'], sub {
        my $s = $self->obj->sysread(my $c, 10)
    } );
};

sub test_sysread_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->sysread(my $c, 1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->sysread();
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->sysread(1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->sysread(1, 2, 3, 4);
    } );
};

sub test_read {
    my ($self) = @_;

    {
        my $s = $self->obj->read(my $c, 10);
        assert_equals(10, $s);
        assert_equals(10, length($c));
    };

    {
        if (${^TAINT}) {
            $self->obj->untaint;
        };

        my $s = $self->obj->read(my $c, 10, 10);
        assert_equals(10, $s);
        assert_equals(20, length($c));

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };
};

sub test_read_tied {
    my ($self) = @_;

    {
        my $s = read $self->obj, my $c, 10;
        assert_equals(10, $s);
        assert_equals(10, length($c));
    };

    {
        if (${^TAINT}) {
            $self->obj->untaint;
        };

        my $s = read $self->obj, my $c, 10, 10;
        assert_equals(10, $s);
        assert_equals(20, length($c));

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };
};

sub test_read_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->read(my $c, 1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->read();
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->read(1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->read(1, 2, 3, 4);
    } );
};

sub test_slurp_wantscalar {
    my ($self) = @_;

    if (${^TAINT}) {
        $self->obj->untaint;
    };

    my $c = $self->obj->slurp;
    assert_true(length $c > 1, 'length $c > 1');
    assert_true($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');

    if (${^TAINT}) {
        assert_false(tainted $c);
    };
};

sub test_slurp_wantarray {
    my ($self) = @_;

    if (${^TAINT}) {
        $self->obj->untaint;
    };

    my @c = $self->obj->slurp;
    assert_true(@c > 1, '@c > 1');
    assert_true($c[0] =~ tr/\n// == 1, '$c[0] =~ tr/\n// == 1');

    if (${^TAINT}) {
        assert_false(tainted $c[0]);
    };
};

sub test_slurp_error_io {
    my ($self) = @_;

    assert_raises( ['Exception::Fatal'], sub {
        IO::Moose::Handle->slurp( file => \*STDOUT );
    } );
};

sub test_slurp_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->slurp;
    } );

    # no file
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->slurp(1, 2);
    } );

    assert_raises( qr/Odd number of elements in hash/, sub {
        $self->obj->slurp(1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->slurp(1, 2);
    } );

    assert_raises( qr/does not pass the type constraint/, sub {
        IO::Moose::Handle->slurp( file => 'STRING' );
    } );
};

sub test_stat {
    my ($self) = @_;

    my $st = $self->obj->stat();
    assert_not_null($st);
    assert_isa('File::Stat::Moose', $st);

    read $self->fh_in, (my $content), 99999;
    assert_equals(length($content), $st->size);
};

sub test_stat_error_io {
    my ($self) = @_;

    $self->obj->close;

    # Bad file descriptor
    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->stat;
    } );
};

sub test_stat_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->stat;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->stat(1);
    } );
};

sub test_blocking {
    my ($self) = @_;

    {
        my $c = eval {
            $self->obj->blocking(0);
        };
        if ($@) {
            my $e = Exception::Base->catch;
            # Unimplemented on MSWin32
            return if $e->isa('Exception::IO');
        };
        assert_equals(1, $c);
    };

    {
        my $c = $self->obj->blocking;
        assert_equals(0, $c);
    };

    {
        my $c = $self->obj->blocking(1);
        assert_equals(0, $c);
    };

    {
        my $c = $self->obj->blocking;
        assert_equals(1, $c);

    };
};

sub test_blocking_error_io {
    my ($self) = @_;

    $self->obj->close;

    # Bad file descriptor
    assert_raises( ['Exception::IO'], sub {
        $self->obj->blocking;
    } );
};

sub test_blocking_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->blocking;
    } );

    assert_raises( qr/does not pass the type constraint/, sub {
        $self->obj->blocking('STRING');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->blocking(1, 2);
    } );
};

sub test_untaint {
    my ($self) = @_;

    if (${^TAINT}) {
        assert_true($self->obj->tainted);
    }
    else {
        assert_false($self->obj->tainted);
    };

    {
        my $c = $self->obj->getline;
        assert_not_equals('', $c);

        if (${^TAINT}) {
            assert_true(tainted $c);
        };
    };

    $self->obj->untaint;
    assert_false($self->obj->tainted);

    {
        my $c = $self->obj->getline;

        if (${^TAINT}) {
            assert_false(tainted $c);
        };
    };
};

sub test_untaint_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Handle->untaint;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->untaint(1);
    } );
};

sub test_accessors_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->output_field_separator(1, 2);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->output_autoflush(1, 2);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->format_top_name(1, 2);
    } );
};

1;
