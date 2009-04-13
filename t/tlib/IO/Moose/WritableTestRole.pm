package IO::Moose::WritableTestRole;

use Moose::Role;

with 'IO::Moose::WritableFilenameTestRole';
with 'IO::Moose::HasObjectTestRole';

use Test::Assert ':all';

has fh_out => (
    is      => 'rw',
    isa     => 'GlobRef',
    clearer => 'clear_fh_out'
);

around set_up => sub {
    my ($super, $self) = @_;

    my $return = $self->$super();

    open my $fh_out, '>', $self->filename_out or Exception::IO->throw;
    $self->fh_out($fh_out);

    return $return;
};

around tear_down => sub {
    my ($super, $self) = @_;

    close $self->fh_out;
    $self->clear_fh_out;

    return $self->$super();
};

1;
