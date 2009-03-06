package IO::Moose::FileTest;

use strict;
use warnings;

use Test::Unit::Lite;
use parent 'Test::Unit::TestCase';

use Test::Assert ':all';

use IO::Moose::File;

use File::Spec;
use File::Temp;

use Scalar::Util 'reftype', 'openhandle', 'tainted';

my ($filename_in, $filename_out, @filenames_out);

sub set_up {
    $filename_in = __FILE__;
    (undef, $filename_out) = File::Temp::tempfile( 'XXXXXXXX', DIR => File::Spec->tmpdir );
    push @filenames_out, $filename_out;
};

sub DESTROY {
    unlink foreach @filenames_out;
};

sub tear_down {
    unlink $filename_out;
};

sub test___isa {
    my $obj = IO::Moose::File->new;
    assert_isa('IO::File', $obj);
    assert_isa('IO::Handle', $obj);
    assert_isa('IO::Seekable', $obj);
    assert_isa('IO::Moose::File', $obj);
    assert_isa('IO::Moose::Handle', $obj);
    assert_isa('IO::Moose::Seekable', $obj);
    assert_isa('Moose::Object', $obj);
    assert_isa('MooseX::GlobRef::Object', $obj);
    assert_equals('GLOB', reftype $obj);
};

sub test___api {
    my @api = grep { ! /^_/ } @{ Class::Inspector->functions('IO::Moose::File') };
    assert_deep_equals( [ qw{
        BINMODE
        OPEN
        binmode
        close
        file
        has_file
        has_layer
        has_mode
        has_perms
        has_sysmode
        layer
        meta
        mode
        new
        new_tmpfile
        open
        perms
        sysmode
        sysopen
    } ], \@api );
};

sub test_new_empty {
    my $obj = IO::Moose::File->new;
    assert_isa('IO::Moose::File', $obj);
    assert_equals('GLOB', reftype $obj);
    assert_null(openhandle $obj->fh);

    assert_null($obj->file);
};

sub test_new_open_default {
    my $obj = IO::Moose::File->new( file => $filename_in );
    assert_isa('IO::Moose::File', $obj);

    assert_equals("package IO::Moose::FileTest;\n", $obj->readline);
};

sub test_new_open_write {
    my $obj = IO::Moose::File->new( file => $filename_out, mode => '+>' );
    assert_isa('IO::Moose::File', $obj);

    assert_equals($filename_out, $obj->file);
    assert_equals("+>", $obj->mode);

    $obj->print("test_new_open_write\n");

    assert_true($obj->seek(0, 0));
    assert_equals("test_new_open_write\n", $obj->readline);
};

sub test_new_open_layer {
    my $obj = IO::Moose::File->new( file => $filename_in, layer => ':crlf' );
    assert_isa('IO::Moose::File', $obj);

    assert_equals($filename_in, $obj->file);
    assert_equals(":crlf", $obj->layer);

    assert_equals("package IO::Moose::FileTest;\n", $obj->readline);
};

sub test_new_sysopen_no_tied {
    my $obj = IO::Moose::File->new( file => $filename_in, sysmode => 0, tied => 0 );
    assert_isa('IO::Moose::File', $obj);

    assert_equals("package IO::Moose::FileTest;\n", $obj->readline);
};

sub test_new_error_io {
    assert_raises( ['Exception::IO'], sub {
        IO::Moose::File->new( file => 'nosuchfile_abcdef'.$$ );
    } );
};

sub test_new_error_args {
    assert_raises( qr/does not pass the type constraint/, sub {
        IO::Moose::File->new( file => $filename_in, mode => 'badmode' );
    } );

    assert_raises( qr/does not pass the type constraint/, sub {
        IO::Moose::File->new( file => $filename_in, layer => 'badmode' );
    } );

    assert_raises( qr/does not pass the type constraint/, sub {
        IO::Moose::File->new( file => $filename_in, mode => 0, perms => 'badperms' );
    } );
};

sub test_new_tmpfile {
    my $obj = IO::Moose::File->new_tmpfile;
    assert_isa('IO::Moose::File', $obj);

    $obj->print("test_new_open_write");

    assert_not_null($obj->seek(0, 0));
    assert_equals("test_new_open_write", $obj->readline);
};

sub test_new_tmpfile_args {
    my $obj = IO::Moose::File->new_tmpfile( SUFFIX => $$, output_record_separator => '.' );
    assert_isa('IO::Moose::File', $obj);
    $obj->print("test_new_open_write");

    assert_not_null($obj->seek(0, 0));
    assert_equals("test_new_open_write.", $obj->readline);
};

sub test_new_tmpfile_error_io {
    assert_raises( ['Exception::Fatal'], sub {
        IO::Moose::File->new_tmpfile( DIR => '/nosuchdir_abcdef'.$$ );
    } );
};

sub test_slurp_wantscalar_static_tainted {
    my $c = IO::Moose::File->slurp( file => $filename_in, tainted => 1, autochomp => 1 );
    assert_true(length $c > 1, 'length $c > 1');
    assert_true($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');
    assert_matches(qr/\n$/s, $c);

    if (${^TAINT}) {
        assert_true(tainted $c);
    };
};

sub test_slurp_wantscalar_static_untainted {
    my $c = IO::Moose::File->slurp( file => $filename_in, tainted => 0, autochomp => 1 );
    assert_true(length $c > 1, 'length $c > 1');
    assert_true($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');
    assert_matches(qr/\n$/s, $c);

    if (${^TAINT}) {
        assert_false(tainted $c);
    };
};

sub test_slurp_wantarray_static_tainted {
    my @c = IO::Moose::File->slurp( file => $filename_in, tainted => 1, autochomp => 1 );
    assert_true(@c > 1, '@c > 1');
    assert_true($c[0] =~ tr/\n// == 0, '$c[0] =~ tr/\n// == 0');

    if (${^TAINT}) {
        assert_true(tainted $c[0]);
    };
};

sub test_slurp_wantarray_static_untainted {
    my @c = IO::Moose::File->slurp( file => $filename_in, tainted => 0, autochomp => 1 );
    assert_true(@c > 1, '@c > 1');
    assert_true($c[0] =~ tr/\n// == 0, '$c[0] =~ tr/\n// == 0');

    if (${^TAINT}) {
        assert_false(tainted $c[0]);
    };
};

1;
