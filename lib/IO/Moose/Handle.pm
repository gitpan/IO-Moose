#!/usr/bin/perl -c

package IO::Moose::Handle;
use 5.006;
our $VERSION = 0.02;

=head1 NAME

IO::Moose::Handle - Moose reimplementation of IO::Handle with improvements

=head1 SYNOPSIS

  use IO::Moose::Handle;

  $fh = new IO::Moose::Handle;
  $fh->fdopen(fileno(STDIN));
  print $fh->getline;
  $file = $fh->slurp;
  $fh->close;

  $fh = fdopen IO::Moose::Handle \*STDERR, '>';
  autoflush $fh 1;
  say $fh 'Some text';
  undef $fh;  # calls close at DESTROY

=head1 DESCRIPTION

This class provides an interface mostly compatible with L<IO::Handler>.  The
differences:

=over

=item *

It is based on L<Moose> object framework.

=item *

It uses L<Exception::Base> for signaling errors. Most of methods are throwing
exception on failure.

=item *

The modifiers like B<input_record_separator> are supported on per-filehandler
basis.

=item *

It also implements additional methods like B<say>, B<slurp>.

=item *

It is pure-Perl implementation.

=back

=cut


local $_;

use warnings FATAL => 'all';

use Moose;

extends 'MooseX::GlobRef::Object';

use Moose::Util::TypeConstraints;

subtype 'ModeStr'
    => as 'Str'
    => where { /^([rwa]\+?|\+?(<|>>?))$/ };

subtype 'CanonModeStr'
    => as 'Str'
    => where { /^\+?(<|>>?)$/ };

coerce 'CanonModeStr'
    => from 'Undef'
        => via { '<' }
    => from 'ModeStr'
        => via { local $_ = $_;
                 s/^r(\+?)$/$1</;
                 s/^w(\+?)$/$1>/;
                 s/^a(\+?)$/$1>>/;
                 $_ };

#subtype 'IO'
#    => as 'Object'
#    => where { defined $_
#            && Scalar::Util::reftype($_) eq 'GLOB'
#            && Scalar::Util::openhandle($_) }
#    => optimize_as { defined $_[0]
#                  && Scalar::Util::reftype($_[0]) eq 'GLOB'
#                  && Scalar::Util::openhandle($_[0]) };


has 'fh' =>
    reader  => 'fh',
    writer  => '_set_fh';

has 'fd' =>
    isa     => 'Str | FileHandle | IO',
    is_weak => 1,
    reader  => 'fd',
    writer  => '_set_fd';

has 'mode' =>
    isa     => 'CanonModeStr',
    default => '<',
    coerce  => 1,
    reader  => 'mode',
    writer  => '_set_mode';

has 'error' =>
    default => -1;

has 'ungetc_buffer' =>
    default => '';

has 'autochomp' =>
    is      => 'rw';

has 'untaint' =>
    default => 0;

has $_ =>
    clearer => 'clear_' . $_
    foreach ( qw< format_line_break_characters
                  format_formfeed
                  input_record_separator
                  output_field_separator
                  output_record_separator > );


use Exception::Base ':all',
    'Exception::IO'       => { isa => 'Exception::System' },
    'Exception::Fatal'    => { isa => 'Exception::Base' },
    'Exception::Argument' => { isa => 'Exception::Base' };


use Scalar::Util 'blessed', 'reftype', 'weaken', 'looks_like_number';
use Symbol 'qualify';

use File::Stat::Moose;

# Use Errno for getc method
use Errno ();

# Use Fcntl for blocking method
eval { require Fcntl };


# Constant for IO::Moose::Handle::* package name
sub __TIEPACKAGE__ () { __PACKAGE__ . '::Tie' };


# Debugging flag
our $Debug = 0;


# Default constructor
sub BUILD {
    warn "BUILD @_" if $Debug;

    my ($self, $params) = @_;
    my $hashref = ${*$self};

    # initialize anonymous handlers
    select select my $fh;
    $self->_set_fh($fh);

    if (defined $hashref->{fd}) {
        # call fdopen if fd is defined; it also ties handler
        $self->fdopen($hashref->{fd}, $hashref->{mode});
    }
    else {
        # tie handler with proxy class just here
        tie *$self, __TIEPACKAGE__, $self;
    }

    return $self;
}


# fdopen constructor
sub new_from_fd {
    warn "new_from_fd @_" if $Debug;

    my ($class, $fd, $mode) = @_;
    $class = blessed $class if blessed $class;

    return $class->new(fd => $fd, mode => $mode);
}


# fdopen method
sub fdopen {
    warn "fdopen @_" if $Debug;

    my $self = shift;
    my ($fd, $mode) = @_;
    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: ' . __PACKAGE__ . '->fdopen(FD, [MODE])'
        if not defined $fd or @_ > 2;

    return $self->new_from_fd(@_) unless blessed $self;  # called as constructor

    my $hashref = ${*$self};

    # check constraints
    $fd = $self->_set_fd($fd);
    $mode = $self->_set_mode($mode);

    # compatibility with Perl 5.6 which doesn't accept "&" in mode
    if ($] < 5.008) {
        if (blessed $fd and $fd->isa(__PACKAGE__)) {
            $fd = $fd->fileno;
        } elsif (ref $fd) {
            $fd = CORE::fileno $fd;
        }
    }

    my $status;
    try eval {
        if (blessed $fd and $fd->isa(__PACKAGE__)) {
            warn "fdopen: open(fh, $mode&, \$fd->{fh})\n" if $Debug;
            $status = CORE::open $hashref->{fh}, "$mode&", ${*$fd}->{fh};
        }
        elsif ((ref $fd || '') eq 'GLOB') {
            warn "fdopen: open(fh, $mode&, \\$$fd)\n" if $Debug;
            $status = CORE::open $hashref->{fh}, "$mode&", $fd;
        }
        elsif ((reftype $fd || '') eq 'GLOB') {
            warn "fdopen: open(fh, $mode&, *$fd)\n" if $Debug;
            $status = CORE::open $hashref->{fh}, "$mode&", *$fd;
        }
        elsif ($fd =~ /^\d+$/) {
            warn "fdopen: open(fh, $mode&=$fd)\n" if $Debug;
            $status = CORE::open $hashref->{fh}, "$mode&=$fd";
        }
        elsif (not ref $fd) {
            warn "fdopen: open(fh, $mode&$fd)\n" if $Debug;
            $status = CORE::open $hashref->{fh}, "$mode&$fd";
        }
        else {
            # try to dereference glob if other failed
            warn "fdopen: open(fh, $mode&, *$fd)\n" if $Debug;
            $status = CORE::open $hashref->{fh}, "$mode&", *$fd;
        }
    };
    if (catch my $e) {
        $hashref->{error} = 1;
        throw Exception::Fatal $e,
              ignore_package => __PACKAGE__,
              message => 'Cannot fdopen',
            if not defined $e->message;
        throw $e
              ignore_package => __PACKAGE__;
    }
    if (not $status) {
        $hashref->{error} = 1;
        throw Exception::IO
              ignore_package => __PACKAGE__,
              message => 'Cannot fdopen';
    }

    $hashref->{error} = 0;

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
    tie *$self, __TIEPACKAGE__, $self;

    return $self;
}


# Standard close IO method / tie hook
sub close {
    warn "close @_" if $Debug;

    my ($self) = @_;

    # handle tie hook
    $self = $$self if blessed $self and $self->isa(__TIEPACKAGE__);

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->close()'
        if not blessed $self;

    # handle GLOB reference
    my $hashref = ${*$self};

    if (not CORE::close $hashref->{fh}) {
        $hashref->{error} = 1;
        throw Exception::IO
              ignore_package => __PACKAGE__,
              message => 'Cannot close';
    }

    $hashref->{error} = -1;

    # close also tied handler
    untie *$self;
    CORE::close *$self;
    tie *$self, __TIEPACKAGE__, $self;

    return $self;
}


# Standard eof IO method / tie hook
sub eof {
    warn "eof @_" if $Debug;

    my ($self) = @_;

    # handle tie hook
    $self = $$self if blessed $self and $self->isa(__TIEPACKAGE__);

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->eof()'
        if not blessed $self;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $status = try eval {
        CORE::eof $hashref->{fh};
    };
    if (catch my $e) {
        throw Exception::Fatal $e,
              ignore_package => __PACKAGE__,
              message => 'Cannot eof',
            if not defined $e->message;
        throw $e
              ignore_package => __PACKAGE__;
    }
    return $status;
}


# Standard fileno IO method / tie hook
sub fileno {
    warn "fileno @_" if $Debug;

    my ($self) = @_;

    # handle tie hook
    $self = $$self if blessed $self and $self->isa(__TIEPACKAGE__);

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->fileno()'
        if not blessed $self;

    # handle GLOB reference
    my $hashref = ${*$self};

    return CORE::fileno $hashref->{fh};
}


# opened IO method
sub opened {
    warn "opened @_" if $Debug;

    my $self = shift;

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->opened()'
        if not blessed $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    return defined CORE::fileno $hashref->{fh};
}


# Standard print IO method / tie hook
sub print {
    warn "print @_" if $Debug;

    my $self = shift;

    # handle tie hook
    $self = $$self if blessed $self and $self->isa(__TIEPACKAGE__);

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->print(ARGS)'
        if not blessed $self;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $status = try eval {
        # IO modifiers based on object's fields
        local $, = exists $hashref->{output_field_separator}
                 ? $hashref->{output_field_separator}
                 : $,;
        local $\ = exists $hashref->{output_record_separator}
                 ? $hashref->{output_record_separator}
                 : $\;

        # IO modifiers based on tied fh modifiers
        my $oldfh = select *$self;
        my $var = $|;
        select $hashref->{fh};
        $| = $var;
        select $oldfh;

        CORE::print { $hashref->{fh} } @_;
    };
    if (catch my $e) {
        $hashref->{error} = 1;
        throw Exception::Fatal $e,
              ignore_package => __PACKAGE__,
              message => 'Cannot print',
            if not defined $e->message;
        throw $e
              ignore_package => __PACKAGE__;
    }
    if (not $status) {
        $hashref->{error} = 1;
        throw Exception::IO
              ignore_package => __PACKAGE__,
              message => 'Cannot print';
    }
    return $self;
}


# Standard printf IO method / tie hook
sub printf {
    warn "printf @_" if $Debug;

    my $self = shift;

    # handle tie hook
    $self = $$self if blessed $self and $self->isa(__TIEPACKAGE__);

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->printf(FMT, [ARGS])'
        if not ref $self;

    # handle GLOB reference
    my $hashref = ${*$self};

    # IO modifiers based on tied fh modifiers
    my $oldfh = select *$self;
    my $var = $|;
    select $hashref->{fh};
    $| = $var;
    select $oldfh;

    my $status = try eval {
        CORE::printf { $hashref->{fh} } @_;
    };
    if (catch my $e) {
        $hashref->{error} = 1;
        throw Exception::Fatal $e,
              ignore_package => __PACKAGE__,
              message => 'Cannot printf',
            if not defined $e->message;
        throw $e
              ignore_package => __PACKAGE__;
    }
    if (not $status) {
        $hashref->{error} = 1;
        throw Exception::IO
              ignore_package => __PACKAGE__,
              message => 'Cannot printf';
    }
    return $self;
}


# Opposite to read
sub write {
    warn "write @_" if $Debug;

    my $self = shift;

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->write(BUF [, LEN [, OFFSET]])'
        if not blessed $self or @_ > 3 || @_ < 1;

    # handle GLOB reference
    my $hashref = ${*$self};

    my ($buf, $len, $offset) = @_;

    my $status = try eval {
        # clean IO modifiers
        local $\ = '';

        # IO modifiers based on tied fh modifiers
        my $oldfh = select *$self;
        my $var = $|;
        select $hashref->{fh};
        $| = $var;
        select $oldfh;

        CORE::print { $hashref->{fh} } substr($buf, $offset || 0, defined $len ? $len : length($buf));
    };
    if (catch my $e) {
        $hashref->{error} = 1;
        throw Exception::Fatal $e,
              ignore_package => __PACKAGE__,
              message => 'Cannot write',
            if not defined $e->message;
        throw $e
              ignore_package => __PACKAGE__;
    }
    if (not $status) {
        $hashref->{error} = 1;
        throw Exception::IO
              ignore_package => __PACKAGE__,
              message => 'Cannot write';
    }
    return $self;
}


# Wrapper for CORE::write
sub format_write {
    warn "format_write @_" if $Debug;

    my $self = shift;

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->format_write([FORMAT_NAME])'
        if not blessed $self or @_ > 1;

    # handle GLOB reference
    my $hashref = ${*$self};

    my ($fmt) = @_;

    my $status;
    {
        my ($oldfmt, $oldtopfmt);

        if (defined $fmt) {
            $oldfmt = $self->format_name(qualify($fmt, caller));
            $oldtopfmt = $self->format_top_name(qualify($fmt . '_TOP', caller));
        }

        # IO modifiers based on tied fh modifiers
        my $oldfh = select *$self;
        my @vars = ($|, $%, $=, $-, $~, $^, $., $:, $^L);
        select $hashref->{fh};
        ($|, $%, $=, $-, $~, $^, $., $:, $^L) = @vars;
        select $oldfh;

        $status = try eval {
            CORE::write $hashref->{fh};
        };

        if (defined $fmt) {
            $self->format_name($oldfmt);
            $self->format_top_name($oldtopfmt);
        }
    }
    if (catch my $e) {
        $hashref->{error} = 1;
        throw Exception::Fatal $e,
              ignore_package => __PACKAGE__,
              message => 'Cannot format_write',
            if not defined $e->message;
        throw $e
              ignore_package => __PACKAGE__;
    }
    if (not $status) {
        $hashref->{error} = 1;
        throw Exception::IO
              ignore_package => __PACKAGE__,
              message => 'Cannot format_write';
    }
    return $self;
}


# Wrapper for CORE::readline. Method / tie hook
sub readline {
    warn "readline @_" if $Debug;

    my $self = shift;

    # handle tie hook
    $self = $$self if blessed $self and $self->isa(__TIEPACKAGE__);

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->readline()'
        if not blessed $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    my ($status, @lines, $line, $ungetc_begin, $ungetc_end);
    my $wantarray = wantarray;

    undef $!;
    try eval {
        # IO modifiers based on object's fields
        local $/ = exists $hashref->{input_record_separator}
                 ? $hashref->{input_record_separator}
                 : $/;

        # scalar or array context
        if ($wantarray) {
            my @ungetc_lines;
            my $ungetc_string = '';
            if (defined $hashref->{ungetc_buffer} and $hashref->{ungetc_buffer} ne '') {
                # iterate for splitted ungetc buffer
                $ungetc_begin = 0;
                while (($ungetc_end = index $hashref->{ungetc_buffer}, $/, $ungetc_begin) > -1) {
                    push @ungetc_lines, substr $hashref->{ungetc_buffer}, $ungetc_begin, $ungetc_end - $ungetc_begin + 1;
                    $ungetc_begin = $ungetc_end + 1;
                }
                # last line of ungetc buffer is also the first line of real readline output
                $ungetc_string = substr $hashref->{ungetc_buffer}, $ungetc_begin;
            }
            $status = scalar(@lines = CORE::readline $hashref->{fh});
            $lines[0] = $ungetc_string . $lines[0] if defined $lines[0] and $lines[0] ne '';
            unshift @lines, @ungetc_lines if @ungetc_lines;
            chomp @lines if $hashref->{autochomp};
            @lines = map { /(.*)/s; $1 } @lines if $hashref->{untaint};
        }
        else {
            my $ungetc_string = '';
            if (defined $hashref->{ungetc_buffer} and $hashref->{ungetc_buffer} ne '') {
                if (($ungetc_end = index $hashref->{ungetc_buffer}, $/, 0) > -1) {
                    $ungetc_string = substr $hashref->{ungetc_buffer}, 0, $ungetc_end + 1;
                }
                else {
                    $ungetc_string = $hashref->{ungetc_buffer};
                }
            }
            if (defined $ungetc_end and $ungetc_end > -1) {
                # only ungetc buffer
                $status = 1;
                $line = $ungetc_string;
            }
            else {
                # also call real readline
                $status = defined($line = CORE::readline $hashref->{fh});
                $line = $ungetc_string . (defined $line ? $line : '');
            }
            chomp $line if $hashref->{autochomp};
            if ($hashref->{untaint}) {
                $line =~ /(.*)/s;
                $line = $1;
            }
        }
    };
    if (catch my $e) {
        $hashref->{error} = 1;
        throw Exception::Fatal $e,
              ignore_package => __PACKAGE__,
              message => 'Cannot readline',
            if not defined $e->message;
        throw $e
              ignore_package => __PACKAGE__;
    }
    if (not $status and $!) {
        $hashref->{error} = 1;
        throw Exception::IO
              ignore_package => __PACKAGE__,
              message => 'Cannot readline';
    }

    # clean ungetc buffer
    if (defined $hashref->{ungetc_buffer} and $hashref->{ungetc_buffer} ne '') {
        if (not $wantarray and $ungetc_end > -1) {
            $hashref->{ungetc_buffer} = substr $hashref->{ungetc_buffer}, $ungetc_end + 1;
        }
        else {
            $hashref->{ungetc_buffer} = '';
        }
    }

    return $wantarray ? @lines : $line;
}


# readline method in scalar context
sub getline {
    warn "getline @_" if $Debug;

    my $self = shift;

    my $line = try eval {
        $self->readline(@_);
    };
    if (catch my $e) {
        throw $e message => 'Usage: $io->getline()'
            if $e->isa('Exception::Argument');
        throw $e message => 'Cannot getline'
            if $e->isa('Exception::Fatal') or $e->isa('Exception::IO');
    }

    return $line;
}


# readline method in array context
sub getlines {
    warn "getlines @_" if $Debug;

    my $self = shift;

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Can\'t call $io->getlines in a scalar context, use $io->getline'
        if not wantarray;

    my @lines = try [ eval {
        $self->readline(@_);
    } ];
    if (catch my $e) {
        throw $e message => 'Usage: $io->getlines()'
            if $e->isa('Exception::Argument');
        throw $e message => 'Cannot getlines'
            if $e->isa('Exception::Fatal') or $e->isa('Exception::IO');
    }

    return @lines;
}


# Add character to the ungetc buffer
sub ungetc {
    warn "ungetc @_" if $Debug;

    my $self = shift;

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->ungetc(ORD)'
        if not blessed $self or @_ != 1 or not looks_like_number $_[0];

    # handle GLOB reference
    my $hashref = ${*$self};

    my ($ord) = @_;

    $hashref->{ungetc_buffer} = '' if not defined $hashref->{ungetc_buffer};
    substr($hashref->{ungetc_buffer}, 0, 0) = chr($ord);

    return $self;
}


# Method wrapper for CORE::sysread
sub sysread {
    warn "sysread @_" if $Debug;

    my $self = shift;

    # handle tie hook
    $self = $$self if blessed $self and $self->isa(__TIEPACKAGE__);

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->sysread(BUF, LEN [, OFFSET])'
        if not ref $self or @_ < 2 or @_ > 3;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $status = try eval {
        CORE::sysread($hashref->{fh}, $_[0], $_[1], $_[2] || 0);
    };
    if (catch my $e) {
        $hashref->{error} = 1;
        throw Exception::Fatal $e,
              ignore_package => __PACKAGE__,
              message => 'Cannot sysread',
            if not defined $e->message;
        throw $e
              ignore_package => __PACKAGE__;
    }
    if (not defined $status) {
        $hashref->{error} = 1;
        throw Exception::IO
              ignore_package => __PACKAGE__,
              message => 'Cannot sysread';
    }
    if (defined $_[0] and $hashref->{untaint}) {
        $_[0] =~ /(.*)/s;
        $_[0] = $1;
    }
    return $status;
}


# Method wrapper for CORE::syswrite
sub syswrite {
    warn "syswrite @_" if $Debug;

    my $self = shift;

    # handle tie hook
    $self = $$self if blessed $self and $self->isa(__TIEPACKAGE__);

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->syswrite(BUF [, LEN [, OFFSET]])'
        if not ref $self or @_ < 1 or @_ > 3;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $status = try eval {
        if (defined($_[1])) {
            CORE::syswrite($hashref->{fh}, $_[0], $_[1], $_[2] || 0);
        }
        else {
            CORE::syswrite($hashref->{fh}, $_[0]);
        }
    };
    if (catch my $e) {
        $hashref->{error} = 1;
        throw Exception::Fatal $e,
              ignore_package => __PACKAGE__,
              message => 'Cannot syswrite',
            if not defined $e->message;
        throw $e
              ignore_package => __PACKAGE__;
    }
    if (not defined $status) {
        $hashref->{error} = 1;
        throw Exception::IO
              ignore_package => __PACKAGE__,
              message => 'Cannot syswrite';
    }
    return $status;
}


# Wrapper for CORE::getc. Method / tie hook
sub getc {
    warn "getc @_" if $Debug;

    my $self = shift;

    # handle tie hook
    $self = $$self if blessed $self and $self->isa(__TIEPACKAGE__);

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->getc()'
        if not blessed $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    undef $!;
    my $char = try eval {
        if (defined $hashref->{ungetc_buffer} and $hashref->{ungetc_buffer} ne '') {
            substr $hashref->{ungetc_buffer}, 0, 1;
        }
        else {
            CORE::getc $hashref->{fh};
        }
    };
    if (catch my $e) {
        $hashref->{error} = 1;
        throw Exception::Fatal $e,
              ignore_package => __PACKAGE__,
              message => 'Cannot getc',
            if not defined $e->message;
        throw $e
              ignore_package => __PACKAGE__;
    }
    if (not defined $char and $! and $! != Errno::EBADF) {
        $hashref->{error} = 1;
        throw Exception::IO
              ignore_package => __PACKAGE__,
              message => 'Cannot getc';
    }

    # clean ungetc buffer
    if (defined $hashref->{ungetc_buffer} and $hashref->{ungetc_buffer} ne '') {
        $hashref->{ungetc_buffer} = substr $hashref->{ungetc_buffer}, 1;
    }

    if (defined $char and $hashref->{untaint}) {
        $char =~ /(.*)/s;
        $char = $1;
    }

    return $char;
}


# print with EOL
sub say {
    warn "say @_" if $Debug;

    my $self = shift;

    try eval {
        $self->print(@_, "\n");
    };
    if (catch my $e) {
        throw $e message => 'Usage: $io->say(ARGS)'
            if $e->isa('Exception::Argument');
        throw $e message => 'Cannot say'
            if $e->isa('Exception::Fatal') or $e->isa('Exception::IO');
    }

    return $self;
}


# Read whole file
sub slurp {
    warn "slurp @_" if $Debug;

    my $self = shift;

    if (not blessed $self) {
        throw Exception::Argument
              ignore_package => __PACKAGE__,
              message => 'Usage: ' . __PACKAGE__ . '->slurp(FD)'
            if not blessed $self and @_ != 1;

        my $class = $self;
        my ($fd) = (@_);

        $self = $class->new(fd => $fd, mode => '<');
    }
    else {
        throw Exception::Argument
              ignore_package => __PACKAGE__,
              message => 'Usage: $io->slurp()'
            if @_ > 0;
    }

    # handle GLOB reference
    my $hashref = ${*$self};

    my (@lines, $string);
    my $wantarray = wantarray;

    undef $!;
    try eval {
        # scalar or array context
        if ($wantarray) {
            local $hashref->{input_record_separator} = "\n";
            @lines = $self->readline;
        }
        else {
            local $hashref->{input_record_separator} = undef;
            local $hashref->{autochomp} = 0;
            $string = $self->readline;
        }
    };
    if (catch my $e) {
        throw $e message => 'Cannot slurp';
    }

    return $wantarray ? @lines : $string;
}


# Wrapper for CORE::truncate
sub truncate {
    warn "truncate @_" if $Debug;

    my $self = shift;

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->truncate(LEN)'
        if not ref $self or @_ != 1;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $status = try eval {
        CORE::truncate($hashref->{fh}, $_[0]);
    };
    if (catch my $e) {
        $hashref->{error} = 1;
        throw Exception::Fatal $e,
              ignore_package => __PACKAGE__,
              message => 'Cannot truncate',
            if not defined $e->message;
        throw $e
              ignore_package => __PACKAGE__;
    }
    if (not defined $status) {
        $hashref->{error} = 1;
        throw Exception::IO
              ignore_package => __PACKAGE__,
              message => 'Cannot truncate';
    }
    return $status;
}


# Interface for File::Stat::Moose
sub stat {
    warn "stat @_" if $Debug;

    my $self = shift;

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->stat()'
        if not ref $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $stat = try eval {
        File::Stat::Moose->new(file => $hashref->{fh});
    };
    if (catch my $e) {
        $hashref->{error} = 1;
        throw Exception::Fatal $e,
              ignore_package => __PACKAGE__,
              message => 'Cannot stat',
            if not defined $e->message;
        throw $e
              ignore_package => __PACKAGE__;
    }
    return $stat;
}


# Pure Perl implementation
sub error {
    warn "error @_" if $Debug;

    my $self = shift;

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->error()'
        if not blessed $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    if (defined CORE::fileno $hashref->{fh}) {
        return $hashref->{error};
    }
    else {
        return -1;
    }
}


# Pure Perl implementation
sub clearerr {
    warn "clearerr @_" if $Debug;

    my $self = shift;

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->clearerr()'
        if not blessed $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    if (defined CORE::fileno $hashref->{fh}) {
        return $hashref->{error} = 0;
    }
    else {
        return -1;
    }
}


# Pure Perl implementation with syscall
sub sync {
    warn "sync @_" if $Debug;

    my $self = shift;

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->sync()'
        if not blessed $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    if (defined &IO::Moose::Handle::Syscall::SYS_fsync and defined CORE::fileno $hashref->{fh}) {
        return syscall(&IO::Moose::Handle::Syscall::SYS_fsync, CORE::fileno $hashref->{fh}) == 0
               ? '0 but true'
               : undef;
    }
    else {
        return;
    }
}


# Pure Perl implementation
sub flush {
    warn "flush @_" if $Debug;

    my $self = shift;

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->flush()'
        if not blessed $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $oldfh = select $hashref->{fh};
    my @var = ($|, $\);
    $| = 1;
    $\ = undef;

    my $status = try eval {
        CORE::print { $hashref->{fh} } '';
    };

    ($|, $\) = @var;
    select $oldfh;

    return $status ? '0 but true' : undef;
}


# flush + print
sub printflush {
    warn "flush @_" if $Debug;

    my $self = shift;

    if (ref $self) {
        # handle GLOB reference
        my $hashref = ${*$self};

        my $oldfh = select *$self;
        my $var = $|;
        $| = 1;

        my $status = try eval {
            $self->print(@_);
        };

        $| = $var;
        select $oldfh;

        if (catch my $e) {
            throw $e message => 'Usage: $io->printflush()'
                if $e->isa('Exception::Argument');
            throw $e message => 'Cannot printflush'
                if $e->isa('Exception::Fatal') or $e->isa('Exception::IO');
        }

        return $status;
    }
    else {
        local $| = 1;
        CORE::print @_;
    }
}


# Pure Perl implementation
sub blocking {
    warn "blocking @_" if $Debug;

    my $self = shift;

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->blocking([BOOL])'
        if not blessed $self or @_ > 1;

    return if not defined $Fcntl::VERSION;

    # handle GLOB reference
    my $hashref = ${*$self};

    my ($block) = @_;
    my $newmode;

    my $status;
    try eval {
        my $mode = eval { fcntl($hashref->{fh}, &Fcntl::F_GETFL, 0) };

        throw Exception::IO
              message => 'Cannot blocking: F_GETFL'
            if not defined $mode;

        $status = $newmode = $mode;

        my $O_NONBLOCK = eval { &Fcntl::O_NONBLOCK };

        if (defined $O_NONBLOCK) {
            my $O_NDELAY = eval { &Fcntl::O_NDELAY };
            if (not defined $O_NDELAY) {
                $O_NDELAY = $O_NONBLOCK;
            }
            $status = $status & ($O_NONBLOCK | $O_NDELAY) ? 0 : 1;

            if (defined $block) {
                if ($block == 0) {
                    $newmode &= ~$O_NDELAY;
                    $newmode |= $O_NONBLOCK;
                }
                elsif ($block > 0) {
                    $newmode &= ~($O_NDELAY|$O_NONBLOCK);
                }
            }
        }
        else { # not defined $O_NONBLOCK
            my $O_NDELAY = &Fcntl::O_NDELAY;
            $status = $status & $O_NDELAY ? 0 : 1;

            if (defined $block) {
                if ($block == 0) {
                    $newmode |= $O_NDELAY;
                }
                elsif ($block > 0) {
                    $newmode &= ~$O_NDELAY;
                }
            }
        }

        if (defined $block and $newmode != $mode) {
            throw Exception::IO
                  message => 'Cannot blocking: F_SETFL'
                if not defined eval { fcntl($hashref->{fh}, &Fcntl::F_SETFL, $newmode) };
        }
    };

    if (catch my $e) {
        throw Exception::Fatal $e,
              ignore_package => __PACKAGE__,
              message => 'Cannot blocking',
            if not defined $e->message;
        throw $e
              ignore_package => __PACKAGE__;
    }

    return $status;
}


# Mark untaint attribute
sub untaint {
    warn "untaint @_" if $Debug;

    my $self = shift;

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->untaint()'
        if not blessed $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    throw Exception::Fatal
          ignore_package => __PACKAGE__,
          message => 'Cannot untaint'
        if not defined CORE::fileno $hashref->{fh};

    $hashref->{untaint} = 1;

    return '0 but true';
}


# Unmark untaint attribute
sub taint {
    warn "taint @_" if $Debug;

    my $self = shift;

    throw Exception::Argument
          ignore_package => __PACKAGE__,
          message => 'Usage: $io->taint()'
        if not blessed $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    throw Exception::Fatal
          ignore_package => __PACKAGE__,
          message => 'Cannot taint'
        if not defined CORE::fileno $hashref->{fh};

    $hashref->{untaint} = 0;

    return '0 but true';
}


# Clean up on destroy
sub DESTROY {
    warn "DESTROY @_" if $Debug;

    my ($self) = @_;
    untie *$self;
}


# Add missing methods through Class::MOP
INIT: {
    # Generate accessors for IO modifiers (global and local)
    my %standard_accessors = (
        input_record_separator  => '/',   # $/
        output_field_separator  => ',',   # $,
        output_record_separator => '\\',  # $\
    );
    while (my ($func, $var) = each(%standard_accessors)) {
        no strict 'refs';
        __PACKAGE__->meta->add_method($func => sub {
            local *__ANON__ = $func;
            warn "$func @_" if $Debug;
            my $self = shift;
            throw Exception::Argument
                  message => "Usage: \$io->$func([EXPR])"
                if @_ > 1;
            if (ref $self) {
                my $hashref = ${*$self} if reftype $self eq 'GLOB';
                my $prev = $hashref->{$func};
                if (@_ > 0) {
                    $hashref->{$func} = shift;
                }
                return $prev;
            }
            else {
                my $prev = ${*$var};
                if (@_ > 0) {
                    ${*$var} = shift;
                }
                return $prev;
            }
        });
    }

    # Generate accessors for IO modifiers (output modifiers which require select)
    my %output_accessors = (
        format_formfeed              => "\014",  # $^L
        format_line_break_characters => ':',     # $:
        format_lines_left            => '-',     # $-
        format_lines_per_page        => '=',     # $=
        format_page_number           => '%',     # $%
        input_line_number            => '.',     # $.
        output_autoflush             => '|',     # $|
    );
    while (my ($func, $var) = each(%output_accessors)) {
        no strict 'refs';
        __PACKAGE__->meta->add_method($func => sub {
            local *__ANON__ = $func;
            warn "$func @_" if $Debug;
            my $self = shift;
            throw Exception::Argument
                  message => "Usage: \$io->$func([EXPR])"
                if @_ > 1;
            if (ref $self) {
                my $oldfh = select *$self;
                my $prev = ${*$var};
                if (@_ > 0) {
                    ${*$var} = shift;
                }
                select $oldfh;
                return $prev;
            }
            else {
                my $prev = ${*$var};
                if (@_ > 0) {
                    ${*$var} = shift;
                }
                return $prev;
            }
        });
    }

    # Generate accessors for IO modifiers (qualified format name)
    my %format_name_accessors = (
        format_name      => '~',  # $~
        format_top_name  => '^',  # $^
    );
    while (my ($func, $var) = each(%format_name_accessors)) {
        no strict 'refs';
        __PACKAGE__->meta->add_method($func => sub {
            local *__ANON__ = $func;
            warn "$func @_" if $Debug;
            my $self = shift;
            throw Exception::Argument
                  message => "Usage: \$io->$func([EXPR])"
                if @_ > 1;
            if (ref $self) {
                my $oldfh = select *$self;
                my $prev = ${*$var};
                if (@_ > 0) {
                    my $value = shift;
                    ${*$var} = defined $value ? qualify($value, caller) : undef;
                }
                select $oldfh;
                return $prev;
            }
            else {
                my $prev = ${*$var};
                my $value = shift;
                ${*$var} = defined $value ? qualify($value, caller) : undef;
                return $prev;
            }
        });
    }

    # Alias
    __PACKAGE__->meta->alias_method('autoflush' => \&output_autoflush);

    # Assing tie hooks to real functions
    foreach my $func (qw< close eof fileno print printf readline getc >) {
        __TIEPACKAGE__->meta->alias_method(
            uc($func) => __PACKAGE__->meta->get_method($func)->body
        );
    }
    foreach my $func (qw< read write >) {
        __TIEPACKAGE__->meta->alias_method(
            uc($func) => __PACKAGE__->meta->get_method('sys' . $func)->body
        );
    }

    # Make immutable finally
    __PACKAGE__->meta->make_immutable;
}



package IO::Moose::Handle::Tie;

use Moose;

use Scalar::Util 'weaken';

*Debug = \$IO::Moose::Handle::Debug;


# Tie hook. Others are initialized by IO::Moose::Handle.
sub TIEHANDLE {
    warn "TIEHANDLE @_" if $Debug;

    my ($class, $instance) = @_;

    # tie object will be stored in scalar reference of main object
    my $self = \$instance;

    # weaken the real object, otherwise it won't be destroyed automatically
    weaken $instance;

    return bless $self => $class;
}


sub UNTIE {
    warn "UNTIE @_" if $Debug;
}


sub DESTROY {
    warn "DESTROY @_" if $Debug;
}



package IO::Moose::Handle::Syscall;


# Use SYS_fsync for sync method
eval { require 'syscall.ph' };
# Workaround for bug on Ubuntu gutsy i386
if (defined &__NR_fsync and defined &__i386 and defined &_ASM_X86_64_UNISTD_H_) {
    # Store and restore other typeglobs than CODE
    my %glob;
    foreach my $type (qw< SCALAR ARRAY HASH IO FORMAT >) {
        $glob{$type} = *{__NR_fsync}{$type}
            if defined *{__NR_fsync}{$type};
    }
    undef *{__NR_fsync};
    foreach my $type (qw< SCALAR ARRAY HASH IO FORMAT >) {
        *{__NR_fsync} = $glob{$type}
            if defined $glob{$type};
    }
    eval { require 'asm-i386/unistd.ph' };
}



1;


__END__

=for readme stop

=head1 BASE CLASSES

=over 2

=item *

L<MooseX::GlobRef::Object>

=back

=head1 FIELDS

=over

=item fd (rw, new)

File descriptor (string, file handle or IO object) as a parameter for new
object.

=item mode (rw, new)

File mode as a parameter for new object. Can be Perl-style (E<lt>, E<gt>,
E<gt>E<gt>, etc.) or C-style (r, w, a, etc.)

=item fh (ro)

File handler used for internal IO operations.

=item autochomp (rw)

If is true value the input will be auto chomped.

=item input_record_separator, clear_input_record_separator (rw, $/)

=item output_field_separator, clear_output_field_separator (rw, $,)

=item output_record_separator, clear_output_record_separator (rw, $\)

=item format_formfeed, clear_format_formfeed (rw, $^L)

=item format_line_break_characters, clear_format_line_break_characters (rw, $:)

=item format_lines_left (rw, $-)

=item format_lines_per_page (rw, $=)

=item format_page_number (rw, $%)

=item input_line_number (rw, $.)

=item autoflush, output_autoflush (rw, $|)

=item format_name (rw, $~)

=item format_top_name (rw, $^)

These are attributes assigned with Perl's built-in variables. See L<perlvar>
for complete descriptions.  The fields have accessors available as
per-filehandle basis if called as B<$io-E<gt>accessor> or as global setting if
called as B<IO::Moose::Handle-E<gt>accessor>.

=back

=head1 CONSTRUCTORS

=over

=item new

Creates the B<IO::Moose::Handle> object and calls B<fdopen> method if the
I<fd> parameter is defined.

  $io = new IO::Moose::Handle fd=>\*STDIN, mode=>"r";

The object can be created with uninitialized file handle.

  $in = new IO::Moose::Handle;
  $in->fdopen(\*STDIN);

=item new_from_fd(I<fd> [, I<mode>])

Creates the B<IO::Moose::Handle> object and immediately opens the file handle
based on arguments.

  $out = new_from_fd IO::Moose::Handle \*STDOUT, "w";

=back

=head1 METHODS

=over

=item fdopen(I<fd> [, I<mode>])

Opens the file handle based on existing file handle, file handle name, IO
object or file descriptor number.

  $out = new IO::Moose::Handle;
  $out->fdopen(\*STDOUT, "w");

  $dup = new IO::Moose::Handle;
  $dup->fdopen($out, "a");

=item close

=item eof

=item fileno

=item print([I<args>])

=item printf([I<fmt> [, I<args>]])

=item readline

=item sysread(I<buf>, I<len> [, I<offset>])

=item syswrite(I<buf> [, I<len> [, I<offset>]])

=item getc

=item truncate(I<len>)

These are front ends for corresponding built-in functions.  Most of them
throws exception on failure which can be caught with try/catch:

  use Exception::Base ':all';
  try eval {
    open $f, "/etc/hostname";
    $io = new IO::Moose::Handle fd=>$f, mode=>"r";
    $c = $io->getc;
  };
  if (catch my $e) {
    warn "problem with /etc/hostname file: $e";
  }

=item opened

Returns true value if the object has opened file handle, false otherwise.

=item write(I<buf> [, I<len> [, I<offset>]])

The opposite of B<read>. The wrapper for the perl B<CORE::write> function is called
B<format_write>.

=item format_write([<format_name])

The wrapper for perl B<CORE::format> function.

=item getline

The B<readline> method which is called always in scalar context.

  $io = new IO::Moose::Handle fd=>\*STDIN, mode=>"r";
  push @a, $io->readline;  # reads only one line

=item getlines

The B<readline> method which is called always in array context.

  $io = new IO::Moose::Handle fd=>\*STDIN, mode=>"r";
  print scalar $io->readlines;  # error: can't call in scalar context.

=item ungetc(I<ord>)

Pushes a character with the given ordinal value back onto the given handle's
input stream.  In fact this is emulated in pure-Perl code and can't be mixed
with non IO::Moose::Handle objects.

  $io = new IO::Moose::Handle fd=>\*STDIN, mode=>"r";
  $io->ungetc(ord('A'));
  print $io->getc;  # prints A

=item say([I<args>])

The B<print> method with EOL character at the end.

  $io = new IO::Moose::Handle fd=>\*STDOUT, mode=>"w";
  $io->say("Hello!");

=item slurp

Reads whole file and returns its content as a scalar in scalar context or as
an array in array context (like B<getlines> method).

  open $f, "/etc/passwd";
  
  $io1 = new IO::Moose::Handle fd=>$f, "r";
  $passwd_file = $io1->slurp;
  
  $io2 = new IO::Moose::Handle fd=>$f, "r";
  $io2->autochomp(1);
  @passwd_lines = $io2->slurp;

=item IO::Moose::Handle->slurp(I<fd>)

Creates the B<IO::Moose::Handle> object and returns its content as a scalar in
scalar context or as an array in array context.

  open $f, "/etc/passwd";  
  $passwd_file = IO::Moose::Handle->slurp($f);

=item stat

Returns B<File::Stat::Moose> object which represents status of file pointed by
current file handle.

  open $f, "/etc/passwd";
  $io = new IO::Moose::Handle fd=>$f, "r";
  $st = $io->stat;
  print $st->size;  # size of /etc/passwd file

=item error

Returns true value if the given handle has experienced any errors since it was
opened or since the last call to B<clearerr>, or if the handle is invalid.

It is recommended to use exceptions mechanism to handle errors.

=item clearerr

Clear the given handle's error indicator. Returns -1 if the handle is invalid,
0 otherwise.

=item sync

Synchronizes a file's in-memory state with that on the physical medium.  It
operates on file descriptor and it is low-level operation.  Returns "0 but
true" on success or undef on error.

=item flush

Flushes any buffered data at the perlio api level.  Returns "0 but true" on
success or undef on error.

=item printflush(I<args>)

Turns on autoflush, print I<args> and then restores the autoflush status. 
Returns the return value from B<print>.

=item blocking([I<bool>])

If called with an argument blocking will turn on non-blocking IO if I<bool> is
false, and turn it off if I<bool> is true.  B<blocking> will return the value
of the previous setting, or the current setting if I<bool> is not given.

=item untaint

Marks the object as taint-clean, and as such data read from it will also be
considered taint-clean.  Returns "0 but true" on success, -1 if setting the
taint-clean flag failed.  It has meaning only if Perl is running in tainted
mode (-T).

=item taint

Unmarks the object as taint-clean.  Returns "0 but true" on success, -1 if
setting the taint-clean flag failed.

=back

=head1 INTERNALS

The main problem is that Perl does not support the indirect notation for IO
object's functions like B<print>, B<close>, etc.

  package My::IO::BadExample;
  sub new { bless {}, $_[0]; }
  sub open { my $self=shift; CORE::open $self->{fh}, @_; }
  sub print { my $self=shift; CORE::print {$self->{fh}} @_; }

  package main;
  my $io = new My::IO::BadExample;
  open $io '>', undef;  # Wrong: missing comma after first argument
  print $io "test";     # Wrong: not GLOB reference

You can use tied handlers:

  $io = \*FOO;
  tie *$io, 'My::IO::Tie';
  open $io, '>', undef;  # see comma after $io: open is just a function
  print $io "test";      # standard indirect notation

The IO::Moose::Handle object is stored in hash available via globref.

There are two handlers used for IO operations: the original handler used for
real IO operations and tied handler which hooks IO functions interface.

The OO-style uses orignal handler stored in I<fh> field.

  $io->print("OO style");
  ## package IO::Moose::Handle;
  ## sub print { $self=shift; $hashref=${*$self};
  ##   CORE::print {$hashref->{fh}} @_
  ## }

The IO functions-style uses object reference which is derefered as a handler
tied to proxy object which operates on original handler.

  print $io "IO functions style";
  ## package IO::Moose::Handle::Tie;
  ## \*PRINT = &IO::Moose::Handle::print;
  ## ## package IO::Moose::Handle;
  ## ## sub print { $self=shift; $self=$$self; $hashref=${*$self};
  ## ##   CORE::print {$hashref->{fh}} @_
  ## ## }

=head1 SEE ALSO

L<IO::Handle>, L<MooseX::GlobRef::Object>, L<Moose>.

=head1 BUGS

The API is not stable yet and can be changed in future.

=for readme continue

=head1 AUTHOR

Piotr Roszatycki E<lt>dexter@debian.orgE<gt>

=head1 LICENSE

Copyright 2007, 2008 by Piotr Roszatycki E<lt>dexter@debian.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
