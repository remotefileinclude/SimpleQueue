package SimpleQueue::Common ;

use strict;
use warnings;
use Exporter 'import';

our @EXPORT_OK = qw| sq_encode sq_decode |;

sub sq_encode {
    my ($message) = @_;

    # Message encoding  :
    #
    # - First 32 bits contains an unsigned integer specifying 
    #   the message body length in bytes
    # - Remainder contains the message body
    #
    # Clients must read the first 32 bit interger and then read that
    # interger number bytes to get the message body
    # How terribly with this break outside of ascii encoding?
    my $byte_size      = do { use bytes; length($message) };
	my $packformat     = sprintf('Na%s', $byte_size);
    return pack( $packformat, $byte_size, $message ); 
}


sub sq_decode {
    my ($message_h) = @_;

    # First 32 bits are an unsigned int that contain 
    # the message body length in bytes
    sysread( $message_h, my $bytes, 4);
    my ($length) = unpack("N", $bytes );
       
    if (!$length) {
        return undef;
    }
 
    sysread($message_h, my $p_message, int($length) );

    return unpack( sprintf('a%i',$length), $p_message);  
}


__END__

=pod

=head1 NAME 

SimpleQueue::Common

=head1 SUBROUTINES

=head2 sq_encode

=head2 sq_decode

=cut 
