#!/usr/bin/perl -c

package IO::Moose::Seekable;
use 5.006;
our $VERSION = 0.04;

=head1 NAME

IO::Moose::Seekable - Moose reimplementation of IO::Seekable

=head1 SYNOPSIS

  package My::IO;
  use Moose;
  extends 'IO::Moose::Handle';
  with 'IO::Moose::Seekable';

  package main;
  $stdin = new My::IO fd=>\*STDIN, mode=>'r';
  $stdin->slurp;
  print $stdin->tell, "\n";

=head1 DESCRIPTION

This class provides an interface mostly compatible with L<IO::Seekable>.  The
differences:

=over

=item *

It is based on L<Moose> object framework.

=item *

It provides the Moose Role.

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

use Moose::Role;


use Exception::Base ':all',
    '+ignore_package'     => [ __PACKAGE__ ],
    'Exception::IO'       => { isa => 'Exception::System' },
    'Exception::Fatal'    => { isa => 'Exception::Base' },
    'Exception::Argument' => { isa => 'Exception::Base' };


use Scalar::Util 'blessed', 'reftype';


# Use Fcntl for setpos
BEGIN { eval { require Fcntl }; }


# Debugging flag
our $Debug = 0;


# Wrapper for CORE::seek
sub seek {
    { no warnings; warn "seek @_" if $Debug; }

    my $self = shift;

    # handle tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    throw Exception::Argument
          message => 'Usage: $io->seek(POS, WHENCE)'
        if not blessed $self or @_ != 2;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $status;
    try eval {
        $status = CORE::seek $hashref->{fh}, $_[0], $_[1];
    };
    if (catch my $e) {
        throw Exception::Fatal $e,
              message => 'Cannot seek'
            if not defined $e->message;
        throw $e;
    }
    if (not $status) {
        throw Exception::IO
              message => 'Cannot seek';
    }

    return $self;
}


# Wrapper for CORE::sysseek
sub sysseek {
    { no warnings; warn "sysseek @_" if $Debug; }

    my $self = shift;

    throw Exception::Argument
          message => 'Usage: $io->sysseek(POS, WHENCE)'
        if not blessed $self or @_ != 2;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $status;
    try eval {
        $status = CORE::sysseek $hashref->{fh}, $_[0], $_[1];
    };
    if (catch my $e) {
        throw Exception::Fatal $e,
              message => 'Cannot sysseek'
            if not defined $e->message;
        throw $e;
    }
    if (not $status) {
        throw Exception::IO
              message => 'Cannot sysseek';
    }
    return $status;
}


# Wrapper for CORE::tell
sub tell {
    { no warnings; warn "tell @_" if $Debug; }

    my $self = shift;

    # handle tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    throw Exception::Argument
          message => 'Usage: $io->tell()'
        if not blessed $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $status;
    try eval {
        $status = CORE::tell $hashref->{fh};
    };
    if (catch my $e) {
        throw Exception::Fatal $e,
              message => 'Cannot tell'
            if not defined $e->message;
        throw $e;
    }
    return $status == 0 ? '0 but true' : $status;
}


# Pure Perl implementation
sub getpos {
    { no warnings; warn "getpos @_" if $Debug; }

    my $self = shift;

    throw Exception::Argument
          message => 'Usage: $io->getpos()'
        if not blessed $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $pos;
    try eval {
        $pos = $self->tell;
    };

    if (catch my $e) {
        throw Exception::Fatal $e,
              message => 'Cannot getpos'
            if not defined $e->message;
        throw $e;
    }

    return $pos;
}


# Pure Perl implementation
sub setpos {
    { no warnings; warn "setpos @_" if $Debug; }

    my $self = shift;

    throw Exception::Argument
          message => 'Usage: $io->setpos(POS)'
        if not blessed $self or @_ != 1;

    my ($pos) = @_;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $status;
    try eval {
        $status = $self->seek($pos, &Fcntl::SEEK_SET);
    };

    if (catch my $e) {
        throw Exception::Fatal $e,
              message => 'Cannot getpos'
            if not defined $e->message;
        throw $e;
    }

    return $self;
}


INIT: {
    foreach my $func (qw< tell seek >) {
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

L<Moose::Role>

=back

=head1 METHODS

=over

=item seek(I<pos>, I<whence>)

Seek the file to position I<pos>, relative to I<whence>:

=over

=item I<whence>=0 (SEEK_SET)

I<pos> is absolute position. (Seek relative to the start of the file)

=item I<whence>=1 (SEEK_CUR)

I<pos> is an offset from the current position. (Seek relative to current)

=item I<whence>=2 (SEEK_END)

=back

I<pos> is an offset from the end of the file. (Seek relative to end)

The SEEK_* constants can be imported from the L<Fcntl> module if you don't
wish to use the numbers 0 1 or 2 in your code.  The SEEK_* constants are more
portable.

Returns self object on success or throws an exception.

  use Fcntl 'SEEK_END';
  $file->seek(0, SEEK_END);
  $file->say("*** End of file");

=item sysseek(I<pos>, I<whence>)

Uses the system call lseek(2) directly so it can be used with B<sysread> and
B<syswrite> methods.

Returns the new position or throws an exception.  A position of zero is
returned as the string "0 but true".

=item tell

Returns the current file position, or throws an exception on error.  A
position of zero is returned as the string "0 but true".

=item getpos

Returns a value that represents the current position of the file.  This method
is implemented with B<tell> method.

=item setpos(I<pos>)

Goes to the position stored previously with B<getpos> method.  Returns this
object on success, throws an exception on failure.  This method is implemented
with B<seek> method.

  $pos = $file->getpos;
  $file->print("something\n");
  $file->setpos($pos);
  print $file->readline;  # prints "something"

=back

=head1 SEE ALSO

L<IO::Seekable>, L<IO::Moose>, L<Moose::Role>.

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
