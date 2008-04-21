package IO::Moose::HandleTest;

use strict;
use warnings;

use base 'Test::Unit::TestCase';

use IO::Moose::Handle;
use Exception::Base ':all';

use File::Temp 'tempfile';

use Scalar::Util 'reftype';

{
    package IO::Moose::HandleTest::Test1;

    sub new {
        my ($class, $mode, $fd) = @_;
        my $fileno = fileno $fd;
        open my $fh, "$mode&=$fileno";
        bless $fh => $class;
    }
}

my ($filename_in, $fh_in, $filename_out, $fh_out);

sub set_up {
    $filename_in = __FILE__;
    ((my $tmp), $filename_out) = tempfile;
    select select $fh_in;
    select select $fh_out;
}

sub tear_down {
    close $fh_in;
    close $fh_out;
    unlink $filename_out;
}

sub test___isa {
    my $self = shift;
    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
}

sub test_new_empty {
    my $self = shift;
    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_null($obj->fileno);
}

sub test_fdopen {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    # fdopen($fh)
    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_in);
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);
    $self->assert_not_null($obj1->fileno);

    # fdopen($io_handle_moose)
    my $obj2 = IO::Moose::Handle->new;
    $self->assert_not_null($obj2);
    $self->assert($obj2->isa("IO::Moose::Handle"), '$obj2->isa("IO::Moose::Handle")');
    $obj2->fdopen($obj1);
    $self->assert_not_null($obj2);
    $self->assert($obj2->isa("IO::Moose::Handle"), '$obj2->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj2);
    $self->assert_not_null($obj2->fileno);

    # fdopen($io_handle)
    my $obj3 = IO::Moose::Handle->new;
    $self->assert_not_null($obj3);
    $self->assert($obj3->isa("IO::Moose::Handle"), '$obj3->isa("IO::Moose::Handle")');
    my $io = IO::Moose::HandleTest::Test1->new('<', $fh_in);
    $self->assert_not_null($io);
    $obj3->fdopen($io);
    $self->assert_not_null($obj3);
    $self->assert($obj3->isa("IO::Moose::Handle"), '$obj3->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj3);
    $self->assert_not_null($obj3->fileno);

    # fdopen($fileno)
    my $obj4 = IO::Moose::Handle->new;
    $self->assert_not_null($obj4);
    $self->assert($obj4->isa("IO::Moose::Handle"), '$obj->isa4("IO::Moose::Handle")');
    my $fileno = $obj1->fileno;
    $obj4->fdopen($fileno);
    $self->assert_not_null($obj4);
    $self->assert($obj4->isa("IO::Moose::Handle"), '$obj4->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj4);
    $self->assert_not_null($obj4->fileno);
    
    # fdopen('GLOB')
    my $obj5 = IO::Moose::Handle->new;
    $self->assert_not_null($obj5);
    $self->assert($obj5->isa("IO::Moose::Handle"), '$obj5->isa("IO::Moose::Handle")');
    $obj5->fdopen('STDIN');
    $self->assert_not_null($obj5);
    $self->assert($obj5->isa("IO::Moose::Handle"), '$obj5->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj5);
    $self->assert_not_null($obj5->fileno);

    # tear down
    close $fh_in;
}

sub test_fdopen_error {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    try eval { $obj1->fdopen; };
    catch my $e1;
    $self->assert_equals('Exception::Argument', ref $e1);

    my $obj2 = IO::Moose::Handle->new;
    $self->assert_not_null($obj2);
    $self->assert($obj2->isa("IO::Moose::Handle"), '$obj2->isa("IO::Moose::Handle")');
    try eval { $obj2->fdopen($fh_in, '<', 'extra_arg'); };
    catch my $e2;
    $self->assert_equals('Exception::Argument', ref $e2);

    my $obj3 = IO::Moose::Handle->new;
    $self->assert_not_null($obj3);
    $self->assert($obj3->isa("IO::Moose::Handle"), '$obj3->isa("IO::Moose::Handle")');
    try eval { $obj3->fdopen('IO_HANDLE_MOOSETEST_BADGLOB'); };
    catch my $e3;
    $self->assert_equals('Exception::IO', ref $e3);

    my $obj4 = IO::Moose::Handle->new;
    $self->assert_not_null($obj4);
    $self->assert($obj4->isa("IO::Moose::Handle"), '$obj4->isa("IO::Moose::Handle")');
    try eval { my $obj4 = IO::Moose::Handle->fdopen($fh_in, 'unknown_flag'); };
    catch my $e4;
    $self->assert_matches(qr/does not pass the type constraint/, $@);

    # tear down
    close $fh_in;
}

sub test_fdopen_constructor {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->fdopen($fh_in);
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);
    $self->assert_not_null($obj1->fileno);

    # tear down
    close $fh_in;
}

sub test_fdopen_constructor_error {
    my $self = shift;
    try eval { my $obj1 = IO::Moose::Handle->fdopen; };
    catch my $e1;
    $self->assert_equals('Exception::Argument', ref $e1);
}

sub test_close {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_in);
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);
    $self->assert_not_null($obj1->fileno);

    $obj1->close;

    # close closed fh
    try eval { $obj1->close; };
    catch my $e1;
    $self->assert_equals('Exception::IO', ref $e1);

    # tear down
    close $fh_in;
}

sub test_close_tied {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_in);
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);
    $self->assert_not_null($obj1->fileno);

    close $obj1;

    # close closed fh
    try eval { close $obj1; };
    catch my $e1;
    $self->assert_equals('Exception::IO', ref $e1);

    # tear down
    close $fh_in;
}

sub test_eof_not_empty_file {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_in);
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);
    $self->assert_not_null($obj1->fileno);

    $self->assert(not $obj1->eof);
    $obj1->close;

    $self->assert($obj1->eof);

    # tear down
    close $fh_in;
}

sub test_eof_empty_file {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';
    close $fh_out;
    open $fh_out, '<', $filename_out or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_out);
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);
    $self->assert_not_null($obj1->fileno);

    $self->assert($obj1->eof);
    $obj1->close;

    $self->assert($obj1->eof);

    # tear down
    close $fh_in;
}

sub test_eof_tied_not_empty_file {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_in);
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);
    $self->assert_not_null($obj1->fileno);

    $self->assert(not eof $obj1);
    $obj1->close;

    $self->assert(eof $obj1);

    # tear down
    close $fh_in;
}

sub test_eof_tied_empty_file {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';
    close $fh_out;
    open $fh_out, '<', $filename_out or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_out);
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);
    $self->assert_not_null($obj1->fileno);

    $self->assert(eof $obj1);
    $obj1->close;

    $self->assert(eof $obj1);

    # tear down
    close $fh_in;
}


sub test_eof_exception {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_out, 'w');
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);
    $self->assert_not_null($obj1->fileno);

    try eval { $obj1->eof; };
    catch my $e1;
    $self->assert_equals('Exception::Fatal', ref $e1);

    # tear down
    close $fh_out;
}

sub test_fileno {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_in);
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);
    $self->assert_not_null($obj1->fileno);

    $obj1->close;

    $self->assert_null($obj1->fileno);

    # tear down
    close $fh_in;
}

sub test_fileno_tied {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_in);
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);
    $self->assert_not_null(fileno $obj1);

    $obj1->close;

    $self->assert_null(fileno $obj1);

    # tear down
    close $fh_in;
}

sub test_opened {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    
    $self->assert(! $obj1->opened, '! $obj1->opened');
    
    $obj1->fdopen($fh_in);
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);
    $self->assert_not_null($obj1->fileno);

    $self->assert($obj1->opened, '$obj1->opened');

    $obj1->close;

    $self->assert(! $obj1->opened, '! $obj1->opened');

    # tear down
    close $fh_in;
}

sub test_print {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_out, 'w');
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);

    $self->assert_not_null($obj1->print('a'));
    $self->assert_not_null($obj1->print('b'));
    $self->assert_not_null($obj1->print('c'));

    $obj1->close;

    open my $f, '<', $filename_out or throw 'Exception::IO';
    my $content = <$f>;
    close $f;
    $self->assert_equals('abc', $content);

    try eval { $obj1->print('WARN'); };
    catch my $e1;
    $self->assert_equals('Exception::Fatal', ref $e1);

    # tear down
    close $fh_out;
}

sub test_print_tied {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_out, 'w');
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);

    $self->assert_not_null(print $obj1 'a');
    $self->assert_not_null(print $obj1 'b');
    $self->assert_not_null(print $obj1 'c');

    $obj1->close;

    open my $f, '<', $filename_out or throw 'Exception::IO';
    my $content = <$f>;
    close $f;
    $self->assert_equals('abc', $content);

    try eval { print $obj1 'WARN'; };
    catch my $e1;
    $self->assert_equals('Exception::Fatal', ref $e1);

    # tear down
    close $fh_out;
}

sub test_printf {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_out, 'w');
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);

    $self->assert_not_null($obj1->printf('%s', 'a'));
    $self->assert_not_null($obj1->printf('%c', ord('b')));
    $self->assert_not_null($obj1->printf('c'));

    $obj1->close;

    open my $f, '<', $filename_out or throw 'Exception::IO';
    my $content = <$f>;
    close $f;
    $self->assert_equals('abc', $content);

    try eval { $obj1->printf('WARN'); };
    catch my $e1;
    $self->assert_equals('Exception::Fatal', ref $e1);

    # tear down
    close $fh_out;
}

sub test_printf_tied {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_out, 'w');
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);

    $self->assert_not_null(printf $obj1 '%s', 'a');
    $self->assert_not_null(printf $obj1 '%c', ord('b'));
    $self->assert_not_null(printf $obj1 'c');

    $obj1->close;

    open my $f, '<', $filename_out or throw 'Exception::IO';
    my $content = <$f>;
    close $f;
    $self->assert_equals('abc', $content);

    try eval { printf $obj1 'WARN'; };
    catch my $e1;
    $self->assert_equals('Exception::Fatal', ref $e1);

    # tear down
    close $fh_out;
}

sub test_write {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_out, 'w');
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);

    $obj1->write('abcdef');
    $obj1->write('ghijkl', 3);
    $obj1->write('mnopqr', 3, 2);

    $obj1->close;

    open my $f, '<', $filename_out or throw 'Exception::IO';
    my $content = <$f>;
    close $f;
    $self->assert_equals('abcdefghiopq', $content);

    try eval { $obj1->write('WARN'); };
    catch my $e1;
    $self->assert_equals('Exception::Fatal', ref $e1);

    # tear down
    close $fh_out;
}

{
    our $format_content = "content\n" x 5;
    format FORMAT_TEST1_TOP =
@||||||||||||||||||||||||||
"header"
.

    format FORMAT_TEST1 =
@<<<<<<   @||||||   @>>>>>>
"left",   "middle", "right"
@*
$format_content
.

}

sub test_format_write {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';
    my @vars = ($=, $-, $~, $^, $^L);

    eval {
        my $obj1 = IO::Moose::Handle->new;
        $self->assert_not_null($obj1);
        $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
        $obj1->fdopen($fh_out, 'w');
        $self->assert_not_null($obj1);
        $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
        $self->assert_equals('GLOB', reftype $obj1);

        my $old1 = $obj1->format_lines_per_page(3);
        $self->assert_equals(3, $obj1->format_lines_per_page);
        my $old2 = $obj1->format_lines_left(5);
        $self->assert_equals(5, $obj1->format_lines_left);
        my $old3 = $obj1->format_formfeed(']');
        $self->assert_equals(']', $obj1->format_formfeed);

        $obj1->format_write(__PACKAGE__ . '::FORMAT_TEST1');
    
        my $prev1 = $obj1->format_lines_per_page;
        $self->assert_equals(3, $prev1);

        $prev1 = $obj1->format_lines_per_page($old1);
        $self->assert_equals(3, $prev1);

        $obj1->close;

        open my $f, '<', $filename_out;
        read $f, (my $content), 99999;
        close $f;
        my $string = "          header\nleft      middle      right\ncontent\n]"
                   . "          header\ncontent\ncontent\n]"
                   . "          header\ncontent\ncontent\n";
        $self->assert_equals($string, $content);

        try eval { $obj1->format_write(__PACKAGE__ . '::FORMAT_TEST1'); };
        catch my $e1;
        $self->assert_equals('Exception::Fatal', ref $e1);
    };

    # tear down
    close $fh_out;
    ($=, $-, $~, $^, $^L) = @vars;
    
    die $@ if $@;
}

sub test_output_record_separator {
    my $self = shift;
    return if $^V lt v5.8;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';
    my @vars = ($\);

    eval {
        my $obj1 = IO::Moose::Handle->new;
        $self->assert_not_null($obj1);
        $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
        $obj1->fdopen($fh_out, 'w');
        $self->assert_not_null($obj1);
        $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
        $self->assert_equals('GLOB', reftype $obj1);

        my $obj2 = IO::Moose::Handle->new;
        $self->assert_not_null($obj2);
        $self->assert($obj2->isa("IO::Moose::Handle"), '$obj2->isa("IO::Moose::Handle")');
        $obj2->fdopen($fh_out, 'w');
        $self->assert_not_null($obj2);
        $self->assert($obj2->isa("IO::Moose::Handle"), '$obj2->isa("IO::Moose::Handle")');
        $self->assert_equals('GLOB', reftype $obj2);

        my $old1 = IO::Moose::Handle->output_record_separator(':');
        $self->assert_equals(':', IO::Moose::Handle->output_record_separator);

        my $old2 = $obj2->output_record_separator('-');
        $self->assert_equals('-', $obj2->output_record_separator);

        $self->assert_not_null($obj1->print('a'));
        $self->assert_not_null($obj1->print('b'));
        $obj1->close;

        $self->assert_not_null($obj2->print('c'));
        $self->assert_not_null($obj2->print('d'));

        my $prev1 = IO::Moose::Handle->output_record_separator;
        $self->assert_equals(':', $prev1);

        my $prev2 = $obj2->output_record_separator;
        $self->assert_equals('-', $prev2);

        $prev1 = IO::Moose::Handle->output_record_separator($old1);
        $self->assert_equals(':', $prev1);

        $prev2 = $obj2->output_record_separator($old2);
        $self->assert_equals('-', $prev2);

        $self->assert_not_null($obj2->print('e'));
        $self->assert_not_null($obj2->print('f'));

        $obj2->output_record_separator('!');
        $obj2->clear_output_record_separator;

        $self->assert_not_null($obj2->print('g'));
        $self->assert_not_null($obj2->print('h'));

        $obj2->close;

        open my $f, '<', $filename_out;
        read $f, (my $content), 99999;
        close $f;
        $self->assert_equals('a:b:c-d-efgh', $content);
    };

    # tear down
    close $fh_out;
    ($\) = @vars;
    
    die $@ if $@;
}

sub test_output_field_separator {
    my $self = shift;
    return if $^V lt v5.8;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';
    my @vars = ($,);

    eval {
        my $obj1 = IO::Moose::Handle->new;
        $self->assert_not_null($obj1);
        $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
        $obj1->fdopen($fh_out, 'w');
        $self->assert_not_null($obj1);
        $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
        $self->assert_equals('GLOB', reftype $obj1);

        my $obj2 = IO::Moose::Handle->new;
        $self->assert_not_null($obj2);
        $self->assert($obj2->isa("IO::Moose::Handle"), '$obj2->isa("IO::Moose::Handle")');
        $obj2->fdopen($fh_out, 'w');
        $self->assert_not_null($obj2);
        $self->assert($obj2->isa("IO::Moose::Handle"), '$obj2->isa("IO::Moose::Handle")');
        $self->assert_equals('GLOB', reftype $obj2);

        my $old1 = IO::Moose::Handle->output_field_separator(':');
        $self->assert_equals(':', IO::Moose::Handle->output_field_separator);

        my $old2 = $obj2->output_field_separator('-');
        $self->assert_equals('-', $obj2->output_field_separator);

        $self->assert_not_null($obj1->print('a', 'b'));
        $obj1->close;

        $self->assert_not_null($obj2->print('c', 'd'));

        my $prev1 = IO::Moose::Handle->output_field_separator;
        $self->assert_equals(':', $prev1);

        my $prev2 = $obj2->output_field_separator;
        $self->assert_equals('-', $prev2);

        $prev1 = IO::Moose::Handle->output_field_separator($old1);
        $self->assert_equals(':', $prev1);

        $prev2 = $obj2->output_field_separator($old2);
        $self->assert_equals('-', $prev2);

        $self->assert_not_null($obj2->print('e', 'f'));

        $obj2->output_field_separator('!');
        $obj2->clear_output_field_separator;

        $self->assert_not_null($obj2->print('g', 'h'));

        $obj2->close;

        open my $f, '<', $filename_out;
        read $f, (my $content), 99999;
        close $f;
        $self->assert_equals('a:bc-defgh', $content);
    };

    # tear down
    close $fh_out;
    ($,) = @vars;
    
    die $@ if $@;
}

sub test_readline_wantscalar {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    if (${^TAINT}) {
	$obj->untaint;
    }

    my $c = $obj->readline;
    $self->assert(length $c > 1, 'length $c > 1');
    $self->assert($c =~ tr/\n// == 1, '$c =~ tr/\n// == 1');

    if (${^TAINT}) {
	no warnings;
	kill 0 * $c;
    }

    $obj->close;

    # tear down
    close $fh_in;
}

sub test_readline_wantarray {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    if (${^TAINT}) {
	$obj->untaint;
    }

    my @c = $obj->readline;
    $self->assert(scalar @c > 1, 'scalar @c > 1');

    if (${^TAINT}) {
	no warnings;
	kill 0 * $c[0];
    }

    $obj->close;

    # tear down
    close $fh_in;
}

sub test_readline_ungetc_wantscalar {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    $obj->ungetc(ord('A'));
    $obj->ungetc(ord("\n"));
    $obj->ungetc(ord('B'));

    my $c1 = $obj->readline;
    $self->assert_equals(2, length $c1);
    $self->assert($c1 eq "B\n");

    my $c2 = $obj->readline;
    $self->assert(length $c2 > 1, 'length $c2 > 1');
    $self->assert_matches(qr/^A/, $c2);

    $obj->close;

    # tear down
    close $fh_in;
}

sub test_readline_ungetc_wantarray {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    $obj->ungetc(ord('A'));
    $obj->ungetc(ord("\n"));
    $obj->ungetc(ord('B'));

    my @c = $obj->readline;
    $self->assert(scalar @c > 2, 'scalar @c > 2');
    $self->assert_equals("B\n", $c[0]);
    $self->assert_matches(qr/^A/, $c[1]);

    $obj->close;

    # tear down
    close $fh_in;
}

sub test_readline_global_input_record_separator {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';
    my @vars = ($/);

    eval {
        my $obj = IO::Moose::Handle->new;
        $self->assert_not_null($obj);
        $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
        $obj->fdopen($fh_in);
        $self->assert_not_null($obj);
        $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
        $self->assert_equals('GLOB', reftype $obj);
        $self->assert_not_null($obj->fileno);

        my $old = IO::Moose::Handle->input_record_separator(undef);
        $self->assert_null(IO::Moose::Handle->input_record_separator);

        my $l = (stat __FILE__)[7];
        $self->assert($l > 1, '$l > 1');
        my $c = $obj->readline;
        $self->assert_equals($l, length $c);
        $self->assert($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');

        $obj->close;

        my $prev = IO::Moose::Handle->input_record_separator;
        $self->assert_null($prev);

        $prev = IO::Moose::Handle->input_record_separator($old);
        $self->assert_null($prev);
    };

    # tear down
    close $fh_in;
    ($/) = @vars;
    
    die $@ if $@;
}

sub test_readline_filehandle_input_record_separator {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';
    my @vars = ($/);

    eval {
        my $obj = IO::Moose::Handle->new;
        $self->assert_not_null($obj);
        $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
        $obj->fdopen($fh_in);
        $self->assert_not_null($obj);
        $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
        $self->assert_equals('GLOB', reftype $obj);
        $self->assert_not_null($obj->fileno);

        my $old = $obj->input_record_separator(\1000);
        $self->assert_equals('SCALAR', ref $obj->input_record_separator);
        $self->assert_equals(1000, ${ $obj->input_record_separator });

        my $c1 = $obj->readline;
        $self->assert_equals(1000, length $c1);

        my $prev = $obj->input_record_separator;
        $self->assert_equals('SCALAR', ref $prev);
        $self->assert_equals(1000, ${$prev});

        $prev = $obj->input_record_separator($old);
        $self->assert_equals('SCALAR', ref $prev);
        $self->assert_equals(1000, ${$prev});

        $obj->input_record_separator('!');
        $obj->clear_input_record_separator;

        my $c2 = $obj->readline;
        $self->assert_not_equals(1000, length $c2);
        $self->assert($c2 =~ tr/\n// == 1, '$c2 =~ tr/\n// == 1');

        $obj->close;
    };

    # tear down
    close $fh_in;
    ($/) = @vars;
    
    die $@ if $@;
}

sub test_readline_exception {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);
    
    $obj->close;
    $self->assert_null($obj->fileno);    

    try eval { $obj->readline };
    catch my $e;
    $self->assert_equals('Exception::Fatal', ref $e);

    # tear down
    close $fh_in;
}

sub test_getline_wantscalar {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    my $c = $obj->getline;
    $self->assert(length $c > 1, 'length $c > 1');
    $self->assert($c =~ tr/\n// == 1, '$c =~ tr/\n// == 1');

    $obj->close;

    # tear down
    close $fh_in;
}

sub test_getline_wantarray {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    my @c = $obj->getline;
    $self->assert(scalar @c == 1, 'scalar @c == 1');
    $self->assert($c[0] =~ tr/\n// == 1, '$c[0] =~ tr/\n// == 1');

    $obj->close;

    # tear down
    close $fh_in;
}

sub test_getline_exception {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);
    
    $obj->close;
    $self->assert_null($obj->fileno);    

    try eval { $obj->getline };
    catch my $e;
    $self->assert_equals('Exception::Fatal', ref $e);

    # tear down
    close $fh_in;
}

sub test_getlines_wantscalar_exception {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    try eval { my $c = $obj->getlines };
    catch my $e;
    $self->assert_equals('Exception::Argument', ref $e);

    $obj->close;

    # tear down
    close $fh_in;
}

sub test_getlines_wantarray {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    my @c = $obj->getlines;
    $self->assert(scalar @c > 1, 'scalar @c > 1');

    $obj->close;

    # tear down
    close $fh_in;
}

sub test_getlines_exception {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);
    
    $obj->close;
    $self->assert_null($obj->fileno);    

    try eval { my @c = $obj->getlines };
    catch my $e;
    $self->assert_equals('Exception::Fatal', ref $e);

    # tear down
    close $fh_in;
}

sub test_sysread {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    if (${^TAINT}) {
	$obj->untaint;
    }

    my $s1 = $obj->sysread(my $c, 10);
    $self->assert_equals(10, $s1);
    $self->assert_equals(10, length($c));

    my $s2 = $obj->sysread($c, 10, 10);
    $self->assert_equals(10, $s2);
    $self->assert_equals(20, length($c));

    if (${^TAINT}) {
	no warnings;
	kill 0 * $c;
    }

    $obj->close;

    # tear down
    close $fh_in;
}

sub test_sysread_tied {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

    if (${^TAINT}) {
	$obj->untaint;
    }

    my $s1 = sysread $obj, (my $c), 10;
    $self->assert_equals(10, $s1);
    $self->assert_equals(10, length($c));

    my $s2 = sysread $obj, $c, 10, 10;
    $self->assert_equals(10, $s2);
    $self->assert_equals(20, length($c));

    if (${^TAINT}) {
	no warnings;
	kill 0 * $c;
    }

    $obj->close;

    # tear down
    close $fh_in;
}

sub test_sysread_exception {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);
    
    try eval { my $s1 = $obj->sysread('CONST', 10) };
    catch my $e1;
    # Modification of a read-only value attempted
    $self->assert_equals('Exception::Fatal', ref $e1);

    try eval { my $s2 = $obj->sysread };
    catch my $e2;
    $self->assert_equals('Exception::Argument', ref $e2);

    $obj->close;
    $self->assert_null($obj->fileno);    

    try eval { my $s3 = $obj->sysread(my $c, 10) };
    catch my $e3;
    # sysread() on closed filehandle
    $self->assert_equals('Exception::Fatal', ref $e3)
	if $^V ge v5.8;

    # tear down
    close $fh_in;
}

sub test_syswrite {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_out, 'w');
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);

    my $s1 = $obj->syswrite('1234567890');
    $self->assert_equals(10, $s1);

    my $s2 = $obj->syswrite('1234567890', 5);
    $self->assert_equals(5, $s2);

    my $s3 = $obj->syswrite('1234567890', 5, 5);
    $self->assert_equals(5, $s3);

    $obj->close;

    open my $f, '<', $filename_out or throw 'Exception::IO';
    read $f, (my $content), 99999;
    $self->assert_equals('12345678901234567890', $content);

    # tear down
    close $fh_in;
}

sub test_syswrite_tied {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_out, 'w');
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);

    my $s1 = syswrite $obj, '1234567890';
    $self->assert_equals(10, $s1);

    my $s2 = syswrite $obj, '1234567890', 5;
    $self->assert_equals(5, $s2);

    my $s3 = syswrite $obj, '1234567890', 5, 5;
    $self->assert_equals(5, $s3);

    $obj->close;

    open my $f, '<', $filename_out or throw 'Exception::IO';
    read $f, (my $content), 99999;
    $self->assert_equals('12345678901234567890', $content);

    # tear down
    close $fh_in;
}

sub test_getc {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';
    printf $fh_out "ABC\000" or throw 'Exception::IO';
    close $fh_out or throw 'Exception::IO';

    open $fh_in, '<', $filename_out or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in, 'r');
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);

    if (${^TAINT}) {
	$obj->untaint;
    }

    my $c1 = $obj->getc;
    $self->assert_equals('A', $c1);

    my $c2 = $obj->getc;
    $self->assert_equals('B', $c2);

    my $c3 = $obj->getc;
    $self->assert_equals('C', $c3);

    my $c4 = $obj->getc;
    $self->assert_equals(0, ord($c4));

    my $c5 = $obj->getc;
    $self->assert_null($c5, '$c5 = $obj->getc');

    my $c6 = $obj->getc;
    $self->assert_null($c6, '$c6 = $obj->getc');

    if (${^TAINT}) {
	no warnings;
	kill 0 * $c1;
    }

    $obj->close;

    # tear down
    close $fh_in;
}

sub test_getc_tied {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';
    printf $fh_out "ABC\000" or throw 'Exception::IO';
    close $fh_out or throw 'Exception::IO';

    open $fh_in, '<', $filename_out or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in, 'r');
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);

    if (${^TAINT}) {
	$obj->untaint;
    }

    my $c1 = getc $obj;
    $self->assert_equals('A', $c1);

    my $c2 = getc $obj;
    $self->assert_equals('B', $c2);

    my $c3 = getc $obj;
    $self->assert_equals('C', $c3);

    my $c4 = getc $obj;
    $self->assert_equals(0, ord($c4));

    my $c5 = getc $obj;
    $self->assert_null($c5, '$c5 = getc $obj');

    my $c6 = getc $obj;
    $self->assert_null($c6, '$c6 = getc $obj');

    if (${^TAINT}) {
	no warnings;
	kill 0 * $c1;
    }

    $obj->close;

    # tear down
    close $fh_in;
}

sub test_getc_ungetc {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';
    printf $fh_out "ABC" or throw 'Exception::IO';
    close $fh_out or throw 'Exception::IO';

    open $fh_in, '<', $filename_out or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in, 'r');
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);

    my $c1 = $obj->getc;
    $self->assert_equals('A', $c1);
    
    $obj->ungetc(ord('1'));
    $obj->ungetc(ord('2'));

    my $c2 = $obj->getc;
    $self->assert_equals('2', $c2);

    my $c3 = $obj->getc;
    $self->assert_equals('1', $c3);

    my $c4 = $obj->getc;
    $self->assert_equals('B', $c4);

    my $c5 = $obj->getc;
    $self->assert_equals('C', $c5);

    my $c6 = $obj->getc;
    $self->assert_null($c6, '$c6 = $obj->getc');

    $obj->ungetc(ord('3'));

    my $c7 = $obj->getc;
    $self->assert_equals('3', $c7);

    my $c8 = $obj->getc;
    $self->assert_null($c8, '$c8 = $obj->getc');

    $obj->close;

    # tear down
    close $fh_in;
}

sub test_getc_exception {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_out, 'w');
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);
    
    try eval { $obj->getc('ARG') };
    catch my $e1;
    $self->assert_equals('Exception::Argument', ref $e1);

    try eval { $obj->getc };
    catch my $e2;
    # Filehandle $fh opened only for output
    $self->assert_equals('Exception::Fatal', ref $e2);

    $obj->close;
    $self->assert_null($obj->fileno);    

    # tear down
    close $fh_in;
}

sub test_say {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_out, 'w');
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);

    $self->assert_not_null($obj1->say('a'));
    $self->assert_not_null($obj1->say('b'));
    $self->assert_not_null($obj1->say('c'));

    $obj1->close;

    open my $f, '<', $filename_out or throw 'Exception::IO';
    read $f, (my $content), 99999;
    close $f;
    $self->assert_equals("a\nb\nc\n", $content);

    try eval { $obj1->say('WARN'); };
    catch my $e1;
    $self->assert_equals('Exception::Fatal', ref $e1);

    # tear down
    close $fh_out;
}

sub test_slurp_wantscalar {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

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

    # tear down
    close $fh_in;
}

sub test_slurp_wantarray {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in);
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);
    $self->assert_not_null($obj->fileno);

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

    # tear down
    close $fh_in;
}

sub test_slurp_from_fd_wantscalar {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $c = IO::Moose::Handle->slurp($fh_in);
    $self->assert(length $c > 1, 'length $c > 1');
    $self->assert($c =~ tr/\n// > 1, '$c =~ tr/\n// > 1');

    # tear down
    close $fh_in;
}

sub test_truncate {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';
    print $fh_out "ABCDEFGHIJ" or throw 'Exception::IO';
    close $fh_out or throw 'Exception::IO';
    open $fh_out, '>>', $filename_out or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_out, 'w');
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);

    $self->assert_not_null($obj->truncate(5));
    $self->assert_not_null($obj->truncate(10));

    $obj->close;

    open my $f, '<', $filename_out or throw 'Exception::IO';
    read $f, (my $content), 99999;
    close $f;
    $self->assert_equals("ABCDE\000\000\000\000\000", $content);

    try eval { $obj->truncate(1); };
    catch my $e1;
    # Bad file descriptor
    $self->assert_equals('Exception::IO', ref $e1);

    # tear down
    close $fh_out;
}

sub test_stat {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    try eval {
        my $obj = IO::Moose::Handle->new;
        $self->assert_not_null($obj);
        $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
        $obj->fdopen($fh_in, 'r');
        $self->assert_not_null($obj);
        $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
        $self->assert_equals('GLOB', reftype $obj);

        my $st = $obj->stat();
        $self->assert_not_null($st);
        $self->assert($st->isa("File::Stat::Moose"), '$st->isa("File::Stat::Moose")');

        $obj->close;

        open my $f, '<', $filename_in or throw 'Exception::IO';
        read $f, (my $content), 99999;
        close $f;
        $self->assert_equals(length($content), $st->size);

        try eval { $obj->stat; };
        catch my $e1;
        # Bad file descriptor
        $self->assert_equals('Exception::Fatal', ref $e1);
    };
    catch my $e, ['Exception::Fatal'];

    # tear down
    close $fh_in;
}

sub test_error {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;

    $self->assert_equals(-1, $obj1->error);

    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_out, 'w');
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);

    $self->assert_equals(0, $obj1->error);

    $self->assert_not_null($obj1->print('a'));
    $self->assert_equals(0, $obj1->error);

    eval {
	$obj1->getline;
    };

    $self->assert_equals(1, $obj1->error);
    $self->assert_equals(1, $obj1->error);
    $self->assert_equals(0, $obj1->clearerr);
    $self->assert_equals(0, $obj1->error);
    
    $obj1->close;
    $self->assert_equals(-1, $obj1->error);
    $self->assert_equals(-1, $obj1->clearerr);
    $self->assert_equals(-1, $obj1->error);

    # tear down
    close $fh_out;
}

sub test_sync {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_out, 'w');
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);

    $self->assert_equals(0, $obj1->error);

    $self->assert_not_null($obj1->print('a'));

    my $c1 = try eval {
	$obj1->sync;
    };
    catch my $e1;

    if (ref $e1 eq 'Exception::Fatal') {
	# skip: unimplemented
    }
    elsif ($e1) {
	throw $e1;
    }
    else {
	$self->assert($c1, '$c1');
    }
    
    $obj1->close;

    my $c2 = try eval {
	$obj1->sync;
    };
    catch my $e2;

    if (ref $e1 eq 'Exception::Fatal') {
	# skip: unimplemented
    }
    elsif ($e1) {
	throw $e1;
    }
    else {
	$self->assert(!$c2, '!$c2');
    }
    
    # tear down
    close $fh_out;
}

sub test_flush {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_out, 'w');
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);

    $self->assert_equals(0, $obj1->error);

    $self->assert_not_null($obj1->print('a'));
    $self->assert_not_null($obj1->print('b'));

    open my $f1, '<', $filename_out or throw 'Exception::IO';
    read $f1, (my $content1), 99999;
    close $f1;
    $self->assert_equals('', $content1);

    my $c1 = $obj1->flush;
    $self->assert_not_null($c1);

    open my $f2, '<', $filename_out or throw 'Exception::IO';
    read $f2, (my $content2), 99999;
    close $f2;
    $self->assert_equals('ab', $content2);

    $obj1->close;

    open my $f, '<', $filename_out or throw 'Exception::IO';
    read $f, (my $content), 99999;
    close $f;
    $self->assert_equals('ab', $content);

    try eval { $obj1->flush };
    catch my $e1;
    $self->assert_equals('Exception::Fatal', ref $e1);
    
    # tear down
    close $fh_out;
}

sub test_printflush {
    my $self = shift;

    # set up
    open $fh_out, '>', $filename_out or throw 'Exception::IO';

    my $obj1 = IO::Moose::Handle->new;
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $obj1->fdopen($fh_out, 'w');
    $self->assert_not_null($obj1);
    $self->assert($obj1->isa("IO::Moose::Handle"), '$obj1->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj1);

    $self->assert_equals(0, $obj1->error);

    $self->assert($obj1->printflush('a'), '$obj1->printflush(\'a\')');

    open my $f1, '<', $filename_out or throw 'Exception::IO';
    read $f1, (my $content1), 99999;
    close $f1;
    $self->assert_equals('a', $content1);

    $self->assert($obj1->printflush('b'), '$obj1->printflush(\'b\')');
    
    open my $f2, '<', $filename_out or throw 'Exception::IO';
    read $f2, (my $content2), 99999;
    close $f2;
    $self->assert_equals('ab', $content2);

    $obj1->close;

    try eval { $obj1->printflush('c'); };
    catch my $e1;
    # Bad file descriptor
    $self->assert_equals('Exception::Fatal', ref $e1);
    
    # tear down
    close $fh_out;
}

sub test_blocking {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    try eval {
        my $obj = IO::Moose::Handle->new;
        $self->assert_not_null($obj);
        $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
        $obj->fdopen($fh_in, 'r');
        $self->assert_not_null($obj);
        $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
        $self->assert_equals('GLOB', reftype $obj);

        my $c1 = $obj->blocking(0);
        $self->assert_equals(1, $c1);

        my $c2 = $obj->blocking;
        $self->assert_equals(0, $c2);

        my $c3 = $obj->blocking(1);
        $self->assert_equals(0, $c3);

        my $c4 = $obj->blocking;
        $self->assert_equals(1, $c4);

        $obj->close;

        try eval { $obj->blocking; };
        catch my $e1;
        # Bad file descriptor
        $self->assert_equals('Exception::IO', ref $e1);
    };
    catch my $e, ['Exception::Fatal'];

    # tear down
    close $fh_in;
}

sub test_untaint {
    my $self = shift;

    # set up
    open $fh_in, '<', $filename_in or throw 'Exception::IO';

    my $obj = IO::Moose::Handle->new;
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $obj->fdopen($fh_in, 'r');
    $self->assert_not_null($obj);
    $self->assert($obj->isa("IO::Moose::Handle"), '$obj->isa("IO::Moose::Handle")');
    $self->assert_equals('GLOB', reftype $obj);

    my $c1 = $obj->getline;
    $self->assert_not_equals('', $c1);

    if (${^TAINT}) {
	no warnings;
        eval { kill 0 * $c1 };
	$self->assert_not_equals('', $@);
    }

    my $c2 = $obj->untaint;
    $self->assert($c2, '$obj->untaint');

    my $c3 = $obj->getline;

    if (${^TAINT}) {
	no warnings;
        kill 0 * $c3;
    }

    my $c4 = $obj->taint;
    $self->assert($c4, '$obj->taint');

    my $c5 = $obj->getline;
    $self->assert_not_equals('', $c5);

    if (${^TAINT}) {
	no warnings;
        eval { kill 0 * $c5 };
	$self->assert_not_equals('', $@);
    }

    $obj->close;

    try eval { $obj->untaint; };
    catch my $e1;
    # Bad file descriptor
    $self->assert_equals('Exception::Fatal', ref $e1);

    # tear down
    close $fh_in;
}

1;
