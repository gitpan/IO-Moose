#!/usr/bin/perl -c

package IO::Moose::Seekable;

=head1 NAME

IO::Moose::Seekable - Reimplementation of IO::Seekable with improvements

=head1 SYNOPSIS

  package My::IO;
  use Moose;
  extends 'IO::Moose::Handle';
  with 'IO::Moose::Seekable';

  package main;
  my $stdin = My::IO->new( file => \*STDIN, mode => 'r' );
  print $stdin->slurp;
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

=back

=cut


use 5.008;
use strict;
use warnings FATAL => 'all';

our $VERSION = 0.06_02;

use Moose::Role;


use Exception::Base (
    '+ignore_package' => [ __PACKAGE__ ],
);
use Exception::Argument;
use Exception::Fatal;


use Scalar::Util 'blessed', 'looks_like_number', 'reftype';


# Use Fcntl for blocking method.
use Fcntl ();


# Assertions
use Test::Assert ':assert';

# Debugging flag
use if $ENV{PERL_DEBUG_IO_MOOSE_SEEKABLE}, 'Smart::Comments';


## no critic (ProhibitBuiltinHomonyms)
## no critic (RequireArgUnpacking)
## no critic (RequireCheckingReturnValueOfEval)

# Wrapper for CORE::seek
sub seek {
    ### seek: @_

    my $self = shift;

    # handle tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
          message => 'Usage: $io->seek(POS, WHENCE)',
    ) if not blessed $self or @_ != 2 or not looks_like_number $_[0] or not looks_like_number $_[1];

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my $status;
    eval {
        $status = CORE::seek $hashref->{fh}, $_[0], $_[1];
    };
    if (not $status) {
        $hashref->{_error} = 1;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot seek' );
    };
    assert_true($status) if ASSERT;

    return $self;
};


# Wrapper for CORE::sysseek
sub sysseek {
    ### sysseek: @_

    my $self = shift;

    Exception::Argument->throw(
          message => 'Usage: $io->sysseek(POS, WHENCE)'
    ) if not blessed $self or @_ != 2 or not looks_like_number $_[0] or not looks_like_number $_[1];

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my $position;
    eval {
        $position = CORE::sysseek $hashref->{fh}, $_[0], $_[1];
    };
    if (not $position) {
        $hashref->{_error} = 1;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot sysseek' );
    };
    assert_true($position) if ASSERT;

    return int $position;
};


# Wrapper for CORE::tell
sub tell {
    ### tell: @_

    my $self = shift;

    # handle tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
          message => 'Usage: $io->tell()'
    ) if not blessed $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $position;
    eval {
        $position = CORE::tell $hashref->{fh};
    };
    if ($@ or $position < 0) {
        $hashref->{_error} = 1;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot tell' );
    };
    assert_not_null($position) if ASSERT;

    return $position;
};


# Pure Perl implementation
sub getpos {
    ### getpos: @_

    my $self = shift;

    Exception::Argument->throw(
          message => 'Usage: $io->getpos()'
    ) if not blessed $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $position;
    eval {
        $position = $self->tell;
    };
    if ($@ or $position < 0) {
        $hashref->{_error} = 1;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot tell' );
    };
    assert_not_null($position) if ASSERT;

    return $position;
};


# Pure Perl implementation
sub setpos {
    # setpos: @_

    my $self = shift;

    Exception::Argument->throw(
          message => 'Usage: $io->setpos(POS)'
    ) if not blessed $self or @_ != 1 or not looks_like_number $_[0];

    my ($pos) = @_;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $status;
    eval {
        $status = $self->seek( $pos, Fcntl::SEEK_SET );
    };
    if (not $status) {
        $hashref->{_error} = 1;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot setpos' );
    };
    assert_true($status) if ASSERT;

    return $self;
};


# Aliasing tie hooks to real functions
{
    foreach my $func (qw< tell seek >) {
        __PACKAGE__->meta->alias_method(
            uc($func) => __PACKAGE__->meta->get_method($func)->body
        );
    };
};


1;


__END__

=begin umlwiki

= Class Diagram =

[                  <<role>>
              IO::Moose::Seekable
 -----------------------------------------------
 +seek( I<pos> : Int, I<whence> : Int ) : Self
 +sysseek( I<pos> : Int, I<whence> : Int ) : Int
 +tell(I<>) : Int
 +getpos(I<>) : Int
 +setpos( I<pos> : Int ) : Self
 -----------------------------------------------
                                                ]

[IO::Moose::Handle] ---> <<exception>> [Exception::Fatal] [Exception::IO]

=end umlwiki

=head1 BASE CLASSES

=over 2

=item *

L<Moose::Role>

=back

=head1 EXCEPTIONS

=over

=item Exception::Argument

Thrown whether method is called with wrong argument.

=item Exception::Fatal

Thrown whether fatal error is occurred by core function.

=back

=head1 METHODS

=over

=item seek( I<pos> : Int, I<whence> : Int ) : Self

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
wish to use the numbers 0, 1 or 2 in your code.  The SEEK_* constants are more
portable.

Returns self object on success or throws an exception.

  use Fcntl ':seek';
  $file->seek(0, SEEK_END);
  $file->say("*** End of file");

=item sysseek( I<pos> : Int, I<whence> : Int ) : Int

Uses the system call lseek(2) directly so it can be used with B<sysread> and
B<syswrite> methods.

Returns the new position or throws an exception.

=item tell(I<>) : Int

Returns the current file position, or throws an exception on error.

=item getpos(I<>) : Int

Returns a value that represents the current position of the file.  This method
is implemented with B<tell> method.

=item setpos( I<pos> : Int ) : Self

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

=head1 AUTHOR

Piotr Roszatycki E<lt>dexter@debian.orgE<gt>

=head1 LICENSE

Copyright 2008, 2009 by Piotr Roszatycki E<lt>dexter@debian.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
