package SimpleQueue::Server; 
  
use strict;
use warnings;

use IO::Socket;
use IO::Select;
use Socket;
use Log::Log4perl qw| :easy |;
use Carp;
use SimpleQueue::Common qw| sq_encode |;

sub new {
    my ( $class, %args ) = @_;

    my %defaults = (
        port        => 3682, 
        timeout     => 20,
        socket_path => '/var/run/simple_message.socket'
    );

    foreach my $arg ( keys %defaults ) {
        $args{$arg} ||= $defaults{$arg} 
    } 

    my %set_args = (
        #interface    => sub { return 1 }, # TODO
        port         => sub { ( $_[0] =~ /^\d+$/  ) or croak "port must be a number"  },
        timeout      => sub { ( $_[0] =~ /^\d+$/  ) or croak "timeout must be a number"  },
        socket_path  => sub { return 1 }, # TODO
        log_file     => sub { return 1 }  # TODO
    );

    foreach my $set_arg ( keys %set_args ) {
        $args{$set_arg} or croak "Must set $set_arg";
        $set_args{$set_arg}->( $args{$set_arg} ) ;
    }

    $args{client_select}   = IO::Select->new();
    $args{message_select}  = IO::Select->new();
    $args{client_tracking} = {};

    return bless \%args, $class; 

}

sub run {
    my ( $self ) = @_;

    $self->_setup_message_socket();
    $self->_setup_client_socket();
    $self->_run_main_loop();

}

sub _setup_message_socket {
    my ( $self ) = @_;

    unlink $self->{socket_path};

    my $message_queue = IO::Socket::UNIX->new(
       Local     => $self->{socket_path},
       Type      => SOCK_STREAM,
       Listen    => 5 ,
       Blocking  => 0 
    ) or croak "Could not create message socket: $!";
    
    $message_queue->autoflush(1);
    
    $self->{message_socket}  = $message_queue;
    $self->{message_select}->add($message_queue);
 
}

sub _setup_client_socket {
    my ( $self ) = @_; 

    my $clients = IO::Socket::INET->new(
        LocalPort => $self->{port},
        Proto     => 'tcp',
        Type      => SOCK_STREAM,
        Reuse     => 1,
        Listen    => 10
    ) or croak "Could not open listener socket!: $!";

    $self->{client_socket} = $clients;
    $self->{client_select}->add($clients);         


}

sub _run_main_loop {
    my ( $self ) = @_;

    if ( $self->{log_file} ) {
        Log::Log4perl->easy_init({ 
            level   => $DEBUG,
            file    => $self->{log_file}
        });

    }

    while (1) {

        my ($incoming) = 
            IO::Select->select( $self->{message_select}, undef, undef, 1 );

        my @messages ;

        # This loop gets incoming messages sent to the servers socket
        foreach my $socket ( @{$incoming} ) {
            if ( $socket == $self->{message_socket} ) {
                 my $active = $self->{message_socket}->accept();  
                 $self->{message_select}->add($active); 
            }
	        elsif ( my $message = do { local $/ = undef ; <$socket> } ) {
                 push( @messages, $message . "\n"  )	
            }
        }

        my ( $outgoing_r, $outgoing_w ) = 
            IO::Select->select( $self->{client_select}, $self->{client_select}, undef, 1 );

        # This loop deals with commands sent from the clients
        foreach my $subscriber ( @{$outgoing_r} ) {   
            if ( $subscriber == $self->{client_socket} )  {
                  INFO("Got new client: "  . $subscriber->peerhost  );
                  my $active = $self->{client_socket}->accept();  
                  $self->{client_select}->add($active);    
            }
            else  {
            
                sysread($subscriber, my $inline, 4064);

	            if ( !$inline ) {
                     INFO("Lost client: " . $subscriber->peerhost );
                     $self->{client_select}->remove($subscriber);
                     delete $self->{client_tracking}->{"$subscriber"};
                }
                elsif ( $inline eq "ping" ) {
	                 $self->{client_tracking}->{"$subscriber"}->{last_ping} = time ;	
	    	         print $subscriber "pong";
                }
                elsif ( $inline eq "quit" ) {
                     INFO("Client Quit: " . $subscriber->peerhost ); 
                     $self->{client_select}->remove($subscriber); 
                     delete $self->{client_tracking}->{"$subscriber"};
                }
	            else {
                     #print "unknown cmd: $inline\n"
                }
            }
            
        }

        # This loop deals with sending messages to the client
        foreach my $subscriber ( @{$outgoing_w} ) {   
            if ( @messages ) {
                foreach my $message ( @messages ) {
            
                    DEBUG("Got message: $message");
                    my $packed_message = sq_encode($message);

                    print $subscriber $packed_message;
                }
            }

            if ( $self->_client_timeout($subscriber ) ){
                INFO("Client timeout: " . $subscriber->peerhost ); 
                $self->{client_select}->remove($subscriber); 
                delete $self->{client_tracking}->{"$subscriber"};
            }  
            elsif ( ! $self->{client_tracking}->{"$subscriber"} ) {
                $self->{client_tracking}->{"$subscriber"}->{last_ping} = time ;	
            }
 
        }      

        sleep(1);

    }
 
}

sub _client_timeout {
    my ( $self, $client ) = @_;

    if ( $self->{client_tracking}->{"$client"} ) { 
         return 1 
            if ( time - $self->{client_tracking}->{"$client"}->{last_ping} ) 
                  > $self->{timeout}
    }

    return 0;
}

1;
