#!/usr/bin/perl

use strict;
use warnings;
use Test::More ;

use lib qw(./lib );

my @LIBS = qw|
    SimpleQueue::Common
    SimpleQueue::Client
    SimpleQueue::Server
|;

my @SCRIPTS = qw|
    irssi_message_client.pl
|;

plan tests => scalar(@LIBS) + scalar(@SCRIPTS);

foreach my $lib (@LIBS) {
    use_ok($lib);
}

foreach my $script (@SCRIPTS) {
    my $output = `$^X -c ./scripts/$script 2>&1`;
    like($output, qr/syntax OK/, "$script compiles");
}
  
