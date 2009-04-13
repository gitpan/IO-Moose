package IO::Moose::ReadableFilenameTestRole;

# The size of this file has meaning for some tests.

use Moose::Role;

has filename_in => (
    is      => 'rw',
    isa     => 'Str'
);

around set_up => sub {
    my ($super, $self) = @_;

    my $filename_in = __FILE__;
    $self->filename_in($filename_in);

    return $self->$super();
};

1;
