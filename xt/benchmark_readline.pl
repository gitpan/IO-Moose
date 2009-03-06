#!/usr/bin/perl

use lib 'lib', '../lib';

use Benchmark ':all';

cmpthese( timethese( $ARGV[0] || -1, {

    '1_CoreIO' => sub {

        package My::CoreIO;
        BEGIN {
            open our($io), '-|', 'yes', 'A' x 100;
        };
        die unless defined(my $line = <$io>);
        chomp $line;
        die $line if length($line) ne 100;

    },
    '2_IOHandle' => sub {

        package My::IOHandle;
        use IO::Handle ();
        BEGIN {
            open our($pipe), '-|', 'yes', 'A' x 100;
            our $io = IO::Handle->new_from_fd( $pipe, 'r' );
        };
        die unless defined(my $line = $io->getline);
        chomp $line;
        die $line if length($line) ne 100;
    
    },
    '3_IOMooseHandleTiedOO' => sub { 

        package My::IOMooseHandleTiedOO;
        use IO::Moose::Handle ();
        BEGIN {
            open our($pipe), '-|', 'yes', 'A' x 100;
            our $io = IO::Moose::Handle->new( file => $pipe, mode => 'r', copyfh => 1, tied => 1 );
        };
        die unless defined(my $line = $io->readline);
        chomp $line;
        die $line if length($line) ne 100;

    },
    '4_IOMooseHandleTiedOOStrict' => sub { 

        package My::IOMooseHandleTiedOOStrict;
        use IO::Moose::Handle ();
        BEGIN {
            open our($pipe), '-|', 'yes', 'A' x 100;
            our $io = IO::Moose::Handle->new( file => $pipe, mode => 'r', copyfh => 1, tied => 1, strict_accessors => 1 );
        };
        die unless defined(my $line = $io->readline);
        chomp $line;
        die $line if length($line) ne 100;

    },
    '5_IOMooseHandleNonTiedOO' => sub { 

        package My::IOMooseHandleNonTiedOO;
        use IO::Moose::Handle ();
        BEGIN {
            open our($pipe), '-|', 'yes', 'A' x 100;
            our $io = IO::Moose::Handle->new( file => $pipe, mode => 'r', copyfh => 1, tied => 0 );
        };
        die unless defined(my $line = $io->readline);
        chomp $line;
        die $line if length($line) ne 100;

    },
    '6_IOMooseHandleTiedFunc' => sub { 

        package IOMooseHandleTiedFunc;
        use IO::Moose::Handle ();
        BEGIN {
            open our($pipe), '-|', 'yes', 'A' x 100;
            our $io = IO::Moose::Handle->new( file => $pipe, mode => 'r', copyfh => 1, tied => 1 );
        };
        die unless defined(my $line = <$io>);
        chomp $line;
        die $line if length($line) ne 100;

    },

} ) );
