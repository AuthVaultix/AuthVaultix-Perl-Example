package AuthVaultix;
use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use POSIX qw(strftime);
#  Global Vars (Static style)
my $BASE_URL = "https://api.authvaultix.com/api/1.2/";
our $AppInitialized = "no";
our $SessionID = "none";
our ($Name, $OwnerID, $Secret, $Version);
our %AppInfo;
our %UserData;
#  API Setup
sub Api {
    my ($name, $ownerid, $secret, $version) = @_;
    unless ($name && $ownerid && $secret && $version) {
        die "Missing API credentials.\n";
    }
    $Name    = $name;
    $OwnerID = $ownerid;
    $Secret  = $secret;
    $Version = $version;
}
#  Init
sub Init {
    my %payload = (
        type     => "init",
        name     => $Name,
        ownerid  => $OwnerID,
        secret   => $Secret,
        ver      => $Version   # API expects "ver", not "version"
    );

    my $resp = _send_request(\%payload);

    if ($resp->{success}) {
        $AppInitialized = "yes";
        $SessionID = $resp->{sessionid};
        %AppInfo = %{ $resp->{appinfo} };
        print "Initialized Successfully!\n";
    } else {
        die "Init Failed: $resp->{message}\n";
    }
}
#  Handle Response
sub _handle_response {
    my ($resp, $msg) = @_;

    if (!$resp) {
        die "No response from server\n";
    }

    if ($resp->{success}) {
        %UserData = %{ $resp->{info} };
        print "$msg\n";
        _print_user_info();
    } else {
        die "Error: $resp->{message}\n";
    }
}
#  Login
sub Login {
    my ($username, $password) = @_;
    _check_init();

    my %payload = (
        type      => "login",
        sessionid => $SessionID,
        username  => $username,
        pass      => $password,
        hwid      => _get_hwid(),
        name      => $Name,
        ownerid   => $OwnerID
    );

    my $resp = _send_request(\%payload);   #  endpoint removed
    _handle_response($resp, "Logged in!");
}
#  Register
sub Register {
    my ($username, $password, $license) = @_;
    _check_init();

    my %payload = (
        type      => "register",
        sessionid => $SessionID,
        username  => $username,
        pass      => $password,
        key       => $license,   # MUST be "key"
        hwid      => _get_hwid(),
        name      => $Name,
        ownerid   => $OwnerID
    );

    my $resp = _send_request(\%payload);   #  endpoint removed
    _handle_response($resp, "Registered Successfully!");
}
#  License Login
sub License {
    my ($license) = @_;
    _check_init();

    my %payload = (
        type      => "license",
        sessionid => $SessionID,
        key       => $license,
        hwid      => _get_hwid(),
        name      => $Name,
        ownerid   => $OwnerID
    );

    my $resp = _send_request(\%payload);
    _handle_response($resp, "License Login Successful!");
}
#  Private Helpers
sub _send_request {
    my ($payload_ref) = @_;

    my $ua = LWP::UserAgent->new(
        ssl_opts => { verify_hostname => 0 }
    );

    my $response = $ua->post(
        $BASE_URL,   # ONLY base URL
        Content_Type => 'application/x-www-form-urlencoded',
        Content      => $payload_ref
    );

    if ($response->is_success) {
        my $raw = $response->decoded_content;

        my $json = eval { decode_json($raw) };
        if ($@) {
            die "Invalid JSON from server:\n$raw\n";
        }

        return $json;
    }
    else {
        die "HTTP Request Failed: " . $response->status_line . "\n";
    }
}

sub _print_user_info {
    print "\n👤 User Info:\n";
    print " Username: $UserData{username}\n" if $UserData{username};
    print " IP: $UserData{ip}\n" if $UserData{ip};
    print " HWID: $UserData{hwid}\n" if $UserData{hwid};
    print " Created: " . _format_time($UserData{createdate}) . "\n" if $UserData{createdate};

    if (ref($UserData{subscriptions}) eq 'ARRAY') {
        print "\n Subscriptions:\n";
        foreach my $sub (@{ $UserData{subscriptions} }) {
            print "  → $sub->{subscription} | Expiry: " . _format_time($sub->{expiry}) .
                  " | Left: $sub->{timeleft}s\n";
        }
    }
    print "\n";
}

sub _check_init {
    die "Please initialize app before using login/register/license.\n"
      unless $AppInitialized eq "yes";
}

sub _get_hwid {
    my $hwid = `wmic useraccount where name='%username%' get sid /value 2>nul`;
    $hwid =~ s/SID=//;
    chomp($hwid);
    return $hwid || "UNKNOWN_HWID";
}

sub _format_time {
    my ($unix) = @_;
    return strftime("%d-%m-%Y %H:%M:%S", localtime($unix));
}

1;
