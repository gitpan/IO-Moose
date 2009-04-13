package IO::Moose::WritableFilenameTestRole;

use Moose::Role;

use Test::Assert ':all';

use File::Spec ();
use File::Temp ();

has filename_out => ( 
    is        => 'rw',
    isa       => 'Str',
    clearer   => 'clear_filename_out',
    predicate => 'has_filename_out'
);

around set_up => sub {
    my ($super, $self) = @_;

    my (undef, $filename_out) = File::Temp::tempfile( 'XXXXXXXX', DIR => File::Spec->tmpdir );
    assert_not_null($filename_out);
    $self->filename_out($filename_out);

    return $self->$super();
};

around tear_down => sub {
    my ($super, $self) = @_;

    unlink $self->filename_out if $self->has_filename_out;

    return $self->$super();
};

1;
