#!/usr/bin/perl

use strict;
use warnings;
use lib qw|./lib|;

use SimpleQueue::Client;


my $client = SimpleQueue::Client->new();

$client->run();
