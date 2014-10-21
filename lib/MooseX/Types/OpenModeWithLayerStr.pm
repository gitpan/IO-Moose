#!/usr/bin/perl -c

package MooseX::Types::OpenModeWithLayerStr;

=head1 NAME

MooseX::Types::OpenModeWithLayerStr - Type for mode string with PerlIO layer

=head1 SYNOPSIS

  package My::Class;
  use Moose;
  use MooseX::Types::OpenModeWithLayerStr;
  has file => ( isa => 'Str' );
  has mode => ( isa => 'OpenModeWithLayerStr' );

  package main;
  my $fout = My::Class->new( file => '/tmp/pwdnew', mode => '>:crlf' );

=head1 DESCRIPTION

This module provides Moose type which represents Perl-style canonical open
mode string (i.e. "+>") with additional PerlIO layer.

=cut


use strict;
use warnings;

our $VERSION = 0.06_01;

use Moose::Util::TypeConstraints;


subtype OpenModeWithLayerStr => (
    as 'Str',
    where { /^\+?(<|>>?):?/ },
    optimize_as {
        defined $_[0] && !ref($_[0])
        && $_[0] =~ /^\+?(<|>>?):?/
    },
);


1;


__END__

=head1 SEE ALSO

L<Moose::Util::TypeConstraints>, L<IO::Moose>, L<perlio>.

=head1 AUTHOR

Piotr Roszatycki E<lt>dexter@debian.orgE<gt>

=head1 LICENSE

Copyright (C) 2007, 2008, 2009 by Piotr Roszatycki E<lt>dexter@debian.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>
