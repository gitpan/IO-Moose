#!/usr/bin/perl -c

package IO::Moose::File;

=head1 NAME

IO::Moose::File - Reimplementation of IO::File with improvements

=head1 SYNOPSIS

  use IO::Moose::File;
  my $file = IO::Moose::File->new( file => "/etc/passwd" );
  my @passwd = $file->getlines;

=head1 DESCRIPTION

This class provides an interface mostly compatible with L<IO::File>.  The
differences:

=over

=item *

It is based on L<Moose> object framework.

=item *

It uses L<Exception::Base> for signaling errors. Most of methods are throwing
exception on failure.

=item *

It doesn't export any constants.  Use L<Fcntl> instead.

=item *

It is pure-Perl implementation.

=back

=for readme stop

=cut


use 5.008;
use strict;
use warnings FATAL => 'all';

our $VERSION = 0.06;

use Moose;

extends 'IO::Moose::Handle';

with 'IO::Moose::Seekable';


use MooseX::Types::OpenModeWithLayerStr;
use MooseX::Types::PerlIOLayerStr;


use Exception::Base (
    '+ignore_package' => [ __PACKAGE__, 'Carp', 'File::Temp' ],
);


# TRUE and FALSE
use constant::boolean;

use Scalar::Util 'looks_like_number';


# For new_tmpfile
use File::Temp;


# Assertions
use Test::Assert ':assert';

# Debugging flag
use if $ENV{PERL_DEBUG_IO_MOOSE_FILE}, 'Smart::Comments';


# File can be also file name or File::Temp object
has '+file' => (
    isa     => 'Str | FileHandle | OpenHandle',
);

# File mode can be also a number or contain PerlIO layer string
has '+mode' => (
    isa     => 'Num | OpenModeWithLayerStr | CanonOpenModeStr',
);

# Deprecated: backward compatibility
has filename => (
    is  => 'ro',
    isa => 'Str',
);

# Unix perms number for newly created file
has perms => (
    is      => 'rw',
    isa     => 'Num',
    default => oct(666),
    reader  => 'perms',
    writer  => '_set_perms',
    clearer => '_clear_perms',
);

# PerlIO layer string
has layer => (
    is      => 'rw',
    isa     => 'PerlIOLayerStr',
    reader  => 'layer',
    writer  => '_set_layer',
);


## no critic (ProhibitBuiltinHomonyms)
## no critic (RequireArgUnpacking)
## no critic (RequireCheckingReturnValueOfEval)

# Overrided private method called by constructor
override '_open_file' => sub {
    #### _open_file: @_

    my ($self) = @_;

    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    # Open file with our method
    if (defined $hashref->{file}) {
        # call fdopen if fd is defined; it also ties handler
        if (defined $hashref->{layer}) {
            $self->open( $hashref->{file}, $hashref->{mode} . $hashref->{layer} );
        }
        else {
            $self->open( $hashref->{file}, $hashref->{mode}, $hashref->{perms} );
        };
        return TRUE;
    }
    elsif (defined $hashref->{filename}) {
        # deprecated
        ## no critic (RequireCarping)
        warn "IO::Moose::File->filename attribute is deprecated. Use file attribute instead";
        if (defined $hashref->{layer}) {
            $self->open( $hashref->{filename}, $hashref->{mode} . $hashref->{layer} );
        }
        else {
            $self->open( $hashref->{filename}, $hashref->{mode}, $hashref->{perms} );
        };
        return TRUE;
    };

    return FALSE;
};


# Constructor for new tmpfile
sub new_tmpfile {
    ### new_tmpfile: @_

    my $class = shift;

    my $io;

    eval {
        # Pass arguments to File::Temp constructor
        my $tmp = File::Temp->new(@_);

        # create new empty object with new default mode
        $io = $class->new( file => $tmp, mode => '+>' );
    };
    if ($@) {
        my $e = Exception::Fatal->catch;
        $e->throw( message => 'Cannot new_tmpfile' );
    };
    assert_not_null($io) if ASSERT;

    return $io;
};


# Wrapper for CORE::open
sub open {
    ### open: @_
    my $self = shift;

    # handle tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->open(FILENAME [,MODE [,PERMS]]) or $io->open(FILENAME, IOLAYERS)'
    ) if not blessed $self or @_ < 1 or @_ > 3
         or (@_ == 3 and (defined $_[1] and $_[1] =~ /:/
             or defined $_[2] and not looks_like_number $_[2]));

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my ($file, $mode, $perms) = @_;
    my $layer = '';

    my $status;
    eval {
        # check constraints
        $file = $self->_set_file($file);
        $mode = defined $mode ? $self->_set_mode($mode) : $self->_clear_mode;
        $perms = defined $perms ? $self->_set_perms($perms) : $self->_clear_perms;

        if ($mode =~ s/(:.*)//) {
            $layer = $self->_set_layer($1);
            $mode = $self->_set_mode($mode);
        };

        if ( eval { $file->isa('File::Temp') } ) {
            # File::Temp is always +>
            $self->_set_mode('+>');
            # copy file handle from File::Temp
            $status = $hashref->{fh} = $file;
            if ($layer) {
                $status = CORE::binmode( $hashref->{fh}, $layer );
            };
        }
        elsif ($mode =~ /^\d+$/) {
            ### open: "sysopen(fh, $file, $mode, $perms)"
            $status = sysopen( $hashref->{fh}, $file, $mode, $perms );
        }
        else {
            ### open: "open(fh, $mode, $file)"
            $status = CORE::open( $hashref->{fh}, $mode, $file );
        };
    };
    if (not $status) {
        $hashref->{_error} = 1;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot open' );
    };
    assert_true($status) if ASSERT;

    $hashref->{error} = 0;

    # normalize mode string for tied handler
    if ($mode =~ /^\d+$/) {
        $mode = ($mode & 2 ? '+' : '') . ($mode & 1 ? '>' : '<');
    };

    # clone standard handler for tied handler
    untie *$self;
    CORE::close *$self;

    CORE::open *$self, "$mode&", $hashref->{fh};
    tie *$self, blessed $self, $self;

    if (${^TAINT} and not $hashref->{tainted}) {
        $self->untaint;
    };

    return $self;
};


# Wrapper for CORE::binmode
sub binmode {
    ### binmode: @_

    my $self = shift;

    # handle tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->binmode([LAYER])'
    ) if not blessed $self or @_ > 1;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my ($layer) = @_;

    $layer = $self->_set_layer($layer) if defined $layer;

    my $status;
    eval {
        if (defined $layer) {
            $status = CORE::binmode( $hashref->{fh}, $layer );
        }
        else {
            $status = CORE::binmode( $hashref->{fh} );
        };
    };

    if (not $status) {
        $hashref->{_error} = 1;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot open' );
    };
    assert_true($status) if ASSERT;

    return $self;
};


{
    # Aliasing tie hooks to real functions
    foreach my $func (qw< open binmode >) {
        __PACKAGE__->meta->alias_method(
            uc($func) => __PACKAGE__->meta->get_method($func)->body
        );
    };
};

# Make immutable finally
__PACKAGE__->meta->make_immutable;


1;


__END__

=begin umlwiki

= Class Diagram =

[               IO::Moose::File
 -----------------------------------------------
 +file : Str|FileHandle|OpenHandle {rw, new}
 +mode : Num|OpenModeWithLayerStr|CanonOpenModeStr = "<" {rw, new}
 +perms : Num = 0666 {rw, new}
 +layer : PerlIOLayerStr = "" {rw, new}
 -----------------------------------------------
 +new( I<args> : Hash ) : Self
 +new_tmpfile( I<args> : Hash ) : Self
 +open( I<file> : Str|FileHandle|OpenHandle , I<mode> : OpenModeWithLayerStr|CanonOpenModeStr = "<" ) : Self
 +open( I<file> : Str|FileHandle|OpenHandle , I<mode> : Num, I<perms> : Num = 0600 ) : Self
 +binmode(I<>) : Self
 +binmode( I<layer> : PerlIOLayerStr ) : Self
                                                ]

[IO::Moose::File] ---|> [IO::Moose::Handle]

[IO::Moose::File] ---|> <<role>> [IO::Moose::Seekable]

[IO::Moose::File] ---> <<exception>> [Exception::Fatal] [Exception::IO]

=end umlwiki

=head1 BASE CLASSES

=over 2

=item *

L<IO::Moose::Handle>

=back

=head1 ROLE CLASSES

=over 2

=item *

L<IO::Moose::Seekable>

=back

=head1 ATTRIBUTES

=over

=item file : Str|FileHandle|OpenHandle {rw, new}

File (file name, file handle or IO object) as a parameter for new object.

=item mode : Num|OpenModeWithLayerStr|CanonOpenModeStr = "<" {rw, new}

File mode as a parameter for new object.  Can be Perl-style (E<lt>, E<gt>,
E<gt>E<gt>, etc.) with optional PerlIO layer after colon (i.e.
"<:encoding(UTF-8)") or C-style (r, w, a, etc.) or decimal number (O_RDONLY,
O_RDWR, O_CREAT, other constants from standard module L<Fcntl>).

=item perms : Num = 0666 {rw, new}

Permissions to use in case a new file is created and mode was decimal number.
The permissions are always modified by umask.

=item layer : PerlIOLayerStr = "" {rw, new}

PerlIO layer string.

=back

=head1 CONSTRUCTORS

=over

=item new( I<args> : Hash ) : Self

Creates an object.  If I<file> is defined, the c<open> method is called; if
the open fails, the object is destroyed.  Otherwise, it is returned to the
caller.

  $io = IO::Moose::File->new;
  $io->open("/etc/passwd");

  $io = IO::Moose::File->new( file => "/var/log/perl.log", mode => "a" );

If I<file> is a L<File::Temp> object, this object is used as I<fh> attribute
and I<mode> attribute is changed to C<+E<gt>> value.

  $tmp = IO::Moose::File->new( file => File::Temp->new );
  $tmp->say("This file will be deleted after destroy");

=item new_tmpfile( I<args> : Hash ) : Self

Creates the object with opened temporary and anonymous file for read/write.
If the temporary file cannot be created or opened, the object is destroyed.
Otherwise, it is returned to the caller.

All I<args> will be passed to the L<File::Temp> constructor.

  $io = IO::Moose::File->new_tmpfile( UNLINK => 1, SUFFIX => '.jpg' );
  $pos = $io->getpos;  # save position
  $io->say("foo");
  $io->setpos($pos);   # rewind
  $io->slurp;          # prints "foo"

=back

=head1 METHODS

=over

=item open( I<file> : Str|FileHandle|OpenHandle , I<mode> : OpenModeWithLayerStr|CanonOpenModeStr = "<" ) : Self

=item open( I<file> : Str|FileHandle|OpenHandle , I<mode> : Num, I<perms> : Num = 0600 ) : Self

Opens the file and returns self object.  If mode is Perl-style mode string or
C-style mode string, it uses L<perlfunc/open> function.  If mode is decimal
(it can be C<O_XXX> constant from standard module L<Fcntl>) it uses
L<perlfunc/sysopen> function with default permissions set to C<0666>.

  $io = IO::Moose::File->new;
  $io->open("/etc/passwd");

  $io = IO::Moose::File->new;
  $io->open("/var/tmp/output", "w");

  use Fcntl;
  $io = IO::Moose::File->new;
  $io->open("/etc/hosts", O_RDONLY);

=item binmode(I<>) : Self

=item binmode( I<layer> : PerlIOLayerStr ) : Self

Sets binmode on the underlying IO object.  On some systems (in general, DOS
and Windows-based systems) binmode is necessary when you're not working with
a text file.

It can also sets PerlIO layer (C<:bytes>, C<:crlf>, C<:utf8>,
C<:encoding(XXX)>, etc.). More details can be found in L<PerlIO::encoding>.

In general, C<binmode> should be called after C<open> but before any I/O is
done on the file handler.

Returns self object.

  $io = IO::Moose::File->new( file => "/tmp/picture.png", mode => "w" );
  $io->binmode;

  $io = IO::Moose::File->new( file => "/var/tmp/fromdos.txt" );
  $io->binmode(":crlf");

=back

=head1 SEE ALSO

L<IO::File>, L<IO::Moose>, L<IO::Moose::Handle>, L<IO::Moose::Seekable>,
L<File::Temp>.

=head1 BUGS

The API is not stable yet and can be changed in future.

=for readme continue

=head1 AUTHOR

Piotr Roszatycki E<lt>dexter@debian.orgE<gt>

=head1 LICENSE

Copyright 2008, 2009 by Piotr Roszatycki E<lt>dexter@debian.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
