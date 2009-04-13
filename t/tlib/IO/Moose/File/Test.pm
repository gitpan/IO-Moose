package IO::Moose::File::Test;

use Test::Unit::Lite;

use Moose;
extends 'Test::Unit::TestCase';

with 'IO::Moose::ReadableFilenameTestRole';
with 'IO::Moose::WritableFilenameTestRole';

use Test::Assert ':all';

use IO::Moose::File;

use Scalar::Util 'reftype', 'openhandle', 'tainted';

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
    my ($self) = @_;

    my $obj = IO::Moose::File->new;
    assert_isa('IO::Moose::File', $obj);
    assert_equals('GLOB', reftype $obj);
    assert_null(openhandle $obj->fh);

    assert_null($obj->file);
};

sub test_new_open_default {
    my ($self) = @_;

    my $obj = IO::Moose::File->new( file => $self->filename_in );
    assert_isa('IO::Moose::File', $obj);

    assert_matches(qr/^package IO::Moose::/, $obj->readline);
};

sub test_new_open_write {
    my ($self) = @_;

    my $obj = IO::Moose::File->new( file => $self->filename_out, mode => '+>' );
    assert_isa('IO::Moose::File', $obj);

    assert_equals($self->filename_out, $obj->file);
    assert_equals("+>", $obj->mode);

    $obj->print("test_new_open_write\n");

    assert_true($obj->seek(0, 0));
    assert_equals("test_new_open_write\n", $obj->readline);
};

sub test_new_open_layer {
    my ($self) = @_;

    my $obj = IO::Moose::File->new( file => $self->filename_in, layer => ':crlf' );
    assert_isa('IO::Moose::File', $obj);

    assert_equals($self->filename_in, $obj->file);
    assert_equals(":crlf", $obj->layer);

    assert_matches(qr/^package IO::Moose::/, $obj->readline);
};

sub test_new_sysopen_no_tied {
    my ($self) = @_;

    my $obj = IO::Moose::File->new( file => $self->filename_in, sysmode => 0, tied => 0 );
    assert_isa('IO::Moose::File', $obj);

    assert_matches(qr/^package IO::Moose::/, $obj->readline);
};

sub test_new_error_io {
    my ($self) = @_;

    assert_raises( ['Exception::IO'], sub {
        IO::Moose::File->new( file => 'nosuchfile_abcdef'.$$ );
    } );
};

sub test_new_error_args {
    my ($self) = @_;

    assert_raises( qr/does not pass the type constraint/, sub {
        IO::Moose::File->new( file => $self->filename_in, mode => 'badmode' );
    } );

    assert_raises( qr/does not pass the type constraint/, sub {
        IO::Moose::File->new( file => $self->filename_in, layer => 'badmode' );
    } );

    assert_raises( qr/does not pass the type constraint/, sub {
        IO::Moose::File->new( file => $self->filename_in, mode => 0, perms => 'badperms' );
    } );
};

sub test_new_tmpfile {
    my ($self) = @_;

    my $obj = IO::Moose::File->new_tmpfile;
    assert_isa('IO::Moose::File', $obj);

    $obj->print("test_new_open_write");

    assert_not_null($obj->seek(0, 0));
    assert_equals("test_new_open_write", $obj->readline);
};

sub test_new_tmpfile_args {
    my ($self) = @_;

    my $obj = IO::Moose::File->new_tmpfile( SUFFIX => $$, output_record_separator => '.' );
    assert_isa('IO::Moose::File', $obj);
    $obj->print("test_new_open_write");

    assert_not_null($obj->seek(0, 0));
    assert_equals("test_new_open_write.", $obj->readline);
};

sub test_new_tmpfile_error_io {
    my ($self) = @_;

    assert_raises( ['Exception::Fatal'], sub {
        IO::Moose::File->new_tmpfile( DIR => '/nosuchdir_abcdef'.$$ );
    } );
};

sub test_slurp_wantscalar_static_tainted {
    my ($self) = @_;

    my $c = IO::Moose::File->slurp( file => $self->filename_in, tainted => 1, autochomp => 1 );
    assert_true(length $c > 1, 'length $c > 1');
    assert_true($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');
    assert_matches(qr/\n$/s, $c);

    if (${^TAINT}) {
        assert_true(tainted $c);
    };
};

sub test_slurp_wantscalar_static_untainted {
    my ($self) = @_;

    my $c = IO::Moose::File->slurp( file => $self->filename_in, tainted => 0, autochomp => 1 );
    assert_true(length $c > 1, 'length $c > 1');
    assert_true($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');
    assert_matches(qr/\n$/s, $c);

    if (${^TAINT}) {
        assert_false(tainted $c);
    };
};

sub test_slurp_wantarray_static_tainted {
    my ($self) = @_;

    my @c = IO::Moose::File->slurp( file => $self->filename_in, tainted => 1, autochomp => 1 );
    assert_true(@c > 1, '@c > 1');
    assert_true($c[0] =~ tr/\n// == 0, '$c[0] =~ tr/\n// == 0');

    if (${^TAINT}) {
        assert_true(tainted $c[0]);
    };
};

sub test_slurp_wantarray_static_untainted {
    my ($self) = @_;

    my @c = IO::Moose::File->slurp( file => $self->filename_in, tainted => 0, autochomp => 1 );
    assert_true(@c > 1, '@c > 1');
    assert_true($c[0] =~ tr/\n// == 0, '$c[0] =~ tr/\n// == 0');

    if (${^TAINT}) {
        assert_false(tainted $c[0]);
    };
};

1;
