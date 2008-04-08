package IO::Moose::SeekableTest;

use strict;
use warnings;

use base 'Test::Unit::TestCase';

use IO::Moose::Handle;
use Exception::Base ':all',
    'Exception::IO' => { isa => 'Exception::System' };

use File::Temp 'tempfile';

use Scalar::Util 'reftype';

BEGIN { eval "use Fcntl 'SEEK_SET', 'SEEK_CUR', 'SEEK_END';"; }

{
    package IO::Moose::SeekableTest::Test1;

    use Moose;
    use Scalar::Util 'reftype';

    extends 'MooseX::GlobRef::Object';

    with 'IO::Moose::Seekable';
    
    sub fdopen {
	my $self = shift;
	my ($fd, $mode) = @_;
	my $hashref = ${*$self};
	$mode = "<" unless $mode;
	CORE::open $hashref->{fh}, "$mode&", *$fd;
    }

    sub close {
	my $self = shift;
	my $hashref = ${*$self};
	CORE::close $hashref->{fh};
    }

    sub fileno {
	my $self = shift;
	my $hashref = ${*$self};
	return CORE::fileno $hashref->{fh};
    }
    
    sub readline {
	my $self = shift;
	my $hashref = ${*$self};
	return CORE::readline $hashref->{fh};
    }
    
    sub getc {
	my $self = shift;
	my $hashref = ${*$self};
	return CORE::getc $hashref->{fh};
    }

    sub sysread {
	my $self = shift;
	my $hashref = ${*$self};
	return defined $_[2]
	    ? CORE::sysread $hashref->{fh}, $_[0], $_[1], $_[2]
	    : CORE::sysread $hashref->{fh}, $_[0], $_[1];
    }
}

my ($filename_in, $fh_in, $filename_out, $fh_out);

sub set_up {
    $filename_in = __FILE__;
    ((my $tmp), $filename_out) = tempfile;
    select select $fh_in;
    select select $fh_out;
}

sub tear_down {
    close $fh_in;
    close $fh_out;
    unlink $filename_out;
}

sub test___isa {
    my $self = shift;
    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
}

sub test___Fcntl {
    my $self = shift;
    $self->assert_not_null(eval "SEEK_SET", 'SEEK_SET');
    $self->assert_not_null(eval "SEEK_CUR", 'SEEK_CUR');
    $self->assert_not_null(eval "SEEK_END", 'SEEK_END');
    $self->assert_not_equals(eval "SEEK_SET", eval "SEEK_CUR");
    $self->assert_not_equals(eval "SEEK_SET", eval "SEEK_END");
    $self->assert_not_equals(eval "SEEK_CUR", eval "SEEK_END");
}

sub test_new_empty {
    my $self = shift;
    my $obj = IO::Moose::SeekableTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::SeekableTest::Test1"), '$obj->isa("IO::Moose::SeekableTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
}

sub test_seek {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw Exception::IO;

    my $obj = IO::Moose::SeekableTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::SeekableTest::Test1"), '$obj->isa("IO::Moose::SeekableTest::Test1")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::SeekableTest::Test1"), '$obj->isa("IO::Moose::SeekableTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    my $c1 = $obj->getc;
    $self->assert_equals('p', $c1);  # <p>ackage

    my $c2 = $obj->seek(2, eval "SEEK_SET");
    $self->assert_equals(1, $c2);
    my $c3 = $obj->getc;
    $self->assert_equals('c', $c3);  # pa<c>kage

    my $c4 = $obj->seek(2, eval "SEEK_CUR");
    $self->assert_equals(1, $c4);
    my $c5 = $obj->getc;
    $self->assert_equals('g', $c5);  # packa<g>e

    my $c6 = $obj->seek(-2, eval "SEEK_END");
    $self->assert_equals(1, $c6);
    my $c7 = $obj->getc;
    $self->assert_equals(';', $c7);  # 1<;>\n

    $obj->close;

    try eval { $obj->tell; };
    catch my $e1;
    $self->assert_equals('Exception::Fatal', ref $e1);

    # tear down
    close $fh_in;
}

sub test_seek_fail {
    my $self = shift;

    # set up
    open $fh_out, '<&=1' or throw Exception::IO;

    my $obj = IO::Moose::SeekableTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::SeekableTest::Test1"), '$obj->isa("IO::Moose::SeekableTest::Test1")');
    $obj->fdopen($fh_out);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::SeekableTest::Test1"), '$obj->isa("IO::Moose::SeekableTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    try eval { $obj->seek(0, eval "SEEK_SET") };
    catch my $e1;
    $self->assert_equals('Exception::IO', ref $e1);

    $obj->close;

    # tear down
    close $fh_out;
}

sub test_sysseek {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw Exception::IO;

    my $obj = IO::Moose::SeekableTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::SeekableTest::Test1"), '$obj->isa("IO::Moose::SeekableTest::Test1")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::SeekableTest::Test1"), '$obj->isa("IO::Moose::SeekableTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    $obj->sysread(my $c1, 1);
    $self->assert_equals('p', $c1);  # <p>ackage

    my $c2 = $obj->sysseek(0, eval "SEEK_SET");
    $self->assert($c2, '$obj->sysseek(0, SEEK_SET)');
    $self->assert_num_equals(0, $c2);
    $obj->sysread(my $c3, 1);
    $self->assert_equals('p', $c3);  # <p>ackage

    my $c4 = $obj->sysseek(2, eval "SEEK_SET");
    $self->assert_equals(2, $c4);
    $obj->sysread(my $c5, 1);
    $self->assert_equals('c', $c5);  # pa<c>kage

    my $c6 = $obj->sysseek(2, eval "SEEK_CUR");
    $self->assert_equals(5, $c6);
    $obj->sysread(my $c7, 1);
    $self->assert_equals('g', $c7);  # packa<g>e

    my $c8 = $obj->sysseek(-2, eval "SEEK_END");
    $self->assert($c8 > 6000, '$c6 > 6000'); # this file length
    $obj->sysread(my $c9, 1);
    $self->assert_equals(';', $c9);  # 1<;>\n

    $obj->close;

    try eval { $obj->tell; };
    catch my $e1;
    $self->assert_equals('Exception::Fatal', ref $e1);

    # tear down
    close $fh_in;
}

sub test_tell {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw Exception::IO;

    my $obj = IO::Moose::SeekableTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::SeekableTest::Test1"), '$obj->isa("IO::Moose::SeekableTest::Test1")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::SeekableTest::Test1"), '$obj->isa("IO::Moose::SeekableTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    my $c1 = $obj->tell;
    $self->assert($c1, '$obj->tell');
    $self->assert_num_equals(0, $c1);

    my $c2 = $obj->readline;
    $self->assert_not_equals(0, length $c2);
    
    my $c3 = $obj->tell;
    $self->assert_not_equals(0, $c3);
    $self->assert_equals(length $c2, $c3);

    $obj->close;

    try eval { $obj->tell; };
    catch my $e1;
    $self->assert_equals('Exception::Fatal', ref $e1);

    # tear down
    close $fh_in;
}

sub test_getpos_setpos {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw Exception::IO;

    my $obj = IO::Moose::SeekableTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::SeekableTest::Test1"), '$obj->isa("IO::Moose::SeekableTest::Test1")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::SeekableTest::Test1"), '$obj->isa("IO::Moose::SeekableTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    my $p1 = $obj->getpos;
    $self->assert($p1, '$obj->getpos');

    my $c2 = $obj->getc;
    $self->assert_equals('p', $c2);  # <p>ackage

    my $c3 = $obj->setpos($p1);
    $self->assert($c3, '$obj->setpos($p1)');

    my $c4 = $obj->getc;
    $self->assert_equals('p', $c4);  # <p>ackage

    my $p5 = $obj->getpos;
    $self->assert($p5, '$obj->getpos');
    my $c6 = $obj->getc;
    $self->assert_equals('a', $c6);  # p<a>ckage

    my $c7 = $obj->setpos($p5);
    $self->assert($c7, '$obj->setpos($p5)');

    my $c8 = $obj->getc;
    $self->assert_equals('a', $c8);  # p<a>ckage

    $obj->close;

    try eval { $obj->getpos; };
    catch my $e1;
    $self->assert_equals('Exception::Fatal', ref $e1);

    try eval { $obj->setpos($p1); };
    catch my $e2;
    $self->assert_equals('Exception::Fatal', ref $e2);

    # tear down
    close $fh_in;
}

sub test_getpos_fail {
    my $self = shift;

    # set up
    open $fh_out, '<&=1' or throw Exception::IO;

    my $obj = IO::Moose::SeekableTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::SeekableTest::Test1"), '$obj->isa("IO::Moose::SeekableTest::Test1")');
    $obj->fdopen($fh_out);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::SeekableTest::Test1"), '$obj->isa("IO::Moose::SeekableTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    my $p1 = $obj->getpos;
    $self->assert($p1, '$obj->getpos');

    try eval { $obj->setpos($p1) };
    catch my $e1;
    $self->assert_equals('Exception::IO', ref $e1);

    $obj->close;

    # tear down
    close $fh_out;
}

1;
