package IO::MooseTest;

use strict;
use warnings;

use base 'Test::Unit::TestCase';

sub test_import_good {
    my $self = shift;
    eval 'use IO::Moose qw< IO_MooseTest_Good >;';
    $self->assert_equals('', $@);
    $self->assert_equals('12345', IO::Moose::IO_MooseTest_Good->VERSION);
}

sub test_import_bad {
    my $self = shift;
    eval 'use IO::Moose qw< IO_MooseTest_Bad >;';
    $self->assert_not_equals('', $@);
}

sub test_import_missing {
    my $self = shift;
    eval 'use IO::Moose qw< IO_MooseTest_Missing >;';
    $self->assert_not_equals('', $@);
}

sub test_import_all {
    my $self = shift;
    eval 'use IO::Moose;';
    $self->assert_equals('', $@);
}

1;
