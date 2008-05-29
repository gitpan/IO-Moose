package IO::Moose::FileTest;

use strict;
use warnings;

use base 'Test::Unit::TestCase';

use IO::Moose::Handle;
use Exception::Base;

use File::Temp 'tempfile';

use Scalar::Util 'reftype', 'openhandle';

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
    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
}

sub test_new_open_default {
    my $self = shift;
    my $obj = IO::Moose::File->new(filename => $filename_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null(openhandle $obj->fh);
    $self->assert_equals("package IO::Moose::FileTest;\n", $obj->readline);
}

sub test_new_open_write {
    my $self = shift;
    my $obj = IO::Moose::File->new(filename => $filename_out, mode => '+>');
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_equals($filename_out, $obj->filename);
    $self->assert_equals("+>", $obj->mode);
    $self->assert_not_null(openhandle $obj->fh);
    $obj->print("test_new_open_write");
    $self->assert_not_null($obj->seek(0, 0));
    $self->assert_equals("test_new_open_write", $obj->readline);
}

sub test_new_open_layer {
    my $self = shift;
    my $obj = IO::Moose::File->new(filename => $filename_in, layer => ':crlf');
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_equals($filename_in, $obj->filename);
    $self->assert_equals(":crlf", $obj->layer);
    $self->assert_not_null(openhandle $obj->fh);
    $self->assert_equals("package IO::Moose::FileTest;\n", $obj->readline);
}

sub test_new_fail {
    my $self = shift;

    eval { my $obj1 = IO::Moose::File->new(filename => 'nosuchfile_abcdef'.$$) };
    my $e1 = Exception::Base->catch;
    $self->assert_equals('Exception::IO', ref $e1);

    eval { my $obj2 = IO::Moose::File->new(filename => $filename_in, mode => 'badmode') };
    my $e2 = Exception::Base->catch;
    $self->assert_not_equals('', ref $e2);

    eval { my $obj3 = IO::Moose::File->new(filename => $filename_in, layer => 'badmode') };
    my $e3 = Exception::Base->catch;
    $self->assert_not_equals('', ref $e3);

    eval { my $obj3 = IO::Moose::File->new(filename => $filename_in, mode => 0, perms => 'badperms') };
    my $e4 = Exception::Base->catch;
    $self->assert_not_equals('', ref $e4);
}

sub test_new_tmpfile {
    my $self = shift;
    my $obj = IO::Moose::File->new_tmpfile;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null(openhandle $obj->fh);
    $obj->print("test_new_open_write");
    $self->assert_not_null($obj->seek(0, 0));
    $self->assert_equals("test_new_open_write", $obj->readline);
}

sub test_open_default {
    my $self = shift;
    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_in);
    $self->assert_equals($filename_in, $obj->filename);
    $self->assert_not_null(openhandle $obj->fh);
    $self->assert_equals("package IO::Moose::FileTest;\n", $obj->readline);
}

sub test_open_default_tied {
    my $self = shift;
    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    open $obj, $filename_in;
    $self->assert_equals($filename_in, $obj->filename);
    $self->assert_not_null(openhandle $obj->fh);
    $self->assert_equals("package IO::Moose::FileTest;\n", $obj->readline);
}

sub test_open_write {
    my $self = shift;
    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_out, '+>');
    $self->assert_equals($filename_out, $obj->filename);
    $self->assert_equals("+>", $obj->mode);
    $self->assert_not_null(openhandle $obj->fh);
    $obj->print("test_new_open_write");
    $self->assert_not_null($obj->seek(0, 0));
    $self->assert_equals("test_new_open_write", $obj->readline);
}

sub test_open_write_tied {
    my $self = shift;
    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    open $obj, $filename_out, '+>';
    $self->assert_equals($filename_out, $obj->filename);
    $self->assert_equals("+>", $obj->mode);
    $self->assert_not_null(openhandle $obj->fh);
    $obj->print("test_new_open_write");
    $self->assert_not_null($obj->seek(0, 0));
    $self->assert_equals("test_new_open_write", $obj->readline);
}

sub test_open_layer {
    my $self = shift;
    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
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
    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
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
    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
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

    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);

    eval { $obj->open('nosuchfile_abcdef'.$$) };
    my $e1 = Exception::Base->catch;
    $self->assert_equals('Exception::IO', ref $e1);

    eval { $obj->open($filename_in, 'badmode') };
    my $e2 = Exception::Base->catch;
    $self->assert_equals('Exception::Fatal', ref $e2);

    eval { $obj->open($filename_in, 0, 'badperms') };
    my $e3 = Exception::Base->catch;
    $self->assert_equals('Exception::Fatal', ref $e3);
}

sub test_binmode {
    my $self = shift;
    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_out, '+>');
    $self->assert_not_null(openhandle $obj->fh);
    $obj->binmode;
    $obj->print("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020");
    $self->assert_not_null($obj->seek(0, 0));
    my $c;
    $obj->read($c, 17);
    $self->assert_equals("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020", $c);
}

sub test_binmode_tied {
    my $self = shift;
    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_out, '+>');
    $self->assert_not_null(openhandle $obj->fh);
    binmode $obj;
    $obj->print("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020");
    $self->assert_not_null($obj->seek(0, 0));
    my $c;
    $obj->read($c, 17);
    $self->assert_equals("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020", $c);
}

sub test_binmode_layer {
    my $self = shift;
    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_out, '+>');
    $self->assert_not_null(openhandle $obj->fh);
    $obj->binmode(':crlf');
    $self->assert_equals(":crlf", $obj->layer);
    $obj->print("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020");
    $self->assert_not_null($obj->seek(0, 0));
    my $c;
    $obj->read($c, 17);
    $self->assert_equals("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020", $c);
}

sub test_binmode_layer_tied {
    my $self = shift;
    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_out, '+>');
    $self->assert_not_null(openhandle $obj->fh);
    binmode $obj, ':crlf';
    $self->assert_equals(":crlf", $obj->layer);
    $obj->print("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020");
    $self->assert_not_null($obj->seek(0, 0));
    my $c;
    $obj->read($c, 17);
    $self->assert_equals("\000\001\002\003\004\005\006\007\010\011\012\013\014\015\016\017\020", $c);
}

sub test_binmode_fail {
    my $self = shift;
    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null(openhandle $obj->fh);
    $obj->open($filename_out, '+>');
    $self->assert_not_null(openhandle $obj->fh);

    eval { $obj->binmode('badlayer') };
    my $e1 = Exception::Base->catch;
    $self->assert_not_equals('', ref $e1);

    $obj->close;

    eval { $obj->binmode(':crlf') };
    my $e2 = Exception::Base->catch;
    $self->assert_equals('Exception::Fatal', ref $e2)
        if $^V ge v5.8;
}

sub test_slurp_wantscalar_object {
    my $self = shift;

    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $obj->open($filename_in);
    $self->assert_equals($filename_in, $obj->filename);
    $self->assert_not_null(openhandle $obj->fh);

    if (${^TAINT}) {
        $obj->untaint;
    }

    my $c = $obj->slurp;
    $self->assert(length $c > 1, 'length $c > 1');
    $self->assert($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');

    if (${^TAINT}) {
        no warnings;
        kill 0 * $c;
    }

    $obj->close;
}

sub test_slurp_wantarray_object {
    my $self = shift;

    my $obj = IO::Moose::File->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::File"), '$obj->isa("IO::Moose::File")');
    $obj->open($filename_in);
    $self->assert_equals($filename_in, $obj->filename);
    $self->assert_not_null(openhandle $obj->fh);

    if (${^TAINT}) {
        $obj->untaint;
    }

    my @c = $obj->slurp;
    $self->assert(@c > 1, '@c > 1');
    $self->assert($c[0] =~ tr/\n// == 1, '$c[0] =~ tr/\n// == 1');

    if (${^TAINT}) {
        no warnings;
        kill 0 * $c[0];
    }

    $obj->close;
}

sub test_slurp_wantscalar_static {
    my $self = shift;

    my $c = IO::Moose::File->slurp($filename_in, untaint => 1, autochomp => 1);
    $self->assert(length $c > 1, 'length $c > 1');
    $self->assert($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');
    $self->assert_matches(qr/\n$/s, $c);

    if (${^TAINT}) {
        no warnings;
        kill 0 * $c;
    }
}

sub test_slurp_wantarray_static {
    my $self = shift;

    my @c = IO::Moose::File->slurp($filename_in, untaint => 1, autochomp => 1);
    $self->assert(@c > 1, '@c > 1');
    $self->assert($c[0] =~ tr/\n// == 0, '$c[0] =~ tr/\n// == 0');

    if (${^TAINT}) {
        no warnings;
        kill 0 * $c[0];
    }
}

1;
