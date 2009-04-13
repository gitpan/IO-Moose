package IO::Moose::WritableOpenedTestRole;

use Moose::Role;

with 'IO::Moose::WritableTestRole';

use Test::Assert ':all';

has vars => (
    is  => 'rw',
    isa => 'ArrayRef'
);

around set_up => sub {
    my ($super, $self) = @_;

    my $return = $self->$super();

    $self->obj->fdopen($self->fh_out, 'w');
    assert_true($self->obj->opened);

    $self->vars( [ $=, $-, $~, $^, $^L, $\, $, ] );

    return $return;
};

around tear_down => sub {
    my ($super, $self) = @_;

    ( $=, $-, $~, $^, $^L, $\, $, ) = @{ $self->vars };

    return $self->$super();
};

1;
