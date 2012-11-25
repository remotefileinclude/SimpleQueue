#!/usr/bin/perl

use strict;
use warnings;
use Test::More;
use Fcntl qw| O_RDONLY |;
use lib qw|./lib|;
use SimpleQueue::Common qw| sq_decode sq_encode |;

my $message = "Hello world test message \n";
my $message_length = do { use bytes; length($message) };

#my $encoded_message

my @TESTS = (
    sub {
        no strict 'refs';
        ok( ref( *main::sq_decode{CODE} ) eq 'CODE', "sq_decode exported" );
    },
    sub {
        no strict 'refs';
        ok( ref( *main::sq_encode{CODE} ) eq 'CODE', "sq_encode exported" );
    },  
    sub {
        my $encoded = sq_encode($message) ;

        my ($m_length) = unpack("N", $encoded); 
        ok( $m_length == $message_length,  "Messange length encoded correctly")
    },
    sub {
        my $encoded = sq_encode($message) ;

        my ( undef, $m_decoded ) = unpack("Na$message_length", $encoded); 
        ok( $m_decoded eq $message,  "Messange encoded correctly") 
    },
    sub {
        my $encoded = sq_encode($message) ; 
       
        pipe(my $read, my $write);
        {
            my $ofh = select $write;
            $/ = undef;
            select $ofh;
        }
        syswrite($write, $encoded );
        my $decoded = sq_decode($read) ;
        ok ( $decoded eq $message, "Message decoded from handle with sq_decode");
        close $write;
        close $read;
    }
);

plan tests => scalar(@TESTS);

$_->() foreach (@TESTS);

