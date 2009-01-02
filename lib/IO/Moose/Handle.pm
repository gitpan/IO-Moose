#!/usr/bin/perl -c

package IO::Moose::Handle;

=head1 NAME

IO::Moose::Handle - Reimplementation of IO::Handle with improvements

=head1 SYNOPSIS

  use IO::Moose::Handle;

  my $fh = IO::Moose::Handle->new;
  $fh->fdopen( fileno(STDIN) );
  print $fh->getline;
  my $content = $fh->slurp;
  $fh->close;

  my $fh = IO::Moose::Handle->fdopen( \*STDERR, '>' );
  $fh->autoflush(1);
  $fh->say('Some text');
  undef $fh;  # calls close at DESTROY

=head1 DESCRIPTION

This class extends L<IO::Handle> with following differences:

=over

=item *

It is based on L<Moose> object framework.

=item *

The C<stat> method returns L<File::Stat::Moose> object.

=item *

It uses L<Exception::Base> for signaling errors. Most of methods are throwing
exception on failure.

=item *

The modifiers like C<input_record_separator> are supported on per file handle
basis.

=item *

It also implements additional methods like C<say>, C<slurp>.

=back

=cut

use 5.008;
use strict;
use warnings FATAL => 'all';

our $VERSION = 0.06;

use Moose;

extends 'MooseX::GlobRef::Object', 'IO::Handle';


use MooseX::Types::OpenModeStr;
use MooseX::Types::CanonOpenModeStr;


use Exception::Base (
    '+ignore_package'  => [ __PACKAGE__, qr/^MooseX?::/, qr/^Class::MOP::/ ],
);
use Exception::Argument;
use Exception::Fatal;


# TRUE and FALSE
use constant::boolean;

use Scalar::Util 'blessed', 'reftype', 'weaken', 'looks_like_number';
use Symbol       'qualify';

use File::Stat::Moose;


# Use Errno for EBADF error code.
use Errno;


# Assertions
use Test::Assert ':assert';

# Debugging flag
use if $ENV{PERL_DEBUG_IO_MOOSE_HANDLE}, 'Smart::Comments';


# Standard handles
our ($STDIN, $STDOUT, $STDERR);


# File to open (descriptor number or file handle)
has file => (
    is      => 'rw',
    isa     => 'Num | FileHandle | OpenHandle',
    is_weak => 1,
    reader  => 'file',
    writer  => '_set_file',
);

# Deprecated: backward compatibility
has fd => (
    is      => 'ro',
    isa     => 'Num | FileHandle | OpenHandle',
    is_weak => 1,
);

# File mode
has mode => (
    is      => 'rw',
    isa     => 'CanonOpenModeStr',
    default => '<',
    coerce  => 1,
    reader  => 'mode',
    writer  => '_set_mode',
    clearer => '_clear_mode',
);

# File handle
has fh => (
    is      => 'ro',
    isa     => 'GlobRef',
    reader  => 'fh',
    writer  => '_set_fh',
);

# Flag that input should be automaticaly chomp-ed
has autochomp => (
    is      => 'rw',
    isa     => 'Bool',
    default => FALSE,
);

# Flag that non-blocking IO should be turned on
has blocking => (
    is      => 'rw',
    isa     => 'Bool',
    default => TRUE,
    reader  => '_get_blocking',
    writer  => '_set_blocking',
);

# Flag that input is tainted.
has tainted => (
    is       => 'rw',
    isa      => 'Bool',
    default  => !! ${^TAINT},
);

# Flag if error was occured in IO operation
has _error => (
    isa     => 'Bool',
    default => FALSE,
);

# Buffer for ungetc
has _ungetc_buffer => (
    isa     => 'Str',
    default => '',
);

# IO modifiers per file handle with special accessor
{
    foreach my $attr ( qw{
        format_formfeed
        format_line_break_characters
        input_record_separator
        output_field_separator
        output_record_separator
    } ) {

        has $attr => (
            # is    => 'rw',
            has     => 'Str',
            clearer => "clear_$attr",
        );

    };
};


## no critic (ProhibitOneArgSelect)
## no critic (ProhibitBuiltinHomonyms)
## no critic (ProhibitCaptureWithoutTest)
## no critic (RequireArgUnpacking)
## no critic (RequireCheckingReturnValueOfEval)
## no critic (RequireLocalizedPunctuationVars)

# Import standard handles
sub import {
    my ($pkg, @args) = @_;

    my %vars;
    foreach my $arg (@args) {
        if (defined $arg and $arg =~ /^:(all|std)$/) {
            %vars = map { $_ => 1 } qw{ STDIN STDOUT STDERR };
        }
        elsif (defined $arg and $arg =~ /^\$(STDIN|STDOUT|STDERR)$/) {
            $vars{$1} = 1;
        }
        else {
            Exception::Argument->throw(
                message => "Unknown argument for import: " . (defined $arg ? $arg : 'undef'),
            );
        };
    };

    my $caller = caller;
    no strict 'refs';

    foreach my $var (keys %vars) {
        if ($var eq 'STDIN') {
            $STDIN  = __PACKAGE__->new( file => \*STDIN,  mode => '<' ) if not defined $STDIN;
            *{"${caller}::STDIN"}  = \$STDIN;
        }
        elsif ($var eq 'STDOUT') {
            $STDOUT = __PACKAGE__->new( file => \*STDOUT, mode => '>' ) if not defined $STDOUT;
            *{"${caller}::STDOUT"} = \$STDOUT;
        }
        elsif ($var eq 'STDERR') {
            $STDERR = __PACKAGE__->new( file => \*STDERR, mode => '>' ) if not defined $STDERR;
            *{"${caller}::STDERR"} = \$STDERR;
        }
        else {
            assert_false("Unknown variable \$$var") if ASSERT;
        };
    };

    return TRUE;
};


# Default constructor
sub BUILD {
    ### BUILD: @_

    my ($self, $params) = @_;

    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    # initialize anonymous handle
    select select my $fh;
    $hashref->{fh} = $fh;

    my $is_opened = eval { $self->_open_file };
    if ($@) {
        my $e = Exception::Fatal->catch;
        $e->throw( message => 'Cannot new' );
    };
    assert_not_null($is_opened) if ASSERT;

    if (not $is_opened) {
        # tie handle with proxy class if is not already opened
        tie *$self, blessed $self, $self;
    };

    return $self;
};


# Open file if is defined
sub _open_file {
    #### _open_file: @_

    my ($self) = @_;

    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    if (defined $hashref->{file}) {
        # call fdopen if file is defined; it also ties handle
        $self->fdopen($hashref->{file}, $hashref->{mode});
        return TRUE;
    }
    elsif (defined $hashref->{fd}) {
        ## no critic (RequireCarping)
        warn "IO::Moose::Handle->fd attribute is deprecated. Use file attribute instead";
        $self->fdopen($hashref->{fd}, $hashref->{mode});
        return TRUE;
    };

    return FALSE;
};


# fdopen constructor
sub new_from_fd {
    ### new_from_fd: @_

    my ($class, $fd, $mode) = @_;

    my $io = eval { $class->new(
        file => $fd,
        defined $mode ? (mode => $mode) : ()
    ) };
    if ($@) {
        my $e = Exception::Fatal->catch;
        $e->throw( message => 'Cannot new_from_fd' );
    };
    assert_isa(__PACKAGE__, $io) if ASSERT;

    return $io;
};


# fdopen method
sub fdopen {
    ### fdopen: @_

    my $self = shift;
    Exception::Argument->throw(
        message => 'Usage: $io->fdopen(FD, [MODE])',
    ) if not blessed $self or @_ < 1 or @_ > 2;

    my ($fd, $mode) = @_;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my $status;
    eval {
        # check constraints and fill attributes
        $fd = $self->_set_file($fd);
        $mode = defined $mode ? $self->_set_mode($mode) : $self->_clear_mode;

        if (blessed $fd and $fd->isa(__PACKAGE__)) {
            #### fdopen: "open(fh, $mode&, \$fd->{fh})"
            $status = CORE::open $hashref->{fh}, "$mode&", ${*$fd}->{fh};
        }
        elsif ((ref $fd || '') eq 'GLOB') {
            #### fdopen: "open(fh, $mode&, \\$$fd)"
            $status = CORE::open $hashref->{fh}, "$mode&", $fd;
        }
        elsif ((reftype $fd || '') eq 'GLOB') {
            #### fdopen: "open(fh, $mode&, *$fd)"
            $status = CORE::open $hashref->{fh}, "$mode&", *$fd;
        }
        elsif ($fd =~ /^\d+$/) {
            #### fdopen: "open(fh, $mode&=$fd)"
            $status = CORE::open $hashref->{fh}, "$mode&=$fd";
        }
        else {
            # should be caught by constraint
            assert_false("Bad file descriptor");
        };
    };
    if (not $status) {
        $hashref->{_error} = TRUE;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot fdopen' );
    };
    assert_true($status) if ASSERT;

    $hashref->{_error} = FALSE;

    # clone standard handle for tied handle
    untie *$self;
    CORE::close *$self;

    eval {
        CORE::open *$self, "$mode&", $hashref->{fh};
    };
    if ($@) {
        Exception::Fatal->throw( message => 'Cannot open' );
    };

    tie *$self, blessed $self, $self;
    assert_true(tied *$self) if ASSERT;

    if (${^TAINT} and not $hashref->{tainted}) {
        $self->untaint;
    };

    if (${^TAINT} and not $hashref->{blocking}) {
        $self->blocking(FALSE);
    };

    return $self;
};


# Standard close IO method / tie hook
sub close {
    ### close: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->close()'
    ) if not blessed $self or @_ > 0;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    if (not CORE::close $hashref->{fh}) {
        $hashref->{_error} = TRUE;
        Exception::IO->throw( message => 'Cannot close' );
    };

    $hashref->{_error} = FALSE;

    # close also tied handle
    untie *$self;
    CORE::close *$self;
    tie *$self, blessed $self, $self;
    assert_true(tied *$self) if ASSERT;

    return $self;
};


# Standard eof IO method / tie hook
sub eof {
    ### eof: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->eof()'
    ) if not blessed $self or @_ > 0;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my $status;
    eval {
        $status = CORE::eof $hashref->{fh};
    };
    if ($@) {
        my $e = Exception::Fatal->catch;
        $e->throw( message => 'Cannot eof' );
    };
    return $status;
};


# Standard fileno IO method / tie hook
sub fileno {
    ### fileno: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->fileno()'
    ) if not blessed $self or @_ > 0;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my $fileno = CORE::fileno $hashref->{fh};
    if (not defined $fileno) {
        local $! = Errno::EBADF;
        Exception::IO->throw( message => 'Cannot fileno' );
    };

    return $fileno;
};


# opened IO method
sub opened {
    ### opened: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->opened()'
    ) if not blessed $self or @_ > 0;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my $fileno;
    eval {
        $fileno = CORE::fileno $hashref->{fh};
    };

    return defined $fileno;
};


# Standard print IO method / tie hook
sub print {
    ### print: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->print(ARGS)'
    ) if not blessed $self;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my $status;
    eval {
        # IO modifiers based on object's attributes
        local $, = exists $hashref->{output_field_separator}
                 ? $hashref->{output_field_separator}
                 : $,;
        local $\ = exists $hashref->{output_record_separator}
                 ? $hashref->{output_record_separator}
                 : $\;

        {
            # IO modifiers based on tied fh modifiers
            my $oldfh = select *$self;
            my $var = $|;
            select $hashref->{fh};
            $| = $var;
            select $oldfh;
        };

        $status = CORE::print { $hashref->{fh} } @_;
    };
    if (not $status) {
        $hashref->{_error} = TRUE;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot print' );
    };
    assert_true($status) if ASSERT;

    return $self;
};


# Standard printf IO method / tie hook
sub printf {
    ### printf: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->printf(FMT, [ARGS])'
    ) if not ref $self;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    {
        # IO modifiers based on tied fh modifiers
        my $oldfh = select *$self;
        my $var = $|;
        select $hashref->{fh};
        $| = $var;
        select $oldfh;
    };

    my $status;
    eval {
        $status = CORE::printf { $hashref->{fh} } @_;
    };
    if (not $status) {
        $hashref->{_error} = TRUE;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot printf' );
    };
    assert_true($status) if ASSERT;

    return $self;
};


# Wrapper for CORE::write
sub format_write {
    ### format_write: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->format_write([FORMAT_NAME])'
    ) if not blessed $self or @_ > 1;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my ($fmt) = @_;

    my $e;
    my $status;
    {
        my ($oldfmt, $oldtopfmt);

        # New format in argument
        if (defined $fmt) {
            $oldfmt = $self->format_name(qualify($fmt, caller));
            $oldtopfmt = $self->format_top_name(qualify($fmt . '_TOP', caller));
        }

        # IO modifiers based on object's attributes
        my @vars = ($:, $^L);

        # Global variables without local scope
        $:  = exists $hashref->{format_line_break_characters}
              ? $hashref->{format_line_break_characters}
              : $:;
        $^L = exists $hashref->{format_formfeed}
              ? $hashref->{format_formfeed}
              : $^L;

        # IO modifiers based on tied fh modifiers
        {
            my $oldfh = select *$self;
            my @vars = ($|, $%, $=, $-, $~, $^, $.);
            select $hashref->{fh};
            ($|, $%, $=, $-, $~, $^, $.) = @vars;
            select $oldfh;
        };

        eval {
            $status = CORE::write $hashref->{fh};
        };
        $e = Exception::Fatal->catch;

        # Restore previous settings
        ($:, $^L) = @vars;
        if (defined $fmt) {
            $self->format_name($oldfmt);
            $self->format_top_name($oldtopfmt);
        };
    };
    if (not $status) {
        $hashref->{_error} = TRUE;
        $e = Exception::IO->new unless $e;
        $e->throw( message => 'Cannot format_write' );
    };
    assert_true($status) if ASSERT;

    return $self;
};


# Wrapper for CORE::readline. Method / tie hook
sub readline {
    ### readline: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->readline()'
    ) if not blessed $self or @_ > 0;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my ($status, @lines, $line, $ungetc_begin, $ungetc_end);
    my $wantarray = wantarray;

    undef $!;
    eval {
        # IO modifiers based on object's attributes
        local $/ = exists $hashref->{input_record_separator}
                 ? $hashref->{input_record_separator}
                 : $/;

        # scalar or array context
        if ($wantarray) {
            my @ungetc_lines;
            my $ungetc_string = '';
            if (defined $hashref->{_ungetc_buffer} and $hashref->{_ungetc_buffer} ne '') {
                # iterate for splitted ungetc buffer
                $ungetc_begin = 0;
                while (($ungetc_end = index $hashref->{_ungetc_buffer}, $/, $ungetc_begin) > -1) {
                    push @ungetc_lines, substr $hashref->{_ungetc_buffer}, $ungetc_begin, $ungetc_end - $ungetc_begin + 1;
                    $ungetc_begin = $ungetc_end + 1;
                }
                # last line of ungetc buffer is also the first line of real readline output
                $ungetc_string = substr $hashref->{_ungetc_buffer}, $ungetc_begin;
            }
            $status = scalar(@lines = CORE::readline $hashref->{fh});
            $lines[0] = $ungetc_string . $lines[0] if defined $lines[0] and $lines[0] ne '';
            unshift @lines, @ungetc_lines if @ungetc_lines;
            chomp @lines if $hashref->{autochomp};
        }
        else {
            my $ungetc_string = '';
            if (defined $hashref->{_ungetc_buffer} and $hashref->{_ungetc_buffer} ne '') {
                if (($ungetc_end = index $hashref->{_ungetc_buffer}, $/, 0) > -1) {
                    $ungetc_string = substr $hashref->{_ungetc_buffer}, 0, $ungetc_end + 1;
                }
                else {
                    $ungetc_string = $hashref->{_ungetc_buffer};
                };
            };
            if (defined $ungetc_end and $ungetc_end > -1) {
                # only ungetc buffer
                $status = TRUE;
                $line = $ungetc_string;
            }
            else {
                # also call real readline
                $status = defined($line = CORE::readline $hashref->{fh});
                $line = $ungetc_string . (defined $line ? $line : '');
            };
            chomp $line if $hashref->{autochomp};
        };
    };
    if ($@ or (not $status and $!)) {
        $hashref->{_error} = TRUE;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot readline' );
    };
    assert_true($status) if ASSERT;

    # clean ungetc buffer
    if (defined $hashref->{_ungetc_buffer} and $hashref->{_ungetc_buffer} ne '') {
        if (not $wantarray and $ungetc_end > -1) {
            $hashref->{_ungetc_buffer} = substr $hashref->{_ungetc_buffer}, $ungetc_end + 1;
        }
        else {
            $hashref->{_ungetc_buffer} = '';
        };
    };

    return $wantarray ? @lines : $line;
};


# readline method in scalar context
sub getline {
    ### getline: @_

    my $self = shift;

    my $line;
    eval {
        $line = $self->readline(@_);
    };
    if ($@) {
        my $e = Exception::Fatal->catch;
        if ($e->isa('Exception::Argument')) {
            $e->throw( message => 'Usage: $io->getline()' );
        }
        else {
            $e->throw( message => 'Cannot getline' );
        };
        assert_false("Should throw an exception ealier") if ASSERT;
    };

    return $line;
};


# readline method in array context
sub getlines {
    ### getlines: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Cannot call $io->getlines in a scalar context, use $io->getline'
    ) if not wantarray;

    my @lines;
    eval {
        @lines = $self->readline(@_);
    };
    if ($@) {
        my $e = Exception::Fatal->catch;
        if ($e->isa('Exception::Argument')) {
            $e->throw( message => 'Usage: $io->getlines()' );
        }
        else {
            $e->throw( message => 'Cannot getlines' );
        };
        assert_false("Should throw an exception ealier") if ASSERT;
    };

    return @lines;
};


# Add character to the ungetc buffer
sub ungetc {
    ### ungetc: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->ungetc(ORD)'
    ) if not blessed $self or @_ != 1 or not looks_like_number $_[0];

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my ($ord) = @_;

    $hashref->{_ungetc_buffer} = '' if not defined $hashref->{_ungetc_buffer};
    substr($hashref->{_ungetc_buffer}, 0, 0, chr($ord));

    return $self;
};


# Method wrapper for CORE::sysread
sub sysread {
    ### sysread: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->sysread(BUF, LEN [, OFFSET])'
    ) if not ref $self or @_ < 2 or @_ > 3;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my $bytes;
    eval {
        $bytes = CORE::sysread($hashref->{fh}, $_[0], $_[1], $_[2] || 0);
    };
    if (not defined $bytes) {
        $hashref->{_error} = TRUE;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot sysread' );
    };
    assert_not_null($bytes) if ASSERT;
    return $bytes;
};


# Method wrapper for CORE::syswrite
sub syswrite {
    ### syswrite: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->syswrite(BUF [, LEN [, OFFSET]])'
    ) if not ref $self or @_ < 1 or @_ > 3;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my $bytes;
    eval {
        if (defined($_[1])) {
            $bytes = CORE::syswrite($hashref->{fh}, $_[0], $_[1], $_[2] || 0);
        }
        else {
            $bytes = CORE::syswrite($hashref->{fh}, $_[0]);
        };
    };
    if (not defined $bytes) {
        $hashref->{_error} = TRUE;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot syswrite' );
    };
    assert_not_null($bytes) if ASSERT;
    return $bytes;
};


# Wrapper for CORE::getc. Method / tie hook
sub getc {
    ### getc: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->getc()'
    ) if not blessed $self or @_ > 0;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    undef $!;
    my $char;
    eval {
        if (defined $hashref->{_ungetc_buffer} and $hashref->{_ungetc_buffer} ne '') {
            $char = substr $hashref->{_ungetc_buffer}, 0, 1;
        }
        else {
            $char = CORE::getc $hashref->{fh};
        };
    };
    if ($@ or (not defined $char and $! and $! != Errno::EBADF)) {
        $hashref->{_error} = TRUE;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot getc' );
        assert_false("Should throw an exception ealier") if ASSERT;
    };

    # clean ungetc buffer
    if (defined $hashref->{_ungetc_buffer} and $hashref->{_ungetc_buffer} ne '') {
        $hashref->{_ungetc_buffer} = substr $hashref->{_ungetc_buffer}, 1;
    };

    if (${^TAINT} and not $hashref->{tainted} and defined $char) {
        $char =~ /(.*)/;
        $char = $1;
    };

    return $char;
};


# Method wrapper for CORE::read
sub read {
    ### read: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->read(BUF, LEN [, OFFSET])'
    ) if not ref $self or @_ < 2 or @_ > 3;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my $bytes;
    eval {
        $bytes = CORE::read($hashref->{fh}, $_[0], $_[1], $_[2] || 0);
    };
    if (not defined $bytes) {
        $hashref->{_error} = TRUE;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot read' );
    };
    assert_not_null($bytes) if ASSERT;

    return $bytes;
};


# Opposite to read
sub write {
    ### write: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->write(BUF [, LEN [, OFFSET]])'
    ) if not blessed $self or @_ > 3 or @_ < 1;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my ($buf, $len, $offset) = @_;

    my $bytes;
    my $status;
    eval {
        # clean IO modifiers
        local $\ = '';

        {
            # IO modifiers based on tied fh modifiers
            my $oldfh = select *$self;
            my $var = $|;
            select $hashref->{fh};
            $| = $var;
            select $oldfh;
        };

        my $output = substr($buf, $offset || 0, defined $len ? $len : length($buf));
        $bytes = length($output);
        $status = CORE::print { $hashref->{fh} } $output;
    };
    if (not $status) {
        $hashref->{_error} = TRUE;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot write' );
    };
    assert_true($status) if ASSERT;
    assert_not_null($bytes) if ASSERT;

    return $bytes;
};


# print with EOL
sub say {
    ### say: @_

    my $self = shift;

    eval {
        $self->print(@_, "\n");
    };
    if ($@) {
        my $e = Exception::Fatal->catch;
        if ($e->isa('Exception::Argument')) {
            $e->throw( message => 'Usage: $io->say(ARGS)' );
        }
        else {
            $e->throw( message => 'Cannot say' );
        };
    };

    return $self;
};


# Read whole file
sub slurp {
    ### slurp: @_

    my $self = shift;
    my $class = ref $self || $self || __PACKAGE__;
    my %args = @_;

    Exception::Argument->throw(
        message => "Usage: \$io->slurp() or $class->slurp(file=>FILE)"
    ) if not blessed $self and not defined $args{file} or blessed $self and @_ > 0;

    if (not blessed $self) {
        $self = eval { $self->new( %args ) };
        if ($@) {
            my $e = Exception::Fatal->catch;
            $e->throw( message => 'Cannot slurp' );
        };
        assert_isa(__PACKAGE__, $self) if ASSERT;
    };

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my (@lines, $string);
    my $wantarray = wantarray;

    undef $!;
    eval {
        # scalar or array context
        if ($wantarray) {
            local $hashref->{input_record_separator} = "\n";
            @lines = $self->readline;
        }
        else {
            local $hashref->{input_record_separator} = undef;
            local $hashref->{autochomp} = FALSE;
            $string = $self->readline;
        };
    };
    if ($@) {
        my $e = Exception::Fatal->catch;
        $e->throw( message => 'Cannot slurp' );
    };

    return $wantarray ? @lines : $string;
};


# Wrapper for CORE::truncate
sub truncate {
    ### truncate: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->truncate(LEN)'
    ) if not ref $self or @_ != 1 or not looks_like_number $_[0];

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my $status;
    eval {
        $status = CORE::truncate($hashref->{fh}, $_[0]);
    };
    if ($@ or not $status) {
        $hashref->{_error} = TRUE;
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot truncate' );
    };
    assert_true($status) if ASSERT;

    return $self;
};


# Interface for File::Stat::Moose
sub stat {
    ### stat: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->stat()'
    ) if not ref $self or @_ > 0;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my $stat;
    eval {
        $stat = File::Stat::Moose->new( file => $hashref->{fh} );
    };
    if ($@) {
        my $e = Exception::Fatal->catch;
        $hashref->{_error} = TRUE;
        $e->throw( message => 'Cannot stat' );
    };
    assert_isa('File::Stat::Moose', $stat) if ASSERT;

    return $stat;
};


# Pure Perl implementation
sub error {
    ### error: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->error()'
    ) if not blessed $self or @_ > 0;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    return $hashref->{_error} || ! defined CORE::fileno $hashref->{fh};
};


# Pure Perl implementation
sub clearerr {
    ### clearerr: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->clearerr()'
    ) if not blessed $self or @_ > 0;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    $hashref->{_error} = FALSE;
    return defined CORE::fileno $hashref->{fh};
};


# Uses IO::Handle
sub sync {
    ### sync: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->sync()'
    ) if not blessed $self or @_ > 0;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my $status;
    eval {
        $status = IO::Handle::sync($hashref->{fh});
    };
    if ($@ or not defined $status) {
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $hashref->{_error} = TRUE;
        $e->throw( message => 'Cannot sync' );
    };
    assert_not_null($status) if ASSERT;

    return $self;
};


# Pure Perl implementation
sub flush {
    ### flush: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->flush()'
    ) if not blessed $self or @_ > 0;

    # handle GLOB reference
    my $hashref = ${*$self};

    my $oldfh = select $hashref->{fh};
    my @var = ($|, $\);
    $| = 1;
    $\ = undef;

    my $e;
    my $status;
    eval {
        $status = CORE::print { $hashref->{fh} } '';
    };
    if ($@) {
        $e = Exception::Fatal->catch;
    };

    ($|, $\) = @var;
    select $oldfh;

    if ($e) {
        $hashref->{_error} = TRUE;
        $e->throw( message => 'Cannot flush' );
    };
    assert_null($e) if ASSERT;

    return $self;
};


# flush + print
sub printflush {
    ### printflush: @_

    my $self = shift;

    if (blessed $self) {
        # handle GLOB reference
        assert_equals('GLOB', reftype $self) if ASSERT;
        my $hashref = ${*$self};

        my $oldfh = select *$self;
        my $var = $|;
        $| = 1;

        my $e;
        my $status;
        eval {
            $status = $self->print(@_);
        };
        if ($@) {
            $e = Exception::Fatal->catch;
        };

        $| = $var;
        select $oldfh;

        if ($e) {
            $e->throw( message => 'Cannot printflush' );
        };

        return $status;
    }
    else {
        local $| = 1;
        return CORE::print @_;
    };
};


# Uses IO::Handle
sub blocking {
    ### blocking: @_

    my $self = shift;

    Exception::Argument->throw(
          message => 'Usage: $io->blocking([BOOL])'
    ) if not blessed $self or @_ > 1;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    # constraint checking
    my $old_blocking = $hashref->{blocking};
    eval {
        $self->_set_blocking($_[0]);
    };
    Exception::Fatal->catch->throw(
        message => 'Cannot blocking'
    ) if $@;

    my $status;
    eval {
        if (defined $_[0]) {
            $status = IO::Handle::blocking($hashref->{fh}, $_[0]);
        }
        else {
            $status = IO::Handle::blocking($hashref->{fh});
        };
    };
    if ($@ or not defined $status) {
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $hashref->{_error} = TRUE;
        $hashref->{blocking} = $old_blocking;
        $e->throw( message => 'Cannot blocking' );
    };
    assert_not_null($status) if ASSERT;

    return $status;
};


# Uses IO::Handle
sub untaint {
    ### untaint: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->untaint()'
    ) if not blessed $self or @_ > 0;

    # handle GLOB reference
    assert_equals('GLOB', reftype $self) if ASSERT;
    my $hashref = ${*$self};

    my $status;
    eval {
        $status = IO::Handle::untaint($hashref->{fh});
    };
    if ($@ or not defined $status or $status != 0) {
        my $e = $@ ? Exception::Fatal->catch : Exception::IO->new;
        $hashref->{_error} = TRUE;
        $e->throw( message => 'Cannot untaint' );
    };
    assert_equals(0, $status) if ASSERT;

    $hashref->{tainted} = FALSE;

    return $self;
};


# Clean up on destroy
sub DESTROY {
    ### DESTROY: @_

    my ($self) = @_;
    untie *$self if reftype $self eq 'GLOB';

    return TRUE;
};


# Tie hook by proxy class
sub TIEHANDLE {
    ### TIEHANDLE: @_

    my ($class, $instance) = @_;

    # tie object will be stored in scalar reference of main object
    my $self = \$instance;

    # weaken the real object, otherwise it won't be destroyed automatically
    weaken $instance if ref $instance;

    return bless $self => $class;
};


# Called on untie.
sub UNTIE {
    ### UNTIE: @_
};


# Add missing methods through Class::MOP
#

{
    # Generate accessors for IO modifiers (global and local)
    my %standard_accessors = (
        format_formfeed              => "\014",  # $^L
        format_line_break_characters => ':',     # $:
        input_record_separator       => '/',     # $/
        output_field_separator       => ',',     # $,
        output_record_separator      => '\\',    # $\
    );
    while (my ($func, $var) = each %standard_accessors) {
        no strict 'refs';
        __PACKAGE__->meta->add_method( $func => sub {
            ### $func\: @_
            my $self = shift;
            Exception::Argument->throw(
                message => "Usage: \$io->$func([EXPR]) or " . __PACKAGE__ . "->$func([EXPR])"
            ) if @_ > 1;
            if (ref $self) {
                my $hashref = ${*$self};
                my $prev = $hashref->{$func};
                if (@_ > 0) {
                    $hashref->{$func} = shift;
                };
                return $prev;
            }
            else {
                my $prev = ${*$var};
                if (@_ > 0) {
                    ${*$var} = shift;
                };
                return $prev;
            };
        } );
    };
};

{
    # Generate accessors for IO modifiers (output modifiers which require select)
    my %output_accessors = (
        format_lines_left            => '-',     # $-
        format_lines_per_page        => '=',     # $=
        format_page_number           => '%',     # $%
        input_line_number            => '.',     # $.
        output_autoflush             => '|',     # $|
    );
    while (my ($func, $var) = each %output_accessors) {
        no strict 'refs';
        __PACKAGE__->meta->add_method( $func => sub {
            ### $func\: @_
            my $self = shift;
            Exception::Argument->throw(
                message => "Usage: \$io->$func([EXPR]) or " . __PACKAGE__ . "->$func([EXPR])"
            ) if @_ > 1;
            if (ref $self) {
                my $oldfh = select *$self;
                my $prev = ${*$var};
                if (@_ > 0) {
                    ${*$var} = shift;
                };
                select $oldfh;
                return $prev;
            }
            else {
                my $prev = ${*$var};
                if (@_ > 0) {
                    ${*$var} = shift;
                };
                return $prev;
            };
        } );
    };
};

{
    # Generate accessors for IO modifiers (qualified format name)
    my %format_name_accessors = (
        format_name      => '~',  # $~
        format_top_name  => '^',  # $^
    );
    while (my ($func, $var) = each %format_name_accessors) {
        no strict 'refs';
        __PACKAGE__->meta->add_method( $func => sub {
            ### $func\: @_
            my $self = shift;
            Exception::Argument->throw(
                message => "Usage: \$io->$func([EXPR]) or " . __PACKAGE__ . "->$func([EXPR])"
            ) if @_ > 1;
            if (ref $self) {
                my $oldfh = select *$self;
                my $prev = ${*$var};
                if (@_ > 0) {
                    my $value = shift;
                    ${*$var} = defined $value ? qualify($value, caller) : undef;
                };
                select $oldfh;
                return $prev;
            }
            else {
                my $prev = ${*$var};
                my $value = shift;
                ${*$var} = defined $value ? qualify($value, caller) : undef;
                return $prev;
            };
        } );
    };
};

# Alias
__PACKAGE__->meta->alias_method('autoflush' => \&output_autoflush);

# Aliasing tie hooks to real functions
foreach my $func (qw< close eof fileno print printf readline getc >) {
    __PACKAGE__->meta->alias_method(
        uc($func) => __PACKAGE__->meta->get_method($func)->body
    );
};
foreach my $func (qw< read write >) {
    __PACKAGE__->meta->alias_method(
        uc($func) => __PACKAGE__->meta->get_method("sys$func")->body
    );
};


# Make immutable finally
__PACKAGE__->meta->make_immutable;


1;


__END__

=begin umlwiki

= Class Diagram =

[                                 IO::Moose::Handle
 --------------------------------------------------------------------------------------
 +file : Num|FileHandle|OpenHandle {rw, weak}
 <<obsoleted>> +fd : Num|FileHandle|OpenHandle
 +mode : CanonOpenModeStr = "<" {rw}
 +fh : GlobRef {ro}
 +autochomp : Bool = false {rw}
 +untaint : Bool = ${^TAINT} {ro}
 +blocking : Bool = true {ro}
 +format_formfeed : Str {rw}
 +format_line_break_characters : Str {rw}
 +input_record_separator : Str {rw}
 +output_field_separator : Str {rw}
 +output_record_separator : Str {rw}
 #_error : Bool
 #_ungetc_buffer : Str
 --------------------------------------------------------------------------------------
 <<create>> +new( args : Hash ) : Self
 <<create>> +new_from_fd( fd : Num|FileHandle|OpenHandle, mode : CanonOpenModeStr = ">" ) : Self
 <<create>> +slurp( file : Num|FileHandle|OpenHandle, args : Hash ) : Str|Array
 +fdopen( fd : Num|FileHandle|OpenHandle, mode : CanonOpenModeStr = ">" ) : Self
 +close() : Self
 +eof() : Bool
 +opened() : Bool
 +fileno() : Int
 +print( args : Array ) : Self
 +printf( fmt : Str = "", args : Array = () ) : Self
 +readline() : Str|Array
 +getline() : Str
 +getlines() : Array
 +ungetc( ord : Int ) : Self
 +sysread( out buf, len : Int, offset : Int = 0 ) : Int
 +syswrite( buf : Str, len : Int, offset : Int = 0 ) : Int
 +getc() : Char
 +read( out buf, len : Int, offset : Int = 0 ) : Int
 +write( buf : Str, len : Int, offset : Int = 0 ) : Int
 +format_write( format_name : Str ) : Self
 +say( args : Array ) : Self
 +slurp() : Str|Array
 +truncate( len : Int ) : Self
 +stat() : File::Stat::Moose
 +error() : Bool
 +clearerr() : Bool
 +sync() : Self
 +flush() : Self
 +printflush( args : Array ) : Self
 +blocking() : Bool
 +blocking( bool : Bool ) : Bool
 +untaint() : Self {rw}
 +clear_input_record_separator()
 +clear_output_field_separator()
 +clear_output_record_separator()
 +clear_format_formfeed()
 +clear_format_line_break_characters()
 +format_lines_left() : Str
 +format_lines_left( value : Str ) : Str
 +format_lines_per_page() : Str
 +format_lines_per_page( value : Str ) : Str
 +format_page_number() : Str
 +format_page_number( value : Str ) : Str
 +input_line_number() : Str
 +input_line_number( value : Str ) : Str
 +autoflush() : Str
 +autoflush( value : Str ) : Str
 +output_autoflush() : Str
 +output_autoflush( value : Str ) : Str
 +format_name() : Str
 +format_name( value : Str ) : Str
 +format_top_name() : Str
 +format_top_name( value : Str ) : Str
 #_open_file() : Bool
                                                                            ]

[IO::Moose::Handle] ---> <<use>> [File::Stat::Moose]

[IO::Moose::Handle] ---> <<exception>> [Exception::Fatal] [Exception::IO]

=end umlwiki

=head1 IMPORTS

=over

=item use IO::Moose::Handle '$STDIN', '$STDOUT', '$STDERR';

=item use IO::Moose::Handle ':std';

=item use IO::Moose::Handle ':all';

Opens standard handle and imports it into caller's namespace.  The handles
won't be created until explicit import.

  use IO::Moose::Handle ':std';
  print $STDOUT->autoflush(1);
  print $STDIN->slurp;

=back

=head1 BASE CLASSES

=over 2

=item *

L<IO::Handle>

=item *

L<MooseX::GlobRef::Object>

=back

=head1 EXCEPTIONS

=over

=item Exception::Argument

Thrown whether method is called with wrong argument.

=item Exception::Fatal

Thrown whether fatal error is occurred by core function.

=back

=head1 ATTRIBUTES

=over

=item file : Num|FileHandle|OpenHandle {rw}

File (file descriptor number, file handle or IO object) as a parameter for new
object.

=item mode = CanonOpenModeStr = "<" {rw}

File mode as a parameter for new object. Can be Perl-style (C<E<lt>>,
C<E<gt>>, C<E<gt>E<gt>>, etc.) or C-style (C<r>, C<w>, C<a>, etc.)

=item fh : GlobRef {rw}

File handle used for internal IO operations.

=item autochomp : Bool = false {rw}

If is true value the input will be auto chomped.

=item tainted : Bool = ${^TAINT} {rw}

If is false value and tainted mode is enabled the C<untaint> method will be
called after C<fdopen>.

=item blocking : Bool = true {rw}

If is false value the non-blocking IO will be turned on.

=item format_formfeed : Str {rw, var="$^L"}

=item format_line_break_characters : Str {rw, var="$:"}

=item input_record_separator : Str {rw, var="$/"}

=item output_field_separator : Str {rw, var="$,"}

=item output_record_separator : Str {rw, var="$\"}

These are attributes assigned with Perl's built-in variables. See L<perlvar>
for complete descriptions.  The fields have accessors available as per file
handle basis if called as C<$io-E<gt>accessor> or as global setting if called
as C<IO::Moose::Handle-E<gt>accessor>.

=back

=head1 CONSTRUCTORS

=over

=item new( I<args> : Hash ) : Self

Creates the C<IO::Moose::Handle> object and calls C<fdopen> method if the
I<file> parameter is defined.

  $io = IO::Moose::Handle->new( file => \*STDIN, mode => "r" );

The object can be created with uninitialized file handle.

  $in = IO::Moose::Handle->new;
  $in->fdopen(\*STDIN);

=item new_from_fd( I<fd> : Num|FileHandle|OpenHandle, I<mode> : CanonOpenModeStr = ">" ) : Self

Creates the C<IO::Moose::Handle> object and immediately opens the file handle
based on arguments.

  $out = IO::Moose::Handle->new_from_fd( \*STDOUT, "w" );

=item slurp( I<file> : Num|FileHandle|OpenHandle, I<args> : Hash ) : Str|Array

Creates the C<IO::Moose::Handle> object and returns its content as a scalar in
scalar context or as an array in array context.

  open $f, "/etc/passwd";
  $passwd_file = IO::Moose::Handle->slurp($f);

Additional I<args> are passed to C<IO::Moose::Handle> constructor.

=back

=head1 METHODS

=over

=item fdopen( I<fd> : Num|FileHandle|OpenHandle, I<mode> : CanonOpenModeStr = ">" ) : Self

Opens the file handle based on existing file handle, IO object or file
descriptor number.

  $out = IO::Moose::Handle->new;
  $out->fdopen(\*STDOUT, "w");

  $dup = IO::Moose::Handle->new;
  $dup->fdopen($out, "a");

  $stdin = IO::Moose::Handle->new;
  $stdin->fdopen(0, "r");

=item close(I<>) : Self

=item eof(I<>) : Bool

=item fileno(I<>) : Int

=item print( I<args> : Array ) : Self

=item printf( I<fmt> : Str = "", I<args> : Array = (I<>) ) : Self

=item readline(I<>) : Str|Array

=item sysread( out I<buf>, I<len> : Int, I<offset> : Int = 0 ) : Int

=item syswrite( I<buf> : Str, I<len> : Int, I<offset> : Int = 0 ) : Int

=item getc(I<>) : Char

=item read( out I<buf>, I<len> : Int, I<offset> : Int = 0 ) : Int

=item truncate( I<len> : Int ) : Self

These are front ends for corresponding built-in functions.  Most of them
throws exception on failure which can be caught with try/catch:

  use Exception::Base;
  eval {
    open $f, "/etc/hostname";
    $io = IO::Moose::Handle->new( file => $f, mode => "r" );
    $c = $io->getc;
  };
  if ($@) {
    my $e = Exception::Base->catch) {
    warn "problem with /etc/hostname file: $e";
  };

The C<fdopen>, C<close>, C<print>, C<printf> and C<truncate> methods returns
this object.

=item opened(I<>) : Bool

Returns true value if the object has opened file handle, false otherwise.

=item write( I<buf> : Str, I<len> : Int, I<offset> : Int = 0 ) : Int

The opposite of B<read>. The wrapper for the perl L<perlfunc/write> function is called
C<format_write>.

=item format_write( I<format_name> : Str ) : Self

The wrapper for perl L<perlfunc/format> function.

=item getline(I<>) : Str

The C<readline> method which is called always in scalar context.

  $io = IO::Moose::Handle->new( file=>\*STDIN, mode=>"r" );
  push @a, $io->getline;  # reads only one line

=item getlines(I<>) : Array

The C<readline> method which is called always in array context.

  $io = IO::Moose::Handle->new( file => \*STDIN, mode => "r" );
  print scalar $io->getlines;  # error: can't call in scalar context.

=item ungetc( I<ord> : Int ) : Self

Pushes a character with the given ordinal value back onto the given handle's
input stream.  In fact this is emulated in pure-Perl code and can't be mixed
with non IO::Moose::Handle objects.

  $io = IO::Moose::Handle->new( file => \*STDIN, mode => "r" );
  $io->ungetc(ord('A'));
  print $io->getc;  # prints A

=item say( I<args> : Array ) : Self

The C<print> method with EOL character at the end.

  $io = IO::Moose::Handle->new( file => \*STDOUT, mode => "w" );
  $io->say("Hello!");

=item slurp(I<>) : Str|Array

Reads whole file and returns its content as a scalar in scalar context or as
an array in array context (like C<getlines> method).

  open $f, "/etc/passwd";

  $io1 = IO::Moose::Handle->new( file => $f, mode => "r" );
  $passwd_file = $io1->slurp;

  $io2 = IO::Moose::Handle->new( file => $f, mode => "r" );
  $io2->autochomp(1);
  @passwd_lines = $io2->slurp;

=item stat(I<>) : File::Stat::Moose

Returns C<File::Stat::Moose> object which represents status of file pointed by
current file handle.

  open $f, "/etc/passwd";
  $io = IO::Moose::Handle->new( file => $f, mode => "r" );
  $st = $io->stat;
  print $st->size;  # size of /etc/passwd file

=item error(I<>) : Bool

Returns true value if the file handle has experienced any errors since it was
opened or since the last call to C<clearerr>, or if the handle is invalid.

It is recommended to use exceptions mechanism to handle errors.

=item clearerr(I<>) : Bool

Clear the given handle's error indicator.  Returns true value if the file
handle is valid or false value otherwise.

=item sync(I<>) : Self

Synchronizes a file's in-memory state with that on the physical medium.  It
operates on file descriptor and it is low-level operation.  Returns this
object on success or throws an exception.

=item flush(I<>) : Self

Flushes any buffered data at the perlio API level.  Returns self object on
success or throws an exception.

=item printflush( I<args> : Array ) : Self

Turns on autoflush, print I<args> and then restores the autoflush status.
Returns self object on success or throws an exception.

=item blocking(I<>) : Bool

=item blocking( I<bool> : Bool ) : Bool

If called with an argument blocking will turn on non-blocking IO if I<bool> is
false, and turn it off if I<bool> is true.  C<blocking> will return the value
of the previous setting, or the current setting if I<bool> is not given.

=item untaint(I<>) : Self {rw}

Marks the object as taint-clean, and as such data read from it will also be
considered taint-clean.  It has meaning only if Perl is running in tainted
mode (C<-T>).

=item format_lines_left(I<>) : Str {var="$-"}

=item format_lines_left( I<value> : Str ) : Str {var="$-"}

=item format_lines_per_page(I<>) : Str {var="$="}

=item format_lines_per_page( I<value> : Str ) : Str {var="$="}

=item format_page_number(I<>) : Str {var="$%"}

=item format_page_number( I<value> : Str ) : Str {var="$%"}

=item input_line_number(I<>) : Str {var="$."}

=item input_line_number( I<value> : Str ) : Str {var="$."}

=item output_autoflush(I<>) : Str {var="$|"}

=item output_autoflush( I<value> : Str ) : Str {var="$|"}

=item autoflush(I<>) : Str {var="$|"}

=item autoflush( I<value> : Str ) : Str {var="$|"}

=item format_name(I<>) : Str {var="$~"}

=item format_name( I<value> : Str ) : Str {var="$~"}

=item format_top_name(I<>) : Str {var="$^"}

=item format_top_name( I<value> : Str ) : Str {var="$^"}

These are accessors assigned with Perl's built-in variables. See L<perlvar>
for complete descriptions.

=back

=head1 INTERNALS

This module uses L<MooseX::GlobRef::Object> and stores the object's attributes
in glob reference.  They can be accessed with C<${*$self}-E<gt>{key}>
expression.

There are two handles used for IO operations: the original handle used for
real IO operations and tied handle which hooks IO functions interface.

The OO-style uses original handle stored in I<fh> field.

  # Usage:
  $io->print("OO style");

  # Implementation:
  package IO::Moose::Handle;
  sub print {
      $self = shift;
      $hashref = ${*$self};
      CORE::print { $hashref->{fh} } @_
  }

The IO functions-style uses object reference which is dereferenced as a
handle tied to proxy object which operates on original handle.

  # Usage:
  print $io "IO functions style";

  # Implementation:
  package IO::Moose::Handle;
  \*PRINT = &IO::Moose::Handle::print;
  sub print {
      $self = shift;
      $self = $$self if blessed $self and reftype $self eq 'REF';
      $hashref = ${*$self};
      CORE::print { $hashref->{fh} } @_
  }

=head1 SEE ALSO

L<IO::Handle>, L<MooseX::GlobRef::Object>, L<Moose>.

=head1 BUGS

The API is not stable yet and can be changed in future.

=head1 AUTHOR

Piotr Roszatycki E<lt>dexter@debian.orgE<gt>

=head1 LICENSE

Copyright 2007, 2008, 2009 by Piotr Roszatycki E<lt>dexter@debian.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
