use warnings;
use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Socket;
use Fcntl qw(:flock);
use lib ( sprintf('%s/.irssi/scripts/lib/', $ENV{HOME} ) );

$VERSION = '0.0.1';
%IRSSI = (
	authors     => 'rfi',
	contact     => 'rfi@remotefileinclude.net',
	name        => 'irssi_message_client',
	description => 'Write a notification to a message server listening on a unix socket',
	url         => 'https://github.com/remotefileinclude',
	license     => 'GNU General Public License',
	changed     => '$Date: 2012-11-12 12:00:00 +0100 (Mon, 12 Nov 2012) $'
);

sub PIDFILE    { sprintf('%s/.irssi/scripts/sq.pid', $ENV{HOME} );  }
sub SQ_SOCKET  { sprintf('%s/.irssi/scripts/sq.socket', $ENV{HOME} ); }

sub priv_msg {
	my ($server,$msg,$nick,$address,$target) = @_;
	socket_write( sprintf('%s %s', $nick, $msg ) );
}

sub hilight {
    my ($dest, $text, $stripped) = @_;
    if ($dest->{level} & MSGLEVEL_HILIGHT) {
	    socket_write( sprintf('%s %s', $dest->{target}, $stripped ) );
    }
}

sub socket_write {
    my ( $text ) = @_;

    ensure_server();
    
    my $sock_addr = sockaddr_un( SQ_SOCKET );
    socket( my $server, PF_UNIX,SOCK_STREAM,0 ) or die "socket: $!";
    connect( $server, $sock_addr ) or die "connect: $!";
    
    print $server $text; 
    close $server; 

}

sub ensure_server {

    if ( _can_lock_pid() ) {
        if ( my $pid = fork() ) {
            return 1;
        }
        else {
            die 'annot fork' unless defined $pid;

            use SimpleQueue::Server;

            open my $pid_f, '>', PIDFILE or die "Can't open pid file: $!";    
            flock( $pid_f, LOCK_EX | LOCK_NB ) or return 0; 
            print $pid_f $$ ;

            my $message_server = SimpleQueue::Server->new( 
                socket_path => SQ_SOCKET 
            );

            $message_server->run(); 

            close $pid_f;

        }
    }

}

sub _can_lock_pid {
    open  my $pid_f, '<', PIDFILE or die "Can't open pid file: $!";    
    flock( $pid_f, LOCK_EX | LOCK_NB ) or return 0;
    close $pid_f ;
    return 1;
}

Irssi::signal_add_last("message private", "priv_msg");
Irssi::signal_add_last("print text", "hilight");
