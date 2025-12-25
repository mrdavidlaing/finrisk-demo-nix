#!/usr/bin/env perl
# TransferX Audit Service
# Legacy transaction logging service written in Perl
# "Been running since 1998. Don't ask questions."

use strict;
use warnings;
use JSON;
use IO::Socket::INET;

# Enable auto-flush for stdout and stderr so logs appear in real-time
$| = 1;
STDOUT->autoflush(1);
STDERR->autoflush(1);

my $PORT = $ENV{PORT} || 8084;
my $LOG_DIR = $ENV{LOG_DIR} || '/tmp/transferx-audit';

# Ensure log directory exists
mkdir $LOG_DIR unless -d $LOG_DIR;

# Create server socket
my $server = IO::Socket::INET->new(
    LocalPort => $PORT,
    Type => SOCK_STREAM,
    Reuse => 1,
    Listen => 10
) or die "Cannot create server socket: $!\n";

print "Audit Service listening on port $PORT\n";
STDOUT->flush();

while (my $client = $server->accept()) {
    handle_client($client);
    close $client;
}

sub handle_client {
    my ($client) = @_;
    my $request = '';
    
    # Read request
    while (<$client>) {
        $request .= $_;
        last if $_ eq "\r\n" or $_ eq "\n";
    }
    
    # Read body if POST
    my $content_length = 0;
    if ($request =~ /Content-Length:\s*(\d+)/i) {
        $content_length = $1;
        read($client, my $body, $content_length);
        $request .= $body;
    }
    
    # Parse request
    my ($method, $path) = $request =~ /^(\w+)\s+(\S+)/;
    $path ||= '/';
    
    # Route request
    if ($path eq '/health' && $method eq 'GET') {
        send_response($client, handle_health());
    } elsif ($path eq '/log' && $method eq 'POST') {
        my $body = '';
        if ($request =~ /\r\n\r\n(.*)$/s) {
            $body = $1;
        }
        send_response($client, handle_log($body));
    } elsif ($path eq '/transactions' && $method eq 'GET') {
        send_response($client, handle_list_transactions());
    } else {
        send_response($client, encode_json({ error => 'Not found' }), 404);
    }
}

sub send_response {
    my ($client, $body, $status) = @_;
    $status ||= 200;
    my $status_text = $status == 200 ? 'OK' : 'Not Found';
    
    print $client "HTTP/1.0 $status $status_text\r\n";
    print $client "Content-Type: application/json\r\n";
    print $client "Access-Control-Allow-Origin: *\r\n";
    print $client "Content-Length: " . length($body) . "\r\n";
    print $client "\r\n";
    print $client $body;
}

sub handle_health {
    return encode_json({
        status => 'healthy',
        service => 'audit-service',
        language => 'Perl',
        version => $^V
    });
}

sub handle_log {
    my ($json_text) = @_;
    return encode_json({ error => 'Invalid request' }) unless $json_text;
    
    my $data = eval { decode_json($json_text) };
    if ($@) {
        print STDERR "[audit-service] ERROR: Invalid JSON in log request: $@\n";
        return encode_json({ error => 'Invalid JSON' });
    }
    
    # Log transaction to file
    my $timestamp = time();
    my $date = scalar localtime();
    my $log_file = "$LOG_DIR/transactions.log";
    
    my $log_entry = sprintf(
        "[%s] TRANSFER: %s -> %s, Amount: %.2f %s, Rail: %s, ID: %s",
        $date,
        $data->{senderId} || 'unknown',
        $data->{recipientId} || 'unknown',
        $data->{amount} || 0,
        $data->{currency} || 'USD',
        $data->{rail} || 'UNKNOWN',
        $data->{transferId} || 'N/A'
    );
    
    # Log to stdout for docker logs (with flush to ensure real-time visibility)
    print "[audit-service] $log_entry\n";
    STDOUT->flush();
    
    # Also log to file
    open(my $fh, '>>', $log_file) or do {
        print STDERR "[audit-service] ERROR: Cannot open log file $log_file: $!\n";
        STDERR->flush();
        return encode_json({ error => "Cannot open log file: $!" });
    };
    print $fh "$log_entry\n";
    close($fh);
    
    return encode_json({
        success => 1,
        logged => 1,
        timestamp => $timestamp,
        logFile => $log_file
    });
}

sub handle_list_transactions {
    my @transactions = ();
    my $log_file = "$LOG_DIR/transactions.log";
    
    if (-f $log_file) {
        open(my $fh, '<', $log_file) or return encode_json({ error => "Cannot read log file: $!" });
        while (my $line = <$fh>) {
            chomp $line;
            push @transactions, { logEntry => $line };
        }
        close($fh);
    }
    
    return encode_json({
        transactions => \@transactions,
        count => scalar @transactions
    });
}
