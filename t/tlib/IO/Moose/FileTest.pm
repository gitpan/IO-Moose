package IO::Moose::FileTest;

use strict;
use warnings;

use base 'Test::Unit::TestCase';

use IO::Moose::Handle;
use Exception::Base ':all',
    'Exception::IO' => { isa => 'Exception::System' };

use File::Temp 'tempfile';

use Scalar::Util 'reftype', 'openhandle';

{
    package IO::Moose::FileTest::Test1;

    use Moose;

    extends 'IO::Moose::File';
    
    sub readline {
	my $self = shift;
	my $hashref = ${*$self};
	return CORE::readline $hashref->{fh};
    }
    
    sub read {
	my $self = shift;
	my $hashref = ${*$self};
	return defined $_[2]
	       ? CORE::read $hashref->{fh}, $_[0], $_[1], $_[2]
	       : CORE::read $hashref->{fh}, $_[0], $_[1];
    }
    
    sub print {
	my $self = shift;
	my $hashref = ${*$self};
	return CORE::print { $hashref->{fh} } @_;
    }
    
    sub getc {
	my $self = shift;
	my $hashref = ${*$self};
	return CORE::getc $hashref->{fh};
    }
    
    sub seek {
	my $self = shift;
	my $hashref = ${*$self};
	return CORE::seek $hashref->{fh}, $_[0], $_[1];
    }
}

my ($filename_in, $filename_out);

sub set_up {
    $filename_in = __FILE__;
    ((my $tmp), $filename_out) = tempfile;
}

sub tear_down {
    unlink $filename_out;
}

sub test___isa {
    my $self = shift;
    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
}

sub test_new_empty {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
}

sub test_new_open_default {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new(filename => $filename_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null(openhandle $obj->fh);
    $self->assert_equals("package IO::Moose::FileTest;\n", $obj->readline);
}

sub test_new_open_write {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new(filename => $filename_out, mode => '+>');
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_equals($filename_out, $obj->filename);
    $self->assert_equals("+>", $obj->mode);
    $self->assert_not_null(openhandle $obj->fh);
    $obj->print("test_new_open_write");
    $self->assert_equals(1, $obj->seek(0, 0));
    $self->assert_equals("test_new_open_write", $obj->readline);
}

sub test_new_open_layer {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new(filename => $filename_in, layer => ':crlf');
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_equals($filename_in, $obj->filename);
    $self->assert_equals(":crlf", $obj->layer);
    $self->assert_not_null(openhandle $obj->fh);
    $self->assert_equals("package IO::Moose::FileTest;\n", $obj->readline);
}

sub test_new_fail {
    my $self = shift;

    try eval { my $obj1 = IO::Moose::FileTest::Test1->new(filename => 'nosuchfile_abcdef'.$$) };
    catch my $e1;
    $self->assert_equals('Exception::IO', ref $e1);

    try eval { my $obj2 = IO::Moose::FileTest::Test1->new(filename => $filename_in, mode => 'badmode') };
    catch my $e2;
    $self->assert_equals('Exception::Base', ref $e2);

    try eval { my $obj3 = IO::Moose::FileTest::Test1->new(filename => $filename_in, layer => 'badmode') };
    catch my $e3;
    $self->assert_equals('Exception::Base', ref $e3);

    try eval { my $obj3 = IO::Moose::FileTest::Test1->new(filename => $filename_in, mode => 0, perms => 'badperms') };
    catch my $e4;
    $self->assert_equals('Exception::Base', ref $e4);
}

sub test_new_tmpfile {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new_tmpfile;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null(openhandle $obj->fh);
    $obj->print("test_new_open_write");
    $self->assert_equals(1, $obj->seek(0, 0));
    $self->assert_equals("test_new_open_write", $obj->readline);
}

sub test_open_default {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_in);
    $self->assert_equals($filename_in, $obj->filename);
    $self->assert_not_null(openhandle $obj->fh);
    $self->assert_equals("package IO::Moose::FileTest;\n", $obj->readline);
}

sub test_open_default_tied {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    open $obj, $filename_in;
    $self->assert_equals($filename_in, $obj->filename);
    $self->assert_not_null(openhandle $obj->fh);
    $self->assert_equals("package IO::Moose::FileTest;\n", $obj->readline);
}

sub test_open_write {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_out, '+>');
    $self->assert_equals($filename_out, $obj->filename);
    $self->assert_equals("+>", $obj->mode);
    $self->assert_not_null(openhandle $obj->fh);
    $obj->print("test_new_open_write");
    $self->assert_equals(1, $obj->seek(0, 0));
    $self->assert_equals("test_new_open_write", $obj->readline);
}

sub test_open_write_tied {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    open $obj, $filename_out, '+>';
    $self->assert_equals($filename_out, $obj->filename);
    $self->assert_equals("+>", $obj->mode);
    $self->assert_not_null(openhandle $obj->fh);
    $obj->print("test_new_open_write");
    $self->assert_equals(1, $obj->seek(0, 0));
    $self->assert_equals("test_new_open_write", $obj->readline);
}

sub test_open_layer {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_out, '+>:crlf');
    $self->assert_equals($filename_out, $obj->filename);
    $self->assert_equals("+>", $obj->mode);
    $self->assert_equals(":crlf", $obj->layer);
    $self->assert_not_null(openhandle $obj->fh);
}

sub test_open_sysopen {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_in, 0);
    $self->assert_equals($filename_in, $obj->filename);
    $self->assert_num_equals(0, $obj->mode);
    $self->assert_not_null(openhandle $obj->fh);
    $self->assert_equals("package IO::Moose::FileTest;\n", $obj->readline);
}

sub test_open_sysopen_perms {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_in, 0, 0111);
    $self->assert_equals($filename_in, $obj->filename);
    $self->assert_num_equals(0, $obj->mode);
    $self->assert_num_equals(0111, $obj->perms);
    $self->assert_not_null(openhandle $obj->fh);
}

sub test_open_fail {
    my $self = shift;

    my $obj = IO::Moose::FileTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);

    try eval { $obj->open('nosuchfile_abcdef'.$$) };
    catch my $e1;
    $self->assert_equals('Exception::IO', ref $e1);

    try eval { $obj->open($filename_in, 'badmode') };
    catch my $e2;
    $self->assert_equals('Exception::Fatal', ref $e2);

    try eval { $obj->open($filename_in, 0, 'badperms') };
    catch my $e3;
    $self->assert_equals('Exception::Fatal', ref $e3);
}

sub test_binmode {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_out, '+>');
    $self->assert_not_null(openhandle $obj->fh);
    $obj->binmode;
    $obj->print("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020");
    $self->assert_equals(1, $obj->seek(0, 0));
    my $c;
    $obj->read($c, 17);
    $self->assert_equals("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020", $c);
}

sub test_binmode_tied {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_out, '+>');
    $self->assert_not_null(openhandle $obj->fh);
    binmode $obj;
    $obj->print("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020");
    $self->assert_equals(1, $obj->seek(0, 0));
    my $c;
    $obj->read($c, 17);
    $self->assert_equals("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020", $c);
}

sub test_binmode_layer {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_out, '+>');
    $self->assert_not_null(openhandle $obj->fh);
    $obj->binmode(':crlf');
    $self->assert_equals(":crlf", $obj->layer);
    $obj->print("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020");
    $self->assert_equals(1, $obj->seek(0, 0));
    my $c;
    $obj->read($c, 17);
    $self->assert_equals("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020", $c);
}

sub test_binmode_layer_tied {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_out, '+>');
    $self->assert_not_null(openhandle $obj->fh);
    binmode $obj, ':crlf';
    $self->assert_equals(":crlf", $obj->layer);
    $obj->print("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020");
    $self->assert_equals(1, $obj->seek(0, 0));
    my $c;
    $obj->read($c, 17);
    $self->assert_equals("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020", $c);
}

sub test_binmode_fail {
    my $self = shift;
    my $obj = IO::Moose::FileTest::Test1->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::FileTest::Test1"), '$obj->isa("IO::Moose::FileTest::Test1")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_out, '+>');
    $self->assert_not_null(openhandle $obj->fh);

    try eval { $obj->binmode('badlayer') };
    catch my $e1;
    $self->assert_equals('Exception::Base', ref $e1);

    $obj->close;

    try eval { $obj->binmode(':crlf') };
    catch my $e2;
    $self->assert_equals('Exception::Fatal', ref $e2)
	if $^V ge v5.8;
}

1;
