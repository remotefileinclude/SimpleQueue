#!/usr/bin/perl

use strict;
use warnings;
use Growl::GNTP; 
use lib qw|./lib|;

use SimpleQueue::Client;

my $growl = Growl::GNTP->new(
                AppName => 'irssi_notifier', 
                PeerPort => 23053, 
                Password => 'testtest'
            );
$

my $client = SimpleQueue::Client->new(
                host     => '',
                callback => sub { growl_notify($_[0]) }
             );

$client->run(); 


sub growl_notify {
    my ( $message ) = @_;

    $growl->notify(
        Event   => "test_ev", 
        Title   => "PL notify", 
        Message => $message 
    );
}
