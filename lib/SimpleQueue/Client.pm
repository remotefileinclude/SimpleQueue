package SimpleQueue::Client;
  
use strict;
use warnings;

use IO::Socket;
use IO::Select;
use Socket;
use Log::Log4perl qw| :easy |;
use Carp;
use SimpleQueue::Common qw|sq_decode|;

our $PING_INT = 10;

sub new {
    my ( $class, %args ) = @_;

    my %defaults = (
        host     => 'localhost',
        port     => 3682, 
        callback => sub { printf( "message:\n\n%s\n", $_[0] ) } ,
        timeout  => 10,
    );

    foreach my $arg ( keys %defaults ) {
        $args{$arg} ||= $defaults{$arg} 
    } 

    my %set_args = (
        host     => sub { return 1 },
        port     => sub { ( 65000 > $_[0]  ) or croak "port must be a number" },
        callback => sub { ( ref($_[0]) eq 'CODE') or croak "callback must be coderef"  },
        timeout  => sub { ( $_[0] =~ /^\d+$/  ) or croak "timeout must be a number"  }
    );

    foreach my $set_arg ( keys %set_args ) {
        $args{$set_arg} or croak "Must set $set_arg";
        $set_args{$set_arg}->( $args{$set_arg} ) ;
    }

    $args{select_loop} = IO::Select->new();
    $args{since_ping}  = {};

    return bless \%args, $class;
}

sub run {
    my ( $self ) = @_;

    $self->_setup_server_conn();
    $self->_run_main_loop();
}

sub _setup_server_conn {
    my ( $self ) = @_;

    my $message_client = new IO::Socket::INET (
        PeerAddr => $self->{host},
        PeerPort => $self->{port},
        Proto => 'tcp',
    ) or die "Could not create socket: $!";

    $message_client->autoflush(1);
 
    $self->{select_loop}->add($message_client); 
}

sub _run_main_loop {
    my ( $self ) = @_;

    while (1) {
        TRACE("Checking for messages");
        my ($incoming,$outgoing) = 
            IO::Select->select( $self->{select_loop}, $self->{select_loop}, undef, 1);

        foreach my $server ( @{$incoming} ) {
	        TRACE("Got message");
            
            my $message = sq_decode($server) ; 

            if (!$message) {
                ERROR("Lost server");
                $self->{select_loop}->remove($server);
                exit;
            } 

            $self->{callback}->($message) ;
        }  
 
        foreach my $server ( @{$outgoing} ) {

            if ( $self->{since_ping}->{"$server"}++ > $PING_INT ) {
                TRACE("ping");
                print $server "ping";
	            eval {
                    local $SIG{ALRM}  = sub { die "ping timeout"};
                    alarm $self->{timeout};
                    sysread( $server, my $pong, 4 );
	    	        croak "no pong" unless ( $pong && ($pong eq 'pong'));

	    	        print "$pong\n";
                    alarm 0;
                    $self->{since_ping}->{"$server"} = 0;
                };
                if ($@) {
                    $self->{select_loop}->remove($server);
                    ERROR("Server error $@");
                    exit;
	            }
            }
        }
        
    sleep(1);   
    }
}

1;


__END__

=pod

=head1 NAME

SimpleQueue::Client

=head1 METHODS

=head2 new

=head2 run

=cut
