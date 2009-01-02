#!/usr/bin/perl -Ilib -I../lib

# Usage: slurp file

use if $ENV{PERL_DEBUG}, 'Smart::Comments';

### BEGIN

use IO::Moose::File;

### $ARGV[0]: $ARGV[0]
my $file = IO::Moose::File->slurp( file => $ARGV[0] || die "Usage: $0 *file*\n" );
### $file: $file
print $file;

### $@: "$@"

### END
