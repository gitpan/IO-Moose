#!/usr/bin/perl -c

package IO::Moose;
use 5.006;
our $VERSION = 0.03;

=head1 NAME

IO::Moose - Moose reimplementation of IO::* with improvements

=head1 SYNOPSIS

  use IO::Moose qw< Handle File >;  # loads IO::Moose::* modules

  $fh = new IO::Moose::File '/etc/passwd';
  $passwd = $fh->slurp;
  $fh->close;

=head1 DESCRIPTION

B<IO::Moose> provides a simple mechanism to load several modules in one go.

B<IO::Moose::*> classes provide an interface mostly compatible with L<IO>. 
The differences:

=over

=item *

It is based on L<Moose> object framework.

=item *

It uses L<Exception::Base> for signaling errors. Most of methods are throwing
exception on failure.

=item *

The modifiers like B<input_record_separator> are supported on per-filehandler
basis.

=item *

It also implements additional methods like B<say>, B<slurp>.

=item *

It is pure-Perl implementation.

=back

=cut


use Exception::Base
    'Exception::Fatal::Compilation' => { isa => 'Exception::Base' };

sub import {
    shift;

    my @l = @_ ? @_ : qw< Handle >;

    eval join("", map { "require IO::Moose::" . (/(\w+)/)[0] . ";\n" } @l)
        or throw Exception::Fatal::Compilation
              ignore_package => __PACKAGE__;
}


1;


__END__

=for readme stop

=head1 IMPORTS

=over

=item use IO::Moose [I<modules>]

Loads a modules from B<IO::Moose::*> hierarchy.  I.e. B<Handle> parameter
loads B<IO::Moose::Handle> module.  

  use IO::Moose 'Handle', 'File';  # loads IO::Moose::Handle and ::File.

If I<modules> list is empty, it loads following modules at default:

=over

=item * IO::Moose::Handle

=back

=back

=head1 SEE ALSO

L<IO>, L<Moose>.

=head1 BUGS

The API is not stable yet and can be changed in future.

=for readme continue

=head1 AUTHOR

Piotr Roszatycki E<lt>dexter@debian.orgE<gt>

=head1 LICENSE

Copyright 2008 by Piotr Roszatycki E<lt>dexter@debian.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
