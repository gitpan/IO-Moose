package IO::Moose::ReadableTestRole;

use Moose::Role;

with 'IO::Moose::ReadableFilenameTestRole';
with 'IO::Moose::HasObjectTestRole';

use Test::Assert ':all';

has fh_in => (
    is      => 'rw',
    isa     => 'GlobRef',
    clearer => 'clear_fh_in'
);

around set_up => sub {
    my ($super, $self) = @_;

    my $return = $self->$super();

    open my $fh_in, '<', $self->filename_in or Exception::IO->throw;
    $self->fh_in($fh_in);

    return $return;
};

around tear_down => sub {
    my ($super, $self) = @_;

    close $self->fh_in;
    $self->clear_fh_in;

    return $self->$super();
};

1;
