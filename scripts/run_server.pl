#!/usr/bin/perl 

use strict;
use warnings;

use lib qw| ./lib |;
use SimpleQueue::Server;

my $message_server = SimpleQueue::Server->new( socket_path => "/tmp/socket.unix");

$message_server->run();
