package IO::Moose::ReadableOpenedTestRole;

use Moose::Role;

with 'IO::Moose::ReadableTestRole';

use Test::Assert ':all';

has vars => (
    is  => 'rw',
    isa => 'ArrayRef'
);

around set_up => sub {
    my ($super, $self) = @_;

    my $return = $self->$super();

    $self->obj->fdopen($self->fh_in, 'r');
    assert_true($self->obj->opened);

    $self->vars( [ $/ ] );

    return $return;
};

around tear_down => sub {
    my ($super, $self) = @_;

    ( $/ ) = @{ $self->vars };

    return $self->$super();
};

1;
