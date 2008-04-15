#!/usr/bin/perl -c

package IO::Moose::File;
use 5.006;
our $VERSION = 0.04;

=head1 NAME

IO::Moose::File - Moose reimplementation of IO::File

=head1 SYNOPSIS

  use IO::Moose::File;
  $file = new IO::Moose::File filename=>"/etc/passwd";
  @passwd = $file->getlines;

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

=cut


use warnings FATAL => 'all';

use Moose;

extends 'IO::Moose::Handle';

with 'IO::Moose::Seekable';


use Moose::Util::TypeConstraints;

subtype 'LayerModeStr'
    => as 'Str'
    => where { /^\+?(<|>>?):?/ };

subtype 'LayerStr'
    => as 'Str'
    => where { /^:/ };


has 'mode' => overwrite => 1,
    isa     => 'Num | LayerModeStr | CanonModeStr',
    default => '<',
    coerce  => 1,
    reader  => 'mode',
    writer  => '_set_mode',
    clearer => '_clear_mode';

has 'filename' =>
    isa     => 'Str',
    reader  => 'filename',
    writer  => '_set_filename';

has 'perms' =>
    isa     => 'Num',
    default => 0666,
    reader  => 'perms',
    writer  => '_set_perms',
    clearer => '_clear_perms';

has 'layer' =>
    isa     => 'LayerStr',
    reader  => 'layer',
    writer  => '_set_layer';


use Exception::Base ':all',
    '+ignore_package' => [ __PACKAGE__ ];


# Debugging flag
our $Debug = 0;


# Default constructor
override 'BUILD' => sub {
    { no warnings; warn "BUILD @_" if $Debug; }

    my ($self, $params) = @_;
    my $hashref = ${*$self};

    # initialize anonymous handlers
    select select my $fh;
    $hashref->{fh} = $fh;

    if (defined $hashref->{filename}) {
        # call fdopen if fd is defined; it also ties handler
        if (defined $hashref->{layer}) {
            $self->open($hashref->{filename}, $hashref->{mode} . $hashref->{layer});
        }
        else {
            $self->open($hashref->{filename}, $hashref->{mode}, $hashref->{perms});
        }
    }
    else {
        # tie handler with proxy class just here
        tie *$self, blessed $self, $self;
    }

    return $self;
};


# Constructor for new tmpfile
sub new_tmpfile {
    { no warnings; warn "new_tmpfile @_" if $Debug; }

    my ($class) = @_;
    $class = blessed $class if blessed $class;

    # create new empty object with new default mode
    my $self = $class->new(mode => '+>');

    # handle GLOB reference
    my $hashref = ${*$self};

    my $status;
    try eval {
	if ($^V ge v5.8) {
    	    { no warnings; warn "CORE::open($hashref->{fh}, $hashref->{mode}, undef)" if $Debug; }
    	    $status = CORE::open($hashref->{fh}, $hashref->{mode}, undef);
	}
	else {
	    # compatibility with Perl 5.6 which doesn't support anonymous open
	    require File::Temp;
	    $status = $hashref->{fh} = File::Temp->tmpfile;
	}
    };

    if (catch my $e) {
        throw Exception::Fatal $e,
              message => 'Cannot new_tmpfile'
            if not defined $e->message;
        throw $e;
    }
    if (not $status) {
        throw Exception::IO
              message => 'Cannot new_tmpfile';
    }

    # clone standard handler for tied handler
    untie *$self;
    CORE::close *$self;
    if ($] < 5.008) {
        # Compatibility with Perl 5.6
        my $newfd = CORE::fileno $hashref->{fh};
        CORE::open *$self, "$hashref->{mode}&=$newfd";
    }
    else {
        CORE::open *$self, "$hashref->{mode}&", $hashref->{fh};
    }
    tie *$self, blessed $self, $self;

    return $self;
}


# Wrapper for CORE::open
sub open {
    { no warnings; warn "open @_" if $Debug; }

    my $self = shift;

    # handle tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    throw Exception::Argument
          message => 'Usage: $io->open(FILENAME [,MODE [,PERMS]]) or $fh->open(FILENAME, IOLAYERS)'
        if not blessed $self or @_ < 1 || @_ > 3 || (@_ == 3 and defined $_[1] and $_[1] =~ /:/);

    # handle GLOB reference
    my $hashref = ${*$self};

    my ($filename, $mode, $perms) = @_;

    my $status;
    try eval {
        # check constraints
        $filename = $self->_set_filename($filename);
        $mode = defined $mode ? $self->_set_mode($mode) : $self->_clear_mode;
        $perms = defined $perms ? $self->_set_perms($perms) : $self->_clear_perms;

        if ($mode =~ s/(:.*)//) {
            $self->_set_layer($1);
            $self->_set_mode($mode);
        }

        if ($mode =~ /^\d+$/) {
            { no warnings; warn "sysopen($hashref->{fh}, $filename, $mode, $perms)" if $Debug; }
            $status = sysopen($hashref->{fh}, $filename, $mode, $perms);
        } else {
            { no warnings; warn "CORE::open($hashref->{fh}, $mode, $filename)" if $Debug; }
            $status = CORE::open($hashref->{fh}, $mode, $filename);
        }
    };

    if (catch my $e) {
        $hashref->{error} = 1;
        throw Exception::Fatal $e,
              message => 'Cannot open'
            if not defined $e->message;
        throw $e;
    }
    if (not $status) {
        $hashref->{error} = 1;
        throw Exception::IO
              message => 'Cannot open';
    }

    $hashref->{error} = 0;

    # normalize mode string for tied handler
    if ($mode =~ /^\d+$/) {
        $mode = ($mode & 2 ? '+' : '') . ($mode & 1 ? '>' : '<');
    }

    # clone standard handler for tied handler
    untie *$self;
    CORE::close *$self;
    if ($] < 5.008) {
        # Compatibility with Perl 5.6
        my $newfd = CORE::fileno $hashref->{fh};
        CORE::open *$self, "$mode&=$newfd";
    }
    else {
        CORE::open *$self, "$mode&", $hashref->{fh};
    }
    tie *$self, blessed $self, $self;

    return $self;
}


# Wrapper for CORE::binmode
sub binmode {
    warn "binmode @_" if $Debug;

    my $self = shift;

    # handle tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    throw Exception::Argument
          message => 'Usage: $io->binmode([LAYER])'
        if not blessed $self or @_ > 1;

    # handle GLOB reference
    my $hashref = ${*$self};

    my ($layer) = @_;

    $layer = $self->_set_layer($layer) if defined $layer;

    my $status;
    try eval {
        if (defined $layer) {
            $status = CORE::binmode($hashref->{fh}, $layer);
        }
        else {
            $status = CORE::binmode($hashref->{fh});
        }
    };

    if (catch my $e) {
        $hashref->{error} = 1;
        throw Exception::Fatal $e,
              message => 'Cannot binmode'
            if not defined $e->message;
        throw $e;
    }
    if (not $status) {
        $hashref->{error} = 1;
        throw Exception::IO
              message => 'Cannot binmode';
    }

    return $self;
}


INIT: {
    foreach my $func (qw< open binmode >) {
        __PACKAGE__->meta->alias_method(
            uc($func) => __PACKAGE__->meta->get_method($func)->body
        );
    }
}


1;


__END__

=for readme stop

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

=head1 TYPE CONSTRAINTS

=over

=item LayerModeStr

Represents canonical mode string with optional PerlIO layers (i.e.
"<:encoding(UTF-8)").

=item LayerStr

Represents PerlIO layers string (i.e. ":crlf").

=back

=head1 FIELDS

=over

=item mode (rw, new, default: <)

File mode as a parameter for new object.  Can be Perl-style (E<lt>, E<gt>,
E<gt>E<gt>, etc.) with optional PerlIO layer after colon (i.e.
"<:encoding(UTF-8)") or C-style (r, w, a, etc.) or decimal number (O_RDONLY,
O_RDWR, O_CREAT, other constants from standard module L<Fcntl>).

=item filename (rw, new)

File name.

=item perms (rw, new, default: 0666)

Permissions to use in case a new file is created and mode was decimal number.
The permissions are always modified by umask.

=item layer (rw, new)

PerlIO layer string.

=back

=head1 CONSTRUCTORS

=over

=item new

Creates an object.  If B<filename> is defined, the B<open> method is called;
if the open fails, the object is destroyed.  Otherwise, it is returned to the
caller.

  $io = new IO::Moose::File;
  $io->open("/etc/passwd");

  $io = new IO::Moose::File filename=>"/var/log/perl.log", mode=>"a";

=item new_tmpfile

Creates the object with opened temporary and anonymous file for read/write.
If the temporary file cannot be created or opened, the object is destroyed.
Otherwise, it is returned to the caller.

It takes no parameters.

  $io = new_tmpfile IO::Moose::File;
  $pos = $io->getpos;  # save position
  $io->say("foo");
  $io->setpos($pos);   # rewind
  $io->slurp;          # prints "foo"

=back

=head1 METHODS

=over

=item open(I<filename> [,I<mode> [,I<perms>]])

Openes the file and returns self object.  If mode is Perl-style mode string or
C-style mode string, it uses core B<open> function.  If mode is decimal (it
can be O_XXX constant from standard module L<Fcntl>) it uses core B<sysopen>
function with default permissions set to 0666.

  $io = new IO::Moose::File;
  $io->open("/etc/passwd");

  $io = new IO::Moose::File;
  $io->open("/var/tmp/output", "w");

  use Fcntl;
  $io = new IO::Moose::File;
  $io->open("/etc/hosts", O_RDONLY);

=item binmode([I<layer>])

Sets binmode on the underlying IO object.  On some systems (in general, DOS
and Windows-based systems) binmode is necessary when you're not working with
a text file.

It can also sets PerlIO layer (:bytes, :crlf, :utf8, :encoding(XXX), etc.).
More details can be found in L<PerlIO::encoding>.

In general, b<binmode> should be called after b<open>but before any I/O is done on the filehandle.

Returns self object.

  $io = new IO::Moose::File filename => "/tmp/picture.png", mode => "w";
  $io->binmode;

  $io = new IO::Moose::File filename => "/var/tmp/fromdos.txt";
  $io->binmode(":crlf");

=back

=head1 SEE ALSO

L<IO::File>, L<IO::Moose>, L<IO::Moose::Handle>, L<IO::Moose::Seekable>.

=head1 BUGS

The API is not stable yet and can be changed in future.

=for readme continue

=head1 AUTHOR

Piotr Roszatycki E<lt>dexter@debian.orgE<gt>

=head1 LICENSE

Copyright 2008 by Piotr Roszatycki E<lt>dexter@debian.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
