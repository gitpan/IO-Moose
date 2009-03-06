#!/usr/bin/perl

use lib 'lib', '../lib';

use Benchmark ':all';

cmpthese( timethese( $ARGV[0] || -1, {

    '1_CoreIO' => sub {

        package My::CoreIO;
        open my($fi), $0;
        my @file;
        while (defined (my $line = <$fi>)) {
            chomp $line;
            push @file, $line;
        };
        close $fi;
        open my($fo), '/dev/null';
        foreach (@file) {
            print $fo, "\n";
        };
        close $fo;

    },
    '2_IOFile' => sub {

        package My::IOFile;
        use IO::File ();
        my $fi = IO::File->new($0);
        my @file = $fi->getlines;
        foreach (@file) {
            chomp;
        };
        $fi->close;
        my $fo = IO::File->new('/dev/null', 'w');
        foreach (@file) {
           $fo->print($_, "\n");
        };
        $fo->close;
    
    },
    '3_IOMooseFile' => sub { 

        package My::IOMooseFile;
        use IO::Moose::File ();
        my @file = IO::Moose::File->new( file => $0, autochomp => 1 )->getlines;
        my $fo = IO::Moose::File->new( file => '/dev/null', mode => 'w' );
        foreach (@file) {
            $fo->say($_);
        };
        $fo->close;

    },

} ) );
