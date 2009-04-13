package IO::Moose::Seekable::Test;

use Test::Unit::Lite;

use Moose;
extends 'Test::Unit::TestCase';

with 'IO::Moose::ReadableOpenedTestRole';

use Test::Assert ':all';

use IO::Moose::Seekable;

use Scalar::Util 'reftype';

use maybe Fcntl => ':seek';

sub test___isa {
    my ($self) = @_;
    assert_isa('IO::Handle', $self->obj);
    assert_isa('IO::Seekable', $self->obj);
    assert_isa('IO::Moose::Handle', $self->obj);
    assert_isa('IO::Moose::Seekable', $self->obj);
    assert_isa('Moose::Object', $self->obj);
    assert_isa('MooseX::GlobRef::Object', $self->obj);
    assert_equals('GLOB', reftype $self->obj);
};

sub test___api {
    my @api = grep { ! /^_/ } @{ Class::Inspector->functions('IO::Moose::Seekable') };
    assert_deep_equals( [ qw{
        SEEK
        TELL
        getpos
        meta
        seek
        setpos
        sysseek
        tell
    } ], \@api );
};

sub test___Fcntl {
    assert_not_null(eval { __PACKAGE__->SEEK_SET });
    assert_not_null(eval { __PACKAGE__->SEEK_CUR });
    assert_not_null(eval { __PACKAGE__->SEEK_END });
};

sub test_new_empty {
    my $obj = IO::Moose::Seekable->new;
    assert_isa('IO::Moose::Seekable', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test_seek {
    my ($self) = @_;

    {
        my $c = $self->obj->getc;
        assert_equals('p', $c);  # <p>ackage
    };

    {
        assert_true($self->obj->seek(2, eval { __PACKAGE__->SEEK_SET }));
        my $c = $self->obj->getc;
        assert_equals('c', $c);  # pa<c>kage
    };

    {
        assert_true($self->obj->seek(2, eval { __PACKAGE__->SEEK_CUR }));
        my $c = $self->obj->getc;
        assert_equals('g', $c);  # packa<g>e
    };

    {
        assert_true($self->obj->seek(-2, eval { __PACKAGE__->SEEK_END}));
        my $c = $self->obj->getc;
        assert_equals(';', $c);  # 1<;>\n
    };

    $self->obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->seek(0, eval { __PACKAGE__->SEEK_SET });
    } );
};

sub test_seek_tied {
    my ($self) = @_;

    {
        my $c = $self->obj->getc;
        assert_equals('p', $c);  # <p>ackage
    };

    {
        assert_true(seek $self->obj, 2, eval { __PACKAGE__->SEEK_SET });
        my $c = $self->obj->getc;
        assert_equals('c', $c);  # pa<c>kage
    };

    {
        assert_true(seek $self->obj, 2, eval { __PACKAGE__->SEEK_CUR });
        my $c = $self->obj->getc;
        assert_equals('g', $c);  # packa<g>e
    };

    {
        assert_true(seek $self->obj, -2, eval { __PACKAGE__->SEEK_END });
        my $c = $self->obj->getc;
        assert_equals(';', $c);  # 1<;>\n
    };

    $self->obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        seek $self->obj, 0, eval { __PACKAGE__->SEEK_SET };
    } );
};

sub test_seek_fail {
    my ($self) = @_;

    # stdout
    open my $fh_out, '<&=1' or return;

    my $obj = IO::Moose::Seekable->new;
    assert_isa('IO::Moose::Seekable', $obj);
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
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Seekable->seek(1, 2);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->seek;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->seek(1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->seek('STRING', 2);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->seek(1, 'STRING');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->seek(1, 2, 3);
    } );
};

sub test_sysseek {
    my ($self) = @_;

    {
        $self->obj->sysread(my $c, 1);
        assert_equals('p', $c);  # <p>ackage
    };

    {
        my $p = $self->obj->sysseek(0, eval { __PACKAGE__->SEEK_SET });
        assert_num_equals(0, $p);
        $self->obj->sysread(my $c, 1);
        assert_equals('p', $c);  # <p>ackage
    };

    {
        my $p = $self->obj->sysseek(2, eval { __PACKAGE__->SEEK_SET });
        assert_equals(2, $p);
        $self->obj->sysread(my $c, 1);
        assert_equals('c', $c);  # pa<c>kage
    };

    {
        my $p = $self->obj->sysseek(2, eval { __PACKAGE__->SEEK_CUR });
        assert_equals(5, $p);
        $self->obj->sysread(my $c, 1);
        assert_equals('g', $c);  # packa<g>e
    };

    {
        my $l = (stat $self->filename_in)[7];
        assert_num_not_equals(0, $l);
        my $p = $self->obj->sysseek(-2, eval { __PACKAGE__->SEEK_END });
        assert_num_equals($l, $p + 2); # this file length
    };

    {
        $self->obj->sysread(my $c, 1);
        assert_equals(';', $c);  # 1<;>\n
    };

    $self->obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->sysseek(0, eval { __PACKAGE__->SEEK_SET });
    } );
};

sub test_sysseek_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Seekable->sysseek(1, 2);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->sysseek;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->sysseek(1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->sysseek('STRING', 2);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->sysseek(1, 'STRING');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->sysseek(1, 2, 3);
    } );
};

sub test_tell {
    my ($self) = @_;

    {
        my $p = $self->obj->tell;
        assert_equals(0, $p);
        assert_num_equals(0, $p);
    };

    {
        my $c = $self->obj->readline;
        assert_not_equals(0, length $c);

        my $p = $self->obj->tell;
        assert_not_equals(0, $p);
        assert_equals(length $c, $p);
    };

    $self->obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->tell;
    } );
};

sub test_tell_tied {
    my ($self) = @_;

    {
        my $p = tell $self->obj;
        assert_equals(0, $p);
        assert_num_equals(0, $p);
    };

    {
        my $c = $self->obj->readline;
        assert_not_equals(0, length $c);

        my $p = tell $self->obj;
        assert_not_equals(0, $p);
        assert_equals(length $c, $p);
    };

    $self->obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        tell $self->obj;
    } );
};

sub test_tell_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Seekable->tell;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->tell(1);
    } );
};

sub test_getpos_setpos {
    my ($self) = @_;

    my $p = $self->obj->getpos;
    assert_equals(0, $p);

    {
        my $c1 = $self->obj->getc;
        assert_equals('p', $c1);  # <p>ackage

        my $p2 = $self->obj->setpos($p);
        assert_true($p2, '$self->obj->setpos($p)');

        my $c2 = $self->obj->getc;
        assert_equals('p', $c2);  # <p>ackage
    };

    {
        my $p1 = $self->obj->getpos;
        assert_true($p1, '$self->obj->getpos');

        my $c1 = $self->obj->getc;
        assert_equals('a', $c1);  # p<a>ckage

        my $p2 = $self->obj->setpos($p1);
        assert_true($p2, '$self->obj->setpos($p1)');

        my $c2 = $self->obj->getc;
        assert_equals('a', $c2);  # p<a>ckage
    };

    $self->obj->close;

    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->getpos;
    } );

    assert_raises( ['Exception::Fatal'], sub {
        $self->obj->setpos($p);
    } );
};

sub test_getpos_fail {
    my ($self) = @_;

    # stdout
    open my $fh_out, '<&=1' or return;

    my $obj = IO::Moose::Seekable->new;
    assert_isa('IO::Moose::Seekable', $obj);
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
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Seekable->getpos;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->getpos(1);
    } );
};

sub test_setpos_error_args {
    my ($self) = @_;

    assert_raises( ['Exception::Argument'], sub {
        IO::Moose::Seekable->setpos(1);
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->setpos;
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->setpos('STRING');
    } );

    assert_raises( ['Exception::Argument'], sub {
        $self->obj->setpos(1, 2);
    } );
};

1;
