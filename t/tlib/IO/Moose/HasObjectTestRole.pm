package IO::Moose::HasObjectTestRole;

use Moose::Role;

use Test::Assert ':all';

has obj => (
    is        => 'rw',
    isa       => 'IO::Moose::Handle',
    clearer   => 'clear_obj'
);

around set_up => sub {
    my ($super, $self) = @_;

    (my $class = blessed $self) =~ s/::\w*Test//;

    my $obj = $class->new;
    assert_isa($class, $obj);
    $self->obj($obj);

    return $self->$super();
};

around tear_down => sub {
    my ($super, $self) = @_;

    $self->clear_obj;

    return $self->$super();
};

1;
