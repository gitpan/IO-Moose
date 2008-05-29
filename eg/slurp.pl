#!/usr/bin/perl -I../lib

# Usage: slurp file

BEGIN { eval 'use Smart::Comments;' if $ENV{DEBUG}; }
BEGIN { $IO::Moose::Handle::Debug   = $ENV{DEBUG}; }
BEGIN { $IO::Moose::Seekable::Debug = $ENV{DEBUG}; }
BEGIN { $IO::Moose::File::Debug     = $ENV{DEBUG}; }

### BEGIN

use IO::Moose::File;

eval {
    ### $ARGV[0]: $ARGV[0]
    my $file = IO::Moose::File->slurp( $ARGV[0] );
    ### $file: $file
};

### $@: "$@"

### END
