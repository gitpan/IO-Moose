package IO::Moose::SeekableTest;

use strict;
use warnings;

use parent 'Test::Unit::TestCase';
use Test::Assert ':all';

use IO::Moose::Handle;

use Scalar::Util 'reftype';

use maybe Fcntl => ':seek';

{
    package IO::Moose::SeekableTest::Test1;

    use Moose;

    extends 'MooseX::GlobRef::Object';

    with 'IO::Moose::Seekable';

    use Scalar::Util 'weaken';

    sub fdopen {
        my ($self, $fd, $mode) = @_;
        my $hashref = ${*$self};
        $mode = '<' unless $mode;
        $mode =~ s/^r(\+?)$/$1</;
        $mode =~ s/^w(\+?)$/$1>/;
        $mode =~ s/^a(\+?)$/$1>>/;
        my $fileno = CORE::fileno $fd;
        CORE::open $hashref->{fh}, "$mode&=$fileno"
            or Exception::IO->throw;
        my $newfd = CORE::fileno $hashref->{fh};
        CORE::open *$self, "$mode&=$newfd"
            or Exception::IO->throw;
        tie *$self, blessed $self, $self;
    };

    sub TIEHANDLE {
        my ($class, $instance) = @_;
        my $self = \$instance;
        weaken $instance;
        return bless $self => $class;
    };

    sub close {
        my ($self) = @_;
        my $hashref = ${*$self};
        CORE::close $hashref->{fh};
    };

    sub fileno {
        my ($self) = @_;
        my $hashref = ${*$self};
        return CORE::fileno $hashref->{fh};
    };

    sub readline {
        my ($self) = @_;
        my $hashref = ${*$self};
        return CORE::readline $hashref->{fh};
    };

    sub getc {
        my ($self) = @_;
        my $hashref = ${*$self};
        return CORE::getc $hashref->{fh};
    };

    sub sysread {
        my ($self) = @_;
        my $hashref = ${*$self};
        return defined $_[3]
               ? CORE::sysread $hashref->{fh}, $_[1], $_[2], $_[3]
               : CORE::sysread $hashref->{fh}, $_[1], $_[2];
    };
};

my ($filename_in, $fh_in, $obj);

sub set_up {
    $filename_in = __FILE__;

    open $fh_in, '<', $filename_in or Exception::IO->throw;

    $obj = IO::Moose::SeekableTest::Test1->new;
    assert_isa('IO::Moose::SeekableTest::Test1', $obj);
    assert_equals('GLOB', reftype $obj);

    $obj->fdopen($fh_in, 'r');
    assert_not_null($obj->fileno);
};

sub tear_down {
    $obj = undef;

    close $fh_in;
};

sub test___isa {
    assert_isa('Moose::Object', $obj);
    assert_true($obj->does("IO::Moose::Seekable"), 'obj->does("IO::Moose::Seekable")');
};

sub test___Fcntl {
    assert_not_null(eval { __PACKAGE__->SEEK_SET });
    assert_not_null(eval { __PACKAGE__->SEEK_CUR });
    assert_not_null(eval { __PACKAGE__->SEEK_END });
};

sub test_new_empty {
    my $obj = IO::Moose::SeekableTest::Test1->new;
    assert_isa('IO::Moose::SeekableTest::Test1', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test_seek {
    {
        my $c = $obj->getc;
        assert_equals('p', $c);  # <p>ackage
    };

    {
        assert_true($obj->seek(2, eval { __PACKAGE__->SEEK_SET }));
        my $c = $obj->getc;
        assert_equals('c', $c);  # pa<c>kage
    };

    {
        assert_true($obj->seek(2, eval { __PACKAGE__->SEEK_CUR }));
        my $c = $obj->getc;
        assert_equals('g', $c);  # packa<g>e
    };

    {
        assert_true($obj->seek(-2, eval { __PACKAGE__->SEEK_END}));
        my $c = $obj->getc;
        assert_equals(';', $c);  # 1<;>\n
    };

    $obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        $obj->seek(0, eval { __PACKAGE__->SEEK_SET });
    } );
};

sub test_seek_tied {
    {
        my $c = $obj->getc;
        assert_equals('p', $c);  # <p>ackage
    };

    {
        assert_true(seek $obj, 2, eval { __PACKAGE__->SEEK_SET });
        my $c = $obj->getc;
        assert_equals('c', $c);  # pa<c>kage
    };

    {
        assert_true(seek $obj, 2, eval { __PACKAGE__->SEEK_CUR });
        my $c = $obj->getc;
        assert_equals('g', $c);  # packa<g>e
    };

    {
        assert_true(seek $obj, -2, eval { __PACKAGE__->SEEK_END });
        my $c = $obj->getc;
        assert_equals(';', $c);  # 1<;>\n
    };

    $obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        seek $obj, 0, eval { __PACKAGE__->SEEK_SET };
    } );
};

sub test_seek_fail {
    open my $fh_out, '<&=1' or return;

    $obj = IO::Moose::SeekableTest::Test1->new;
    assert_isa('IO::Moose::SeekableTest::Test1', $obj);
    assert_equals('GLOB', reftype $obj);

    $obj->fdopen($fh_out, 'r');
    assert_not_null($obj->fileno);

    assert_raises( ['Exception::IO'], sub {
        $obj->seek(0, eval { __PACKAGE__->SEEK_SET });
    } );

    $obj->close;

    close $fh_out;
};

sub test_seek_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Seekable->seek(1, 2);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->seek;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->seek(1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->seek('STRING', 2);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->seek(1, 'STRING');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->seek(1, 2, 3);
    } );
};

sub test_sysseek {
    {
        $obj->sysread(my $c, 1);
        assert_equals('p', $c);  # <p>ackage
    };

    {
        my $p = $obj->sysseek(0, eval { __PACKAGE__->SEEK_SET });
        assert_num_equals(0, $p);
        $obj->sysread(my $c, 1);
        assert_equals('p', $c);  # <p>ackage
    };

    {
        my $p = $obj->sysseek(2, eval { __PACKAGE__->SEEK_SET });
        assert_equals(2, $p);
        $obj->sysread(my $c, 1);
        assert_equals('c', $c);  # pa<c>kage
    };

    {
        my $p = $obj->sysseek(2, eval { __PACKAGE__->SEEK_CUR });
        assert_equals(5, $p);
        $obj->sysread(my $c, 1);
        assert_equals('g', $c);  # packa<g>e
    };

    {
        my $p = $obj->sysseek(-2, eval { __PACKAGE__->SEEK_END });
        assert_true($p > 6000, '$p > 6000'); # this file length
    };

    {
        $obj->sysread(my $c, 1);
        assert_equals(';', $c);  # 1<;>\n
    };

    $obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        $obj->sysseek(0, eval { __PACKAGE__->SEEK_SET });
    } );
};

sub test_sysseek_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Seekable->sysseek(1, 2);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->sysseek;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->sysseek(1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->sysseek('STRING', 2);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->sysseek(1, 'STRING');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->sysseek(1, 2, 3);
    } );
};

sub test_tell {
    {
        my $p = $obj->tell;
        assert_equals(0, $p);
        assert_num_equals(0, $p);
    };

    {
        my $c = $obj->readline;
        assert_not_equals(0, length $c);

        my $p = $obj->tell;
        assert_not_equals(0, $p);
        assert_equals(length $c, $p);
    };

    $obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        $obj->tell;
    } );
};

sub test_tell_tied {
    {
        my $p = tell $obj;
        assert_equals(0, $p);
        assert_num_equals(0, $p);
    };

    {
        my $c = $obj->readline;
        assert_not_equals(0, length $c);

        my $p = tell $obj;
        assert_not_equals(0, $p);
        assert_equals(length $c, $p);
    };

    $obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        tell $obj;
    } );
};

sub test_tell_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Seekable->tell;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->tell(1);
    } );
};

sub test_getpos_setpos {
    my $p = $obj->getpos;
    assert_equals(0, $p);

    {
        my $c1 = $obj->getc;
        assert_equals('p', $c1);  # <p>ackage

        my $p2 = $obj->setpos($p);
        assert_true($p2, '$obj->setpos($p)');

        my $c2 = $obj->getc;
        assert_equals('p', $c2);  # <p>ackage
    };

    {
        my $p1 = $obj->getpos;
        assert_true($p1, '$obj->getpos');

        my $c1 = $obj->getc;
        assert_equals('a', $c1);  # p<a>ckage

        my $p2 = $obj->setpos($p1);
        assert_true($p2, '$obj->setpos($p1)');

        my $c2 = $obj->getc;
        assert_equals('a', $c2);  # p<a>ckage
    };

    $obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        $obj->getpos;
    } );

    assert_raises( ['Exception::Fatal'], sub {
        $obj->setpos($p);
    } );
};

sub test_getpos_fail {
    open my $fh_out, '<&=1' or return;

    $obj = IO::Moose::SeekableTest::Test1->new;
    assert_isa('IO::Moose::SeekableTest::Test1', $obj);
    assert_equals('GLOB', reftype $obj);

    $obj->fdopen($fh_out, 'r');
    assert_not_null($obj->fileno);

    assert_raises( ['Exception::IO'], sub {
        my $p = $obj->getpos;
        assert_equals(0, $p);

        $obj->setpos($p);
    } );
};

sub test_getpos_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Seekable->getpos;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->getpos(1);
    } );
};

sub test_setpos_error_args {
    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Seekable->setpos(1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->setpos;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->setpos('STRING');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $obj->setpos(1, 2);
    } );
};

1;
