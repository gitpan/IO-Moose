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

our $VERSION = '0.07';

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
use English '-no_match_vars';

use Scalar::Util 'blessed', 'reftype', 'weaken', 'looks_like_number';
use Symbol       'qualify', 'qualify_to_ref';

# stat method
use File::Stat::Moose;


# EBADF error code.
use Errno;


# Assertions
use Test::Assert ':assert';

# Debugging flag
use if $ENV{PERL_DEBUG_IO_MOOSE_HANDLE}, 'Smart::Comments';


# Standard handles
our ($STDIN, $STDOUT, $STDERR);


# File to open (descriptor number or existing file handle)
has 'file' => (
    is        => 'ro',
    isa       => 'Num | FileHandle | OpenHandle',
    reader    => 'file',
    writer    => '_set_file',
    clearer   => '_clear_file',
    predicate => 'has_file',
);

# File mode
has 'mode' => (
    is        => 'ro',
    isa       => 'CanonOpenModeStr',
    lazy      => TRUE,
    default   => '<',
    coerce    => TRUE,
    reader    => 'mode',
    writer    => '_set_mode',
    clearer   => '_clear_mode',
    predicate => 'has_mode',
);

# File handle
has 'fh' => (
    is        => 'ro',
    isa       => 'GlobRef | FileHandle | OpenHandle',
    reader    => 'fh',
    writer    => '_set_fh',
);

# Flag that input should be automaticaly chomp-ed
has 'autochomp' => (
    is        => 'rw',
    isa       => 'Bool',
    default   => FALSE,
);

# Flag that non-blocking IO should be turned on
has 'blocking' => (
    is        => 'rw',
    isa       => 'Bool',
    default   => TRUE,
    reader    => '_get_blocking',
    writer    => '_set_blocking',
);

# Flag that input is tainted.
has 'tainted' => (
    is        => 'ro',
    isa       => 'Bool',
    default   => !! ${^TAINT},
    reader    => 'tainted',
    writer    => '_set_tainted',
);

# Flag that file handle is a copy of file argument
has 'copyfh' => (
    is        => 'ro',
    isa       => 'Bool',
    default   => FALSE,
);

# Tie self object
has 'tied' => (
    is        => 'ro',
    isa       => 'Bool',
    default   => TRUE,
);

# Use accessors rather than direct hash
has 'strict_accessors' => (
    is        => 'rw',
    isa       => 'Bool',
    default   => FALSE,
);

# Flag if error was occured in IO operation
has '_error' => (
    isa       => 'Bool',
    default   => FALSE,
    reader    => '_get_error',
    writer    => '_set_error',
);

# Buffer for ungetc
has '_ungetc_buffer' => (
    isa       => 'Str',
    default   => '',
    reader    => '_get_ungetc_buffer',
    writer    => '_set_ungetc_buffer',
    predicate => '_has_ungetc_buffer',
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

        has "$attr" => (
            is        => 'rw',
            has       => 'Str',
            reader    => "_get_$attr",
            writer    => "_set_$attr",
            clearer   => "clear_$attr",
            predicate => "has_$attr",
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
    ### IO::Moose::Handle::import: @_

    my ($pkg, @args) = @_;

    my %setup = ref $args[0] eq 'HASH' ? %{ shift @args } : ();

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

    my $caller = $setup{into} || caller($setup{into_level} || 0);

    foreach my $var (keys %vars) {
        if ($var eq 'STDIN') {
            $STDIN  = __PACKAGE__->new( file => \*STDIN,  mode => '<', copyfh => 1 ) if not defined $STDIN;
            *{qualify_to_ref("${caller}::STDIN")}  = \$STDIN;
        }
        elsif ($var eq 'STDOUT') {
            $STDOUT = __PACKAGE__->new( file => \*STDOUT, mode => '>', copyfh => 1 ) if not defined $STDOUT;
            *{qualify_to_ref("${caller}::STDOUT")} = \$STDOUT;
        }
        elsif ($var eq 'STDERR') {
            $STDERR = __PACKAGE__->new( file => \*STDERR, mode => '>', copyfh => 1 ) if not defined $STDERR;
            *{qualify_to_ref("${caller}::STDERR")} = \$STDERR;
        }
        else {
            assert_false("Unknown variable \$$var") if ASSERT;
        };
    };

    return TRUE;
};


# Object initialization
sub BUILD {
    ### IO::Moose::Handle::BUILD: @_

    my ($self, $params) = @_;

    $self->_init_fh;

    return $self;
};


# Initialize file handle
sub _init_fh {
    ### IO::Moose::Handle::BUILD: @_

    my ($self) = @_;

    assert_equals('GLOB', reftype $self) if ASSERT;

    my $fd = $self->file;

    # initialize anonymous handle
    if ($self->copyfh) {
        # Copy file handle
        if (blessed $fd and $fd->isa(__PACKAGE__)) {
            if ($self->strict_accessors) {
                $self->_set_fh( $fd->fh );
            }
            else {
                ${*$self}->{fh} = $fd->fh;
            };
        }
        elsif ((ref $fd || '') eq 'GLOB' or (reftype $fd || '') eq 'GLOB') {
            if ($self->strict_accessors) {
                $self->_set_fh( $fd );
            }
            else {
                ${*$self}->{fh} = $fd;
            };
        }
        else {
            Exception::Argument->throw(
                message => 'Cannot copy file handle from bad file argument'
            );
        };
    }
    else {
        # Create the new handle
        select select my $fh;
        if ($self->strict_accessors) {
            $self->_set_fh( $fh );
        }
        else {
            ${*$self}->{fh} = $fh;
        };
    };

    my $is_opened;

    if (not $self->copyfh) {
        $is_opened = eval { $self->_open_file };
        if ($EVAL_ERROR) {
            my $e = Exception::Fatal->catch;
            $e->throw( message => 'Cannot new' );
        };
        assert_not_null($is_opened) if ASSERT;
    };

    $self->_tie if $self->tied and not $is_opened;

    return $self;
};


# Open file if is defined
sub _open_file {
    #### IO::Moose::Handle::_open_file: @_

    my ($self) = @_;

    if ($self->has_file) {
        # call fdopen if file is defined; it also ties handle
        $self->fdopen( $self->file, $self->mode );
        return TRUE;
    };

    return FALSE;
};


# Tie self object
sub _tie {
    ### IO::Moose::Handle::_tie: @_

    my ($self) = @_;

    assert_equals('GLOB', reftype $self) if ASSERT;
    assert_true($self->tied) if ASSERT;

    tie *$self, blessed $self, $self;

    assert_not_null(tied *$self) if ASSERT;

    return $self;
};


# Untie self object
sub _untie {
    ### IO::Moose::Handle::_untie: @_

    my ($self) = @_;

    assert_equals('GLOB', reftype $self) if ASSERT;
    assert_true($self->tied) if ASSERT;

    untie *$self;

    return $self;
};


# Clone standard handler for tied handle
sub _open_tied {
    ### IO::Moose::Handle::_open_tied: @_

    my ($self) = @_;

    assert_equals('GLOB', reftype $self) if ASSERT;
    assert_true($self->tied) if ASSERT;
    assert_not_null($self->mode) if ASSERT;

    my $mode = $self->mode;

    # clone standard handler for tied handler
    $self->_untie;
    eval {
        CORE::open *$self, "$mode&", $self->fh;
    };
    if ($EVAL_ERROR) {
        Exception::Fatal->throw( message => 'Cannot fdopen' );
    };
    $self->_tie;

    return $self;
};


# Close tied handle
sub _close_tied {
    ### IO::Moose::Handle::_close_tied: @_

    my ($self) = @_;

    assert_equals('GLOB', reftype $self) if ASSERT;
    assert_true($self->tied) if ASSERT;

    $self->_untie;

    CORE::close *$self;

    $self->_tie;

    return $self;
};


# Constructor
sub new_from_fd {
    ### IO::Moose::Handle::new_from_fd: @_

    my $class = shift;
    Exception::Argument->throw(
        message => 'Usage: ' . __PACKAGE__ . '->new_from_fd(FD, [MODE])',
    ) if @_ < 1 or @_ > 2;

    my ($fd, $mode) = @_;

    my $io = eval {
        $class->new(
            file => $fd,
            defined $mode ? (mode => $mode) : ()
        )
    };
    if ($EVAL_ERROR) {
        my $e = Exception::Fatal->catch;
        $e->throw( message => 'Cannot new_from_fd' );
    };
    assert_isa(__PACKAGE__, $io) if ASSERT;

    return $io;
};


# fdopen method
sub fdopen {
    ### IO::Moose::Handle::fdopen: @_

    my $self = shift;
    Exception::Argument->throw(
        message => 'Usage: $io->fdopen(FD, [MODE])',
    ) if not blessed $self or @_ < 1 or @_ > 2 or not defined $_[0];

    my ($fd, $mode) = @_;

    my $status;
    eval {
        # check constraints and fill attributes
        $fd = $self->_set_file($fd);
        $mode = defined $mode ? $self->_set_mode($mode) : do { $self->_clear_mode; $self->mode };

        assert_not_null($fd) if ASSERT;
        assert_not_null($mode) if ASSERT;

        if (blessed $fd and $fd->isa(__PACKAGE__)) {
            #### fdopen: "open(fh, $mode&, \$fd->fh)"
            $status = CORE::open $self->fh, "$mode&", $fd->fh;
        }
        elsif ((ref $fd || '') eq 'GLOB') {
            #### fdopen: "open(fh, $mode&, \\$$fd)"
            $status = CORE::open $self->fh, "$mode&", $fd;
        }
        elsif ((reftype $fd || '') eq 'GLOB') {
            #### fdopen: "open(fh, $mode&, *$fd)"
            $status = CORE::open $self->fh, "$mode&", *$fd;
        }
        elsif ($fd =~ /^\d+$/) {
            #### fdopen: "open(fh, $mode&=$fd)"
            $status = CORE::open $self->fh, "$mode&=$fd";
        }
        else {
            # should be caught by constraint
            assert_false("Bad file descriptor");
        };
    };
    if (not $status) {
        $self->_set_error(TRUE);
        my $e = $EVAL_ERROR ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot fdopen' );
    };
    assert_true($status) if ASSERT;

    $self->_set_error(FALSE);

    $self->_open_tied if $self->tied;

    if (${^TAINT} and not $self->tainted) {
        $self->untaint;
    };

    if (${^TAINT} and not $self->_get_blocking) {
        $self->blocking(FALSE);
    };

    return $self;
};


# Standard close IO method / tie hook
sub close {
    ### IO::Moose::Handle::close: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->close()'
    ) if not blessed $self or @_ > 0;

    if (not CORE::close $self->fh) {
        $self->_set_error(TRUE);
        Exception::IO->throw( message => 'Cannot close' );
    };

    $self->_set_error(FALSE);

    # clear file and mode attributes
    $self->_clear_file;
    $self->_clear_mode;

    $self->_close_tied if $self->tied;

    return $self;
};


# Standard eof IO method / tie hook
sub eof {
    ### IO::Moose::Handle::eof: @_

    my $self = shift;

    # derefer tie hook
    if (blessed $self and reftype $self eq 'REF') {
        my $param = shift;
        $self = $$self;
    };

    Exception::Argument->throw(
        message => 'Usage: $io->eof()'
    ) if not blessed $self or @_ > 0;

    my $status;
    eval {
        $status = CORE::eof $self->fh;
    };
    if ($EVAL_ERROR) {
        my $e = Exception::Fatal->catch;
        $e->throw( message => 'Cannot eof' );
    };
    return $status;
};


# Standard fileno IO method / tie hook
sub fileno {
    ### IO::Moose::Handle::fileno: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->fileno()'
    ) if not blessed $self or @_ > 0;

    my $fileno = CORE::fileno $self->fh;
    if (not defined $fileno) {
        local $! = Errno::EBADF;
        Exception::IO->throw( message => 'Cannot fileno' );
    };

    return $fileno;
};


# opened IO method
sub opened {
    ### IO::Moose::Handle::opened: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->opened()'
    ) if not blessed $self or @_ > 0;

    my $fileno;
    eval {
        $fileno = CORE::fileno $self->fh;
    };

    return defined $fileno;
};


# Standard print IO method / tie hook
sub print {
    ### IO::Moose::Handle::print: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->print(ARGS)'
    ) if not blessed $self;

    my $status;
    eval {
        # IO modifiers based on object's attributes
        local $OUTPUT_FIELD_SEPARATOR
            = $self->has_output_field_separator
            ? $self->_get_output_field_separator
            : $OUTPUT_FIELD_SEPARATOR;
        local $OUTPUT_RECORD_SEPARATOR
            = $self->has_output_record_separator
            ? $self->_get_output_record_separator
            : $OUTPUT_RECORD_SEPARATOR;

        {
            # IO modifiers based on tied fh modifiers
            my $oldfh = select *$self;
            my $var = $|;
            select $self->fh;
            $| = $var;
            select $oldfh;
        };

        $status = CORE::print { $self->fh } @_;
    };
    if (not $status) {
        $self->_set_error(TRUE);
        my $e = $EVAL_ERROR ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot print' );
    };
    assert_true($status) if ASSERT;

    return $self;
};


# Standard printf IO method / tie hook
sub printf {
    ### IO::Moose::Handle::printf: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->printf(FMT, [ARGS])'
    ) if not ref $self;

    {
        # IO modifiers based on tied fh modifiers
        my $oldfh = select *$self;
        my $var = $|;
        select $self->fh;
        $| = $var;
        select $oldfh;
    };

    my $status;
    eval {
        $status = CORE::printf { $self->fh } @_;
    };
    if (not $status) {
        $self->_set_error(TRUE);
        my $e = $EVAL_ERROR ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot printf' );
    };
    assert_true($status) if ASSERT;

    return $self;
};


# Wrapper for CORE::write
sub format_write {
    ### IO::Moose::Handle::format_write: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->format_write([FORMAT_NAME])'
    ) if not blessed $self or @_ > 1;

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
        my @vars_obj = ($FORMAT_LINE_BREAK_CHARACTERS, $FORMAT_FORMFEED);

        # Global variables without local scope
        $FORMAT_LINE_BREAK_CHARACTERS
            = $self->has_format_line_break_characters
            ? $self->_get_format_line_break_characters
            : $FORMAT_LINE_BREAK_CHARACTERS;
        $FORMAT_FORMFEED
            = $self->has_format_formfeed
            ? $self->_get_format_formfeed
            : $FORMAT_FORMFEED;

        # IO modifiers based on tied fh modifiers
        {
            my $oldfh = select *$self;
            my @vars_tied = (
                $OUTPUT_AUTOFLUSH, $FORMAT_PAGE_NUMBER,
                $FORMAT_LINES_PER_PAGE, $FORMAT_LINES_LEFT, $FORMAT_NAME,
                $FORMAT_TOP_NAME, $INPUT_LINE_NUMBER,
            );
            select $self->fh;
            (
                $OUTPUT_AUTOFLUSH, $FORMAT_PAGE_NUMBER,
                $FORMAT_LINES_PER_PAGE, $FORMAT_LINES_LEFT, $FORMAT_NAME,
                $FORMAT_TOP_NAME, $INPUT_LINE_NUMBER,
            ) = @vars_tied;
            select $oldfh;
        };

        eval {
            $status = CORE::write $self->fh;
        };
        $e = Exception::Fatal->catch;

        # Restore previous settings
        ($FORMAT_LINE_BREAK_CHARACTERS, $FORMAT_FORMFEED) = @vars_obj;
        if (defined $fmt) {
            $self->format_name($oldfmt);
            $self->format_top_name($oldtopfmt);
        };
    };
    if (not $status) {
        $self->_set_error(TRUE);
        $e = Exception::IO->new unless $e;
        $e->throw( message => 'Cannot format_write' );
    };
    assert_true($status) if ASSERT;

    return $self;
};


# Wrapper for CORE::readline. Method / tie hook
sub readline {
    ### IO::Moose::Handle::readline: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->readline()'
    ) if not blessed $self or @_ > 0;

    my ($status, @lines, $line, $ungetc_begin, $ungetc_end);
    my $wantarray = wantarray;

    undef $!;
    eval {
        # IO modifiers based on object's attributes
        local $INPUT_RECORD_SEPARATOR
            = $self->has_input_record_separator
            ? $self->_get_input_record_separator
            : $INPUT_RECORD_SEPARATOR;

        # scalar or array context
        if ($wantarray) {
            my @ungetc_lines;
            my $ungetc_string = '';
            if (defined $self->_get_ungetc_buffer and $self->_get_ungetc_buffer ne '') {
                # iterate for splitted ungetc buffer
                $ungetc_begin = 0;
                while (($ungetc_end = index $self->_get_ungetc_buffer, $/, $ungetc_begin) > -1) {
                    push @ungetc_lines, substr $self->_get_ungetc_buffer, $ungetc_begin, $ungetc_end - $ungetc_begin + 1;
                    $ungetc_begin = $ungetc_end + 1;
                }
                # last line of ungetc buffer is also the first line of real readline output
                $ungetc_string = substr $self->_get_ungetc_buffer, $ungetc_begin;
            }
            $status = scalar(@lines = CORE::readline $self->fh);
            $lines[0] = $ungetc_string . $lines[0] if defined $lines[0] and $lines[0] ne '';
            unshift @lines, @ungetc_lines if @ungetc_lines;
            chomp @lines if $self->autochomp;
        }
        else {
            my $ungetc_string = '';
            if (defined $self->_get_ungetc_buffer and $self->_get_ungetc_buffer ne '') {
                if (($ungetc_end = index $self->_get_ungetc_buffer, $/, 0) > -1) {
                    $ungetc_string = substr $self->_get_ungetc_buffer, 0, $ungetc_end + 1;
                }
                else {
                    $ungetc_string = $self->_get_ungetc_buffer;
                };
            };
            if (defined $ungetc_end and $ungetc_end > -1) {
                # only ungetc buffer
                $status = TRUE;
                $line = $ungetc_string;
            }
            else {
                # also call real readline
                $status = defined($line = CORE::readline $self->fh);
                $line = $ungetc_string . (defined $line ? $line : '');
            };
            chomp $line if $self->autochomp;
        };
    };
    if ($EVAL_ERROR or (not $status and $!)) {
        $self->_set_error(TRUE);
        my $e = $EVAL_ERROR ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot readline' );
    };
    assert_true($status) if ASSERT;

    # clean ungetc buffer
    if (defined $self->_get_ungetc_buffer and $self->_get_ungetc_buffer ne '') {
        if (not $wantarray and $ungetc_end > -1) {
            $self->_set_ungetc_buffer( substr $self->_get_ungetc_buffer, $ungetc_end + 1 );
        }
        else {
            $self->_set_ungetc_buffer( "" );
        };
    };

    return $wantarray ? @lines : $line;
};


# readline method in scalar context
sub getline {
    ### IO::Moose::Handle::getline: @_

    my $self = shift;

    my $line;
    eval {
        $line = $self->readline(@_);
    };
    if ($EVAL_ERROR) {
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
    ### IO::Moose::Handle::getlines: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Cannot call $io->getlines in a scalar context, use $io->getline'
    ) if not wantarray;

    my @lines;
    eval {
        @lines = $self->readline(@_);
    };
    if ($EVAL_ERROR) {
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
    ### IO::Moose::Handle::ungetc: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->ungetc(ORD)'
    ) if not blessed $self or @_ != 1 or not looks_like_number $_[0];

    my ($ord) = @_;

    $self->_set_ungetc_buffer('') if not $self->_has_ungetc_buffer;
    $self->_set_ungetc_buffer( chr($ord) . $self->_get_ungetc_buffer );

    return $self;
};


# Method wrapper for CORE::sysread
sub sysread {
    ### IO::Moose::Handle::sysread: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->sysread(BUF, LEN [, OFFSET])'
    ) if not ref $self or @_ < 2 or @_ > 3;

    my $bytes;
    eval {
        $bytes = CORE::sysread($self->fh, $_[0], $_[1], $_[2] || 0);
    };
    if (not defined $bytes) {
        $self->_set_error(TRUE);
        my $e = $EVAL_ERROR ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot sysread' );
    };
    assert_not_null($bytes) if ASSERT;
    return $bytes;
};


# Method wrapper for CORE::syswrite
sub syswrite {
    ### IO::Moose::Handle::syswrite: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->syswrite(BUF [, LEN [, OFFSET]])'
    ) if not ref $self or @_ < 1 or @_ > 3;

    my $bytes;
    eval {
        if (defined($_[1])) {
            $bytes = CORE::syswrite($self->fh, $_[0], $_[1], $_[2] || 0);
        }
        else {
            $bytes = CORE::syswrite($self->fh, $_[0]);
        };
    };
    if (not defined $bytes) {
        $self->_set_error(TRUE);
        my $e = $EVAL_ERROR ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot syswrite' );
    };
    assert_not_null($bytes) if ASSERT;
    return $bytes;
};


# Wrapper for CORE::getc. Method / tie hook
sub getc {
    ### IO::Moose::Handle::getc: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->getc()'
    ) if not blessed $self or @_ > 0;

    undef $!;
    my $char;
    eval {
        if ($self->_has_ungetc_buffer and $self->_get_ungetc_buffer ne '') {
            $char = substr $self->_get_ungetc_buffer, 0, 1;
        }
        else {
            $char = CORE::getc $self->fh;
        };
    };
    if ($EVAL_ERROR or (not defined $char and $! and $! != Errno::EBADF)) {
        $self->_set_error(TRUE);
        my $e = $EVAL_ERROR ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot getc' );
        assert_false("Should throw an exception ealier") if ASSERT;
    };

    # clean ungetc buffer
    if ($self->_has_ungetc_buffer and $self->_get_ungetc_buffer ne '') {
        $self->_set_ungetc_buffer( substr $self->_get_ungetc_buffer, 1 );
    };

    if (${^TAINT} and not $self->tainted and defined $char) {
        $char =~ /(.*)/;
        $char = $1;
    };

    return $char;
};


# Method wrapper for CORE::read
sub read {
    ### IO::Moose::Handle::read: @_

    my $self = shift;

    # derefer tie hook
    $self = $$self if blessed $self and reftype $self eq 'REF';

    Exception::Argument->throw(
        message => 'Usage: $io->read(BUF, LEN [, OFFSET])'
    ) if not ref $self or @_ < 2 or @_ > 3;

    my $bytes;
    eval {
        $bytes = CORE::read($self->fh, $_[0], $_[1], $_[2] || 0);
    };
    if (not defined $bytes) {
        $self->_set_error(TRUE);
        my $e = $EVAL_ERROR ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot read' );
    };
    assert_not_null($bytes) if ASSERT;

    return $bytes;
};


# Opposite to read
sub write {
    ### IO::Moose::Handle::write: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->write(BUF [, LEN [, OFFSET]])'
    ) if not blessed $self or @_ > 3 or @_ < 1;

    my ($buf, $len, $offset) = @_;

    my $bytes;
    my $status;
    eval {
        # clean IO modifiers
        local $OUTPUT_RECORD_SEPARATOR = '';

        {
            # IO modifiers based on tied fh modifiers
            my $oldfh = select *$self;
            my $var = $OUTPUT_AUTOFLUSH;
            select $self->fh;
            $OUTPUT_AUTOFLUSH = $var;
            select $oldfh;
        };

        my $output = substr($buf, $offset || 0, defined $len ? $len : length($buf));
        $bytes = length($output);
        $status = CORE::print { $self->fh } $output;
    };
    if (not $status) {
        $self->_set_error(TRUE);
        my $e = $EVAL_ERROR ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot write' );
    };
    assert_true($status) if ASSERT;
    assert_not_null($bytes) if ASSERT;

    return $bytes;
};


# print with EOL
sub say {
    ### IO::Moose::Handle::say: @_

    my $self = shift;

    eval {
        $self->print(@_, "\n");
    };
    if ($EVAL_ERROR) {
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
    ### IO::Moose::Handle::slurp: @_

    my $self = shift;
    my $class = ref $self || $self || __PACKAGE__;
    my %args = @_;

    Exception::Argument->throw(
        message => "Usage: \$io->slurp() or $class->slurp(file=>FILE)"
    ) if not blessed $self and not defined $args{file} or blessed $self and @_ > 0;

    if (not blessed $self) {
        $self = eval { $self->new( %args ) };
        if ($EVAL_ERROR) {
            my $e = Exception::Fatal->catch;
            $e->throw( message => 'Cannot slurp' );
        };
        assert_isa(__PACKAGE__, $self) if ASSERT;
    };

    my (@lines, $string);
    my $wantarray = wantarray;

    my $old_separator = $self->_get_input_record_separator;
    my $old_autochomp = $self->autochomp;

    undef $!;
    eval {
        # scalar or array context
        if ($wantarray) {
            $self->_set_input_record_separator("\n");
            @lines = $self->readline;
        }
        else {
            $self->_set_input_record_separator(undef);
            $self->autochomp(FALSE);
            $string = $self->readline;
        };
    };
    my $e = Exception::Fatal->catch;

    $self->_set_input_record_separator($old_separator);
    $self->autochomp($old_autochomp);

    if ($e) {
        $e->throw( message => 'Cannot slurp' );
    };

    return $wantarray ? @lines : $string;
};


# Wrapper for CORE::truncate
sub truncate {
    ### IO::Moose::Handle::truncate: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->truncate(LEN)'
    ) if not ref $self or @_ != 1 or not looks_like_number $_[0];

    my $status;
    eval {
        $status = CORE::truncate($self->fh, $_[0]);
    };
    if ($EVAL_ERROR or not $status) {
        $self->_set_error(TRUE);
        my $e = $EVAL_ERROR ? Exception::Fatal->catch : Exception::IO->new;
        $e->throw( message => 'Cannot truncate' );
    };
    assert_true($status) if ASSERT;

    return $self;
};


# Interface for File::Stat::Moose
sub stat {
    ### IO::Moose::Handle::stat: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->stat()'
    ) if not ref $self or @_ > 0;

    my $stat;
    eval {
        $stat = File::Stat::Moose->new( file => $self->fh );
    };
    if ($EVAL_ERROR) {
        my $e = Exception::Fatal->catch;
        $self->_set_error(TRUE);
        $e->throw( message => 'Cannot stat' );
    };
    assert_isa('File::Stat::Moose', $stat) if ASSERT;

    return $stat;
};


# Pure Perl implementation
sub error {
    ### IO::Moose::Handle::error: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->error()'
    ) if not blessed $self or @_ > 0;

    return $self->_get_error || ! defined CORE::fileno $self->fh;
};


# Pure Perl implementation
sub clearerr {
    ### IO::Moose::Handle::clearerr: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->clearerr()'
    ) if not blessed $self or @_ > 0;

    $self->_set_error(FALSE);
    return defined CORE::fileno $self->fh;
};


# Uses IO::Handle
sub sync {
    ### IO::Moose::Handle::sync: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->sync()'
    ) if not blessed $self or @_ > 0;

    my $status;
    eval {
        $status = IO::Handle::sync($self->fh);
    };
    if ($EVAL_ERROR or not defined $status) {
        my $e = $EVAL_ERROR ? Exception::Fatal->catch : Exception::IO->new;
        $self->_set_error(TRUE);
        $e->throw( message => 'Cannot sync' );
    };
    assert_not_null($status) if ASSERT;

    return $self;
};


# Pure Perl implementation
sub flush {
    ### IO::Moose::Handle::flush: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->flush()'
    ) if not blessed $self or @_ > 0;

    my $oldfh = select $self->fh;
    my @var = ($OUTPUT_AUTOFLUSH, $OUTPUT_RECORD_SEPARATOR);
    $OUTPUT_AUTOFLUSH = 1;
    $OUTPUT_RECORD_SEPARATOR = undef;

    my $e;
    my $status;
    eval {
        $status = CORE::print { $self->fh } '';
    };
    if ($EVAL_ERROR) {
        $e = Exception::Fatal->catch;
    };

    ($OUTPUT_AUTOFLUSH, $OUTPUT_RECORD_SEPARATOR) = @var;
    select $oldfh;

    if ($e) {
        $self->_set_error(TRUE);
        $e->throw( message => 'Cannot flush' );
    };
    assert_null($e) if ASSERT;

    return $self;
};


# flush + print
sub printflush {
    ### IO::Moose::Handle::printflush: @_

    my $self = shift;

    if (blessed $self) {
        my $oldfh = select *$self;
        my $var = $OUTPUT_AUTOFLUSH;
        $OUTPUT_AUTOFLUSH = 1;

        my $e;
        my $status;
        eval {
            $status = $self->print(@_);
        };
        if ($EVAL_ERROR) {
            $e = Exception::Fatal->catch;
        };

        $OUTPUT_AUTOFLUSH = $var;
        select $oldfh;

        if ($e) {
            $e->throw( message => 'Cannot printflush' );
        };

        return $status;
    }
    else {
        local $OUTPUT_AUTOFLUSH = 1;
        return CORE::print @_;
    };
};


# Uses IO::Handle
sub blocking {
    ### IO::Moose::Handle::blocking: @_

    my $self = shift;

    Exception::Argument->throw(
          message => 'Usage: $io->blocking([BOOL])'
    ) if not blessed $self or @_ > 1;

    # constraint checking
    my $old_blocking = $self->_get_blocking;
    eval {
        $self->_set_blocking($_[0]);
    };
    Exception::Fatal->catch->throw(
        message => 'Cannot blocking'
    ) if $EVAL_ERROR;

    my $status;
    eval {
        if (defined $_[0]) {
            $status = IO::Handle::blocking($self->fh, $_[0]);
        }
        else {
            $status = IO::Handle::blocking($self->fh);
        };
    };
    if ($EVAL_ERROR or not defined $status) {
        my $e = $EVAL_ERROR ? Exception::Fatal->catch : Exception::IO->new;
        $self->_set_error(TRUE);
        $self->_set_blocking($old_blocking);
        $e->throw( message => 'Cannot blocking' );
    };
    assert_not_null($status) if ASSERT;

    return $status;
};


# Uses IO::Handle
sub untaint {
    ### IO::Moose::Handle::untaint: @_

    my $self = shift;

    Exception::Argument->throw(
        message => 'Usage: $io->untaint()'
    ) if not blessed $self or @_ > 0;

    my $status;
    eval {
        $status = IO::Handle::untaint($self->fh);
    };
    if ($EVAL_ERROR or not defined $status or $status != 0) {
        my $e = $EVAL_ERROR ? Exception::Fatal->catch : Exception::IO->new;
        $self->_set_error(TRUE);
        $e->throw( message => 'Cannot untaint' );
    };
    assert_equals(0, $status) if ASSERT;

    $self->_set_tainted(FALSE);

    return $self;
};


# Clean up on destroy
sub DESTROY {
    ### IO::Moose::Handle::DESTROY: @_

    my ($self) = @_;

    local $@ = '';
    eval {
        $self->_untie;
    };

    return $self;
};


# Tie hook by proxy class
sub TIEHANDLE {
    ### IO::Moose::Handle::TIEHANDLE: @_

    my ($class, $instance) = @_;

    # tie object will be stored in scalar reference of main object
    my $self = \$instance;

    # weaken the real object, otherwise it won't be destroyed automatically
    weaken $instance if ref $instance;

    return bless $self => $class;
};


# Called on untie.
sub UNTIE {
    ### IO::Moose::Handle::UNTIE: @_
};


# Add missing methods through Class::MOP
#

{
    # Generate accessors for IO modifiers (global and local)
    my @standard_accessors = (
        'format_formfeed',              # $^L
        'format_line_break_characters', # $:
        'input_record_separator',       # $/
        'output_field_separator',       # $,
        'output_record_separator',      # $\
    );
    foreach my $func (@standard_accessors) {
        my $var = qualify_to_ref(uc($func));
        __PACKAGE__->meta->add_method( $func => sub {
            ### IO::Moose::Handle::$func\: @_
            my $self = shift;
            Exception::Argument->throw(
                message => "Usage: \$io->$func([EXPR]) or " . __PACKAGE__ . "->$func([EXPR])"
            ) if @_ > 1;
            if (ref $self) {
                my $prev = ${*$self}->{$func};
                if (@_ > 0) {
                    ${*$self}->{$func} = shift;
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
    my @output_accessors = (
        'format_lines_left',            # $-
        'format_lines_per_page',        # $=
        'format_page_number',           # $%
        'input_line_number',            # $.
        'output_autoflush',             # $|
    );
    foreach my $func (@output_accessors) {
        my $var = qualify_to_ref(uc($func));
        __PACKAGE__->meta->add_method( $func => sub {
            ### IO::Moose::Handle::$func\: @_
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
    my @format_name_accessors = (
        'format_name',                  # $~
        'format_top_name',              # $^
    );
    foreach my $func (@format_name_accessors) {
        my $var = qualify_to_ref(uc($func));
        __PACKAGE__->meta->add_method( $func => sub {
            ### IO::Moose::Handle::$func\: @_
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

# Aliasing accessor
__PACKAGE__->meta->alias_method('autoflush' => \&output_autoflush);

# Aliasing tie hooks to real functions
foreach my $func (qw{ close eof fileno print printf readline getc }) {
    __PACKAGE__->meta->alias_method(
        uc($func) => __PACKAGE__->meta->get_method($func)->body
    );
};
foreach my $func (qw{ read write }) {
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
 +file : Num|FileHandle|OpenHandle {ro}
 +mode : CanonOpenModeStr = "<" {ro}
 +fh : GlobRef {ro}
 +autochomp : Bool = false {rw}
 +untaint : Bool = ${^TAINT} {ro}
 +blocking : Bool = true {ro}
 +copyfh : Bool = false {ro}
 +strict_accessors : Bool = false {rw}
 +format_formfeed : Str {rw}
 +format_line_break_characters : Str {rw}
 +input_record_separator : Str {rw}
 +output_field_separator : Str {rw}
 +output_record_separator : Str {rw}
 #_error : Bool
 #_ungetc_buffer : Str
 --------------------------------------------------------------------------------------
 <<create>> +new( args : Hash ) : Self
 <<create>> +new_from_fd( fd : Num|FileHandle|OpenHandle, mode : CanonOpenModeStr ) : Self
 <<create>> +slurp( file : Num|FileHandle|OpenHandle, args : Hash ) : Str|Array
 +fdopen( file : Num|FileHandle|OpenHandle, mode : CanonOpenModeStr = '<' ) : Self
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

[IO::Moose::Handle] ---|> [MooseX::GlobRef::Object] [IO::Handle]

[IO::Moose::Handle] ---> <<use>> [File::Stat::Moose]

[IO::Moose::Handle] ---> <<exception>> [Exception::Fatal] [Exception::IO] [Exception::Argument]

=end umlwiki

=head1 IMPORTS

=over

=item use IO::Moose::Handle '$STDIN', '$STDOUT', '$STDERR';

=item use IO::Moose::Handle ':std';

=item use IO::Moose::Handle ':all';

Creates handle as a copy of standard handle and imports it into caller's
namespace.  This handles won't be created until explicit import.

  use IO::Moose::Handle ':std';
  print $STDOUT->autoflush(1);
  print $STDIN->slurp;

=back

=head1 INHERITANCE

=over 2

=item *

extends L<MooseX::GlobRef::Object>

=over 2

=item *

extends L<Moose::Object>

=back

=item *

extends L<IO::Handle>

=back

=head1 EXCEPTIONS

=over

=item L<Exception::Argument>

Thrown whether method is called with wrong argument.

=item L<Exception::Fatal>

Thrown whether fatal error is occurred by core function.

=back

=head1 ATTRIBUTES

=over

=item file : Num|FileHandle|OpenHandle {ro}

File (file descriptor number, file handle or IO object) as a parameter for new
object or argument for C<fdopen> method.

=item mode : CanonOpenModeStr {ro} = "<"

File mode as a parameter for new object or argument for C<fdopen> method.  Can
be Perl-style (C<E<lt>>, C<E<gt>>, C<E<gt>E<gt>>, etc.) or C-style (C<r>,
C<w>, C<a>, etc.)

=item fh : GlobRef {ro}

File handle used for internal IO operations.

=item autochomp : Bool = false {rw}

If is true value the input will be auto chomped.

=item tainted : Bool = ${^TAINT} {rw}

If is false value and tainted mode is enabled the C<untaint> method will be
called after C<fdopen>.

=item blocking : Bool = true {rw}

If is false value the non-blocking IO will be turned on.

=item copyfh : Bool = false {ro}

If is true value the file handle will be copy of I<file> argument.  If
I<file> argument is not a file handle, the L<Exception::Argument> is
thrown.

=item strict_accessors : Bool = false {rw}

By default the accessors might be avoided for performance reason.  This
optimization can be disabled if the attribute is set to true value.

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
I<mode> parameter is defined.

  $io = IO::Moose::Handle->new( file => \*STDIN, mode => "r" );

The object can be created with unopened file handle which can be opened later.

  $in = IO::Moose::Handle->new( file => \*STDIN );
  $in->fdopen("r");

If I<copyfh> is true value and I<file> contains a file handle, this file
handle is copied rather than new file handle created.

  $tmp = File::Temp->new;
  $io = IO::Moose::Handle->new( file => $tmp, copyfh => 1, mode => "w" );

=item new_from_fd( I<fd> : Num|FileHandle|OpenHandle, I<mode> : CanonOpenModeStr = "<") : Self

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

=item fdopen( I<fd> : Num|FileHandle|OpenHandle, I<mode> : CanonOpenModeStr = "<" ) : Self

Opens the previously created file handle.  If the file was already opened, it
is closed automatically and reopened without resetting its line counter.  The
method also sets the C<file> and C<mode> attributes.

  $out = IO::Moose::Handle->new;
  $out->fdopen( \*STDOUT, "w" );

  $dup = IO::Moose::Handle->new;
  $dup->fdopen( $dup, "a" );

  $stdin = IO::Moose::Handle->new;
  $stdin->fdopen( 0, "r");

=item close(I<>) : Self

Closes the opened file handle.  The C<file> and C<mode> attributes are cleared
after closing.

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

=head1 DEBUGGING

The debugging mode can be enabled if C<PERL_DEBUG_IO_MOOSE_HANDLE> environment
variable is set to true value.  The debugging mode requires L<Smart::Comments>
module.

The run-time assertions can be enabled with L<Test::Assert> module.

=head1 INTERNALS

This module uses L<MooseX::GlobRef::Object> and stores the object's attributes
in glob reference.  They can be accessed with C<${*$self}-E<gt>{attr}>
expression or with standard accessors C<$self-E<gt>attr>.

There are two handles used for IO operations: the original handle used for
real IO operations and tied handle which hooks IO functions interface.

The OO-style uses original handle stored in I<fh> field.

  # Usage:
  $io->print("OO style");

  # Implementation:
  package IO::Moose::Handle;
  sub print {
      $self = shift;
      CORE::print { $self->fh } @_
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
      CORE::print { $self->fh } @_
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
