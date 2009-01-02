package IO::MooseTest;

use strict;
use warnings;

use parent 'Test::Unit::TestCase';
use Test::Assert ':all';

use IO::Moose ();

sub test_import_good {
    my $self = shift;
    IO::Moose->import( 'IO_MooseTest_Good' );
    assert_equals('12345', IO::Moose::IO_MooseTest_Good->VERSION);
};

sub test_import_bad {
    my $self = shift;
    assert_raises( qr/Could not load class/, sub {
        IO::Moose->import( 'IO_MooseTest_Bad' );
    } );
};

sub test_import_missing {
    my $self = shift;
    assert_raises( qr/Could not load class/, sub {
        IO::Moose->import( 'IO_MooseTest_Missing' );
    } );
};

sub test_import_all {
    my $self = shift;
    IO::Moose->import();
};

1;
