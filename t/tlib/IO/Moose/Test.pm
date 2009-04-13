package IO::Moose::Test;

use Test::Unit::Lite;

use Moose;
extends 'Test::Unit::TestCase';

use Test::Assert ':all';

use IO::Moose ();

sub test___api {
    my @api = grep { ! /^_/ } @{ Class::Inspector->functions('IO::Moose') };
    assert_deep_equals( [ qw{
        import
    } ], \@api );
};

sub test_import_good {
    my $self = shift;
    IO::Moose->import( 'IO_Moose_Test_Good' );
    assert_equals('12345', IO::Moose::IO_Moose_Test_Good->VERSION);
};

sub test_import_bad {
    my $self = shift;
    assert_raises( qr/Could not load class/, sub {
        IO::Moose->import( 'IO_Moose_Test_Bad' );
    } );
};

sub test_import_missing {
    my $self = shift;
    assert_raises( qr/Could not load class/, sub {
        IO::Moose->import( 'IO_Moose_Test_Missing' );
    } );
};

sub test_import_all {
    my $self = shift;
    IO::Moose->import();
};

1;
