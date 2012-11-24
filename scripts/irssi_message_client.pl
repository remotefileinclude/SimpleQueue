use warnings;
use strict;
use vars qw($VERSION %IRSSI);

use Irssi;
use Socket;
use Fcntl qw(:flock O_RDONLY O_CREAT O_WRONLY );
use POSIX qw|getpid|;

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

ensure_server(); 

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
        $SIG{CHLD} = 'IGNORE';
        if ( my $pid = fork() ) {
            END {
                kill 15, $pid;
            }
            return 1;
        }
        else {
            die 'Cannot fork' unless defined $pid;
           
            $SIG{INT} = $SIG{HUP} = sub { CORE::exit(0) };
            close STDOUT;
            close STDIN;
            close STDERR;
            
            my $LOG_FILE = sprintf('%s/.irssi/scripts/sq.log', $ENV{HOME} ); 

            my $pid_f = _write_pid();

            require SimpleQueue::Server;
            SimpleQueue::Service->import();

            my $message_server = SimpleQueue::Server->new( 
                socket_path => SQ_SOCKET 
            );

            $message_server->run(); 
            
            close $pid_f;
            CORE::exit(0)

        }
    }

}

sub _can_lock_pid {
    sysopen( my $pid_f, PIDFILE, O_RDONLY | O_CREAT ) or return 0;
    flock( $pid_f, LOCK_EX | LOCK_NB ) or return 0;
    close $pid_f ;
   
    return 1;
}

sub _write_pid {
    
    sysopen my $pid_f, PIDFILE, O_WRONLY | O_CREAT or die "Can't open pid file: $!"; 
    
    flock( $pid_f, LOCK_EX | LOCK_NB ) or CORE::exit(0); 
    
    {  my $ofh = select $pid_f ;
       $/ = undef;
       select $ofh;
    }

    my $c_pid = get_proc_pid();
    {
        use bytes;
        syswrite($pid_f, $c_pid , length($c_pid), 0 );
    }
    
    return $pid_f;
}

sub get_proc_pid {
    my ($pid) = glob('/proc/self/task/*');
    $pid =~ s/\/.*\///;
    return $pid;
}

sub UNLOAD {
    open my $pid_f, '<', PIDFILE or return;
    my $pid = do { local $/ = undef; <$pid_f> };
    close $pid_f;

    unlink PIDFILE;

    chomp $pid;
    return unless ($pid =~ /^\d+$/);
    kill 15, $pid ;
}

Irssi::signal_add_last("message private", "priv_msg");
Irssi::signal_add_last("print text", "hilight");
