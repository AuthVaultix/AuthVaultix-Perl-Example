package NetworkAgent;
use strict;
use warnings;
use JSON;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

sub post {
    my ($class, $url, $payload) = @_;
    my $ua = LWP::UserAgent->new(
        ssl_opts => { verify_hostname => 0 },
        timeout  => 15
    );
    $ua->agent("AuthVaultixClient/1.0");
    $ua->default_header('Accept' => 'application/json');
    
    my $response = $ua->post($url, Content => $payload);
    
    if ($response->code == 429) {
        print "You're connecting too fast, slow down.\n";
        return undef;
    }
    
    if ($response->is_success) {
        my $json = eval { decode_json($response->decoded_content) };
        if ($@) {
            print "Invalid JSON from server.\n";
            return undef;
        }
        return $json;
    }
    
    print "Request failed: " . $response->status_line . "\n";
    return undef;
}

package PayloadBuilder;
use strict;
use warnings;

sub new {
    my ($class, $action_type) = @_;
    my $self = {
        payload => { type => $action_type }
    };
    bless $self, $class;
    return $self;
}

sub with_context {
    my ($self, $app_name, $owner_id, $session_id) = @_;
    $self->{payload}->{name} = $app_name;
    $self->{payload}->{ownerid} = $owner_id;
    $self->{payload}->{sessionid} = $session_id if defined $session_id && $session_id ne '';
    return $self;
}

sub with_value {
    my ($self, $key, $value) = @_;
    $self->{payload}->{$key} = $value if defined $value;
    return $self;
}

sub compile {
    my ($self) = @_;
    return $self->{payload};
}

package SystemInfoCollector;
use strict;
use warnings;

sub get_os_version {
    if ($^O eq 'MSWin32') {
        my $caption = `powershell -Command "(Get-CimInstance Win32_OperatingSystem).Caption" 2>nul`;
        chomp($caption);
        $caption =~ s/^\s+|\s+$//g;
        if ($caption =~ /^Microsoft /) {
            $caption =~ s/^Microsoft //;
        }

        my $version = `powershell -Command "(Get-CimInstance Win32_OperatingSystem).Version" 2>nul`;
        chomp($version);
        $version =~ s/^\s+|\s+$//g;

        if ($caption eq "" && $version eq "") {
            return "Windows";
        }
        return "$caption ($version)";
    } elsif ($^O eq 'darwin') {
        my $version = `sw_vers -productVersion 2>/dev/null`;
        chomp($version);
        return $version ne '' ? "macOS ($version)" : "macOS";
    } elsif ($^O eq 'linux') {
        my $version = `uname -sr 2>/dev/null`;
        chomp($version);
        return $version ne '' ? $version : "Linux";
    }
    return "Unknown OS";
}

sub get_platform {
    return "native";
}

sub get_device_type {
    return "Desktop";
}

sub get_architecture {
    if ($^O eq 'MSWin32') {
        return uc($ENV{PROCESSOR_ARCHITECTURE} || 'X64');
    } else {
        my $arch = `uname -m 2>/dev/null`;
        chomp($arch);
        return $arch ne '' ? uc($arch) : "X64";
    }
}

sub get_cpu_cores {
    if ($^O eq 'MSWin32') {
        my $physical_cores = `powershell -Command "(Get-CimInstance Win32_Processor).NumberOfCores" 2>nul`;
        chomp($physical_cores);
        $physical_cores =~ s/^\s+|\s+$//g;
        my $logical_processors = $ENV{NUMBER_OF_PROCESSORS} || "2";
        my $cores = $physical_cores eq "" ? $logical_processors : $physical_cores;
        return "$cores Cores / $logical_processors Threads";
    } else {
        my $logical = "2";
        if ($^O eq 'darwin') {
            $logical = `sysctl -n hw.ncpu 2>/dev/null`;
        } else {
            $logical = `nproc 2>/dev/null`;
        }
        chomp($logical);
        $logical =~ s/^\s+|\s+$//g;
        $logical = "2" if $logical eq '';
        return "$logical Cores / $logical Threads";
    }
}

sub get_ram_gb {
    if ($^O eq 'MSWin32') {
        my $ram = `powershell -Command "[Math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)" 2>nul`;
        chomp($ram);
        $ram =~ s/^\s+|\s+$//g;
        return $ram ne "" ? $ram : "0";
    } elsif ($^O eq 'darwin') {
        my $bytes = `sysctl -n hw.memsize 2>/dev/null`;
        chomp($bytes);
        if ($bytes =~ /^\d+$/ && $bytes > 0) {
            return int($bytes / (1024 * 1024 * 1024));
        }
        return "0";
    } else {
        my $kb = `grep MemTotal /proc/meminfo 2>/dev/null | awk '{print \$2}'`;
        chomp($kb);
        if ($kb =~ /^\d+$/ && $kb > 0) {
            return int($kb / (1024 * 1024));
        }
        return "0";
    }
}

package AuthVaultixCore;
use strict;
use warnings;
use MIME::Base64;
use POSIX qw(strftime);

my $BASE_URL = "https://authvaultix.com/api/1.0/";

sub new {
    my ($class, $app_name, $owner_id, $secret, $version) = @_;
    if (!$app_name || !$owner_id || !$secret || !$version) {
        die "Application not setup correctly.\n";
    }
    my $self = {
        app_name     => $app_name,
        owner_id     => $owner_id,
        secret       => $secret,
        version      => $version,
        session_id   => undef,
        initialized  => 0,
        current_user => undef
    };
    bless $self, $class;
    return $self;
}

sub hwid {
    my $sid = "";
    if ($^O eq 'MSWin32') {
        $sid = `powershell -Command "[System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value" 2>nul`;
        chomp($sid);
        $sid =~ s/^\s+|\s+$//g;
    }
    return $sid || "UNKNOWN_HWID";
}

sub ensure_ready {
    my ($self) = @_;
    unless ($self->{initialized}) {
        die "SDK not initialized. Call init before using any API.\n";
    }
}

sub init {
    my ($self) = @_;
    return 1 if $self->{initialized};
    
    my $payload = PayloadBuilder->new("init")
        ->with_value("ver", $self->{version})
        ->with_value("name", $self->{app_name})
        ->with_value("ownerid", $self->{owner_id})
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return 0 unless $resp;
    
    if ($resp->{success}) {
        $self->{session_id} = $resp->{sessionid};
        $self->{initialized} = 1;
        print "Initialized Successfully! Session ID: $self->{session_id}\n";
        return 1;
    } else {
        die "Init Failed: $resp->{message}\n";
    }
}

sub authenticate_user {
    my ($self, $username, $password) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("login")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("username", $username)
        ->with_value("pass", $password)
        ->with_value("hwid", $self->hwid())
        ->with_value("os", SystemInfoCollector->get_os_version())
        ->with_value("platform", SystemInfoCollector->get_platform())
        ->with_value("device", SystemInfoCollector->get_device_type())
        ->with_value("architecture", SystemInfoCollector->get_architecture())
        ->with_value("cpu_cores", SystemInfoCollector->get_cpu_cores())
        ->with_value("ram", SystemInfoCollector->get_ram_gb())
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return 0 unless $resp;
    
    if ($resp->{success}) {
        $self->{current_user} = $resp->{info};
        $self->{session_id} = $resp->{sessionid} if $resp->{sessionid};
        print "Logged in!\n";
        $self->print_user_info();
        return 1;
    } else {
        print "Login Failed: $resp->{message}\n";
        return 0;
    }
}

sub validate_session {
    my ($self) = @_;
    $self->ensure_ready();
    return 0 unless $self->{session_id};
    
    my $payload = PayloadBuilder->new("check")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return 0 unless $resp;
    
    if ($resp->{success}) {
        print "Session Valid!\n";
        return 1;
    } else {
        print "Session Invalid: $resp->{message}\n";
        return 0;
    }
}

sub register_account {
    my ($self, $username, $password, $license, $email) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("register")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("username", $username)
        ->with_value("pass", $password)
        ->with_value("key", $license)
        ->with_value("email", $email)
        ->with_value("hwid", $self->hwid())
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return 0 unless $resp;
    
    if ($resp->{success}) {
        $self->{current_user} = $resp->{info};
        $self->{session_id} = $resp->{sessionid} if $resp->{sessionid};
        print "Registered Successfully!\n";
        $self->print_user_info();
        return 1;
    } else {
        print "Register Failed: $resp->{message}\n";
        return 0;
    }
}

sub license_access {
    my ($self, $license) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("license")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("key", $license)
        ->with_value("hwid", $self->hwid())
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return 0 unless $resp;
    
    if ($resp->{success}) {
        $self->{current_user} = $resp->{info};
        $self->{session_id} = $resp->{sessionid} if $resp->{sessionid};
        print "License Login Successful!\n";
        $self->print_user_info();
        return 1;
    } else {
        print "License Login Failed: $resp->{message}\n";
        return 0;
    }
}

sub send_log {
    my ($self, $message) = @_;
    $self->ensure_ready();
    my $pcuser = $ENV{USERNAME} || 'Unknown';
    my $payload = PayloadBuilder->new("log")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("message", $message)
        ->with_value("pcuser", $pcuser)
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return 0 unless $resp;
    
    return 1 if $resp->{success};
    print "Log Failed: $resp->{message}\n";
    return 0;
}

sub retrieve_file {
    my ($self, $fileid) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("file")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("fileid", $fileid)
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return undef unless $resp;
    
    if ($resp->{success}) {
        my $decoded = eval { decode_base64($resp->{contents}) };
        if ($@) {
            print "Base64 Decode Error\n";
            return undef;
        }
        print "Download successful\n";
        return $decoded;
    }
    print "Download Failed: $resp->{message}\n";
    return undef;
}

sub get_online_clients {
    my ($self) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("fetchonline")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return undef unless $resp;
    
    return $resp->{users} if $resp->{success};
    print "Fetch Online Failed: $resp->{message}\n";
    return undef;
}

sub enforce_ban {
    my ($self, $reason) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("ban")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("reason", $reason)
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return 0 unless $resp;
    
    if ($resp->{success}) {
        print "Banned successfully\n";
        return 1;
    }
    print "Ban Failed: $resp->{message}\n";
    return 0;
}

sub terminate_session {
    my ($self) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("logout")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    if ($resp && $resp->{success}) {
        $self->{session_id} = undef;
        $self->{initialized} = 0;
        print "Logged out successfully\n";
    } else {
        print "Logout Error\n";
    }
}

sub update_username {
    my ($self, $new_username) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("changeusername")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("newUsername", $new_username)
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    if ($resp && $resp->{success}) {
        $self->{session_id} = undef;
        $self->{initialized} = 0;
        print "Username changed successfully. Please login again.\n";
    } else {
        print "Change Username Error\n";
    }
}

sub verify_blacklist {
    my ($self) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("checkblacklist")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("hwid", $self->hwid())
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return 0 unless $resp;
    
    return 1 if $resp->{success};
    print "Client is blacklisted: $resp->{message}\n";
    return 0;
}

sub trigger_password_reset {
    my ($self, $username, $email) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("forgot")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("username", $username)
        ->with_value("email", $email)
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return 0 unless $resp;
    
    if ($resp->{success}) {
        print "Reset email sent successfully\n";
        return 1;
    }
    print "Forgot Password Failed: $resp->{message}\n";
    return 0;
}

sub apply_upgrade {
    my ($self, $username, $license) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("upgrade")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("username", $username)
        ->with_value("key", $license)
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return 0 unless $resp;
    
    if ($resp->{success}) {
        print "Upgrade successful\n";
        return 1;
    }
    print "Upgrade Failed: $resp->{message}\n";
    return 0;
}

sub fetch_global_variable {
    my ($self, $var_id) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("var")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("varid", $var_id)
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return undef unless $resp;
    
    return $resp->{message} if $resp->{success};
    print "Fetch Global Var Failed: $resp->{message}\n";
    return undef;
}

sub fetch_user_variable {
    my ($self, $var_name) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("getvar")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("var", $var_name)
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return undef unless $resp;
    
    return $resp->{response} if $resp->{success};
    print "Fetch User Var Failed: $resp->{message}\n";
    return undef;
}

sub update_user_variable {
    my ($self, $var_name, $value) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("setvar")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("var", $var_name)
        ->with_value("data", $value)
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return 0 unless $resp;
    
    print "Set User Var Failed: $resp->{message}\n" unless $resp->{success};
    return $resp->{success};
}

sub transmit_chat_message {
    my ($self, $message, $channel) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("chatsend")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("message", $message)
        ->with_value("channel", $channel)
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return 0 unless $resp;
    
    if ($resp->{success}) {
        print "Message sent.\n";
        return 1;
    }
    
    if ($resp->{code} == 403 && $resp->{remaining_seconds} > 0) {
        print "Muted till $resp->{muted_until} (wait $resp->{remaining_human})\n";
    } else {
        print "Chat Send Failed: $resp->{message}\n";
    }
    return 0;
}

sub retrieve_chat_history {
    my ($self, $channel) = @_;
    $self->ensure_ready();
    my $payload = PayloadBuilder->new("chatfetch")
        ->with_context($self->{app_name}, $self->{owner_id}, $self->{session_id})
        ->with_value("channel", $channel)
        ->compile();
        
    my $resp = NetworkAgent->post($BASE_URL, $payload);
    return undef unless $resp;
    
    return $resp->{messages} if $resp->{success};
    print "Chat Fetch Failed: $resp->{message}\n";
    return undef;
}

sub print_user_info {
    my ($self) = @_;
    my $user = $self->{current_user};
    return unless $user;
    
    print "\n=== User Data ===\n";
    print "Username: $user->{username}\n";
    print "IP: $user->{ip}\n" if $user->{ip};
    print "HWID: $user->{hwid}\n" if $user->{hwid};
    print "Created: " . _format_time($user->{createdate}) . "\n" if $user->{createdate};
    print "Last Login: " . _format_time($user->{lastlogin}) . "\n" if $user->{lastlogin};
    
    if (ref($user->{subscriptions}) eq 'ARRAY' && scalar(@{$user->{subscriptions}}) > 0) {
        print "\nSubscriptions:\n";
        my $i = 1;
        foreach my $sub (@{$user->{subscriptions}}) {
            print "[$i] $sub->{subscription} | Expiry: " . _format_time($sub->{expiry}) . " | Timeleft: " . _format_timeleft($sub->{timeleft}) . "\n";
            $i++;
        }
    }
    print "\n";
}

sub _format_time {
    my ($unix) = @_;
    return $unix unless $unix =~ /^\d+$/;
    return strftime("%Y-%m-%d %H:%M:%S", localtime($unix));
}

sub _format_timeleft {
    my ($seconds) = @_;
    my $d = int($seconds / 86400);
    my $h = int(($seconds % 86400) / 3600);
    my $m = int(($seconds % 3600) / 60);
    return "${d}d ${h}h ${m}m";
}

package AuthVaultixClient;
use strict;
use warnings;

sub new {
    my ($class, $app_name, $owner_id, $secret, $version) = @_;
    my $self = {
        core => AuthVaultixCore->new($app_name, $owner_id, $secret, $version)
    };
    bless $self, $class;
    return $self;
}

sub init { $_[0]->{core}->init(); }
sub login { $_[0]->{core}->authenticate_user($_[1], $_[2]); }
sub check { $_[0]->{core}->validate_session(); }
sub register { $_[0]->{core}->register_account($_[1], $_[2], $_[3], $_[4] || ""); }
sub license_login { $_[0]->{core}->license_access($_[1]); }
sub log { $_[0]->{core}->send_log($_[1]); }
sub download { $_[0]->{core}->retrieve_file($_[1]); }
sub fetch_online { $_[0]->{core}->get_online_clients(); }
sub ban { $_[0]->{core}->enforce_ban($_[1]); }
sub logout { $_[0]->{core}->terminate_session(); }
sub change_username { $_[0]->{core}->update_username($_[1]); }
sub check_blacklist { $_[0]->{core}->verify_blacklist(); }
sub upgrade { $_[0]->{core}->apply_upgrade($_[1], $_[2]); }
sub forgot_password { $_[0]->{core}->trigger_password_reset($_[1], $_[2]); }
sub get_global_var { $_[0]->{core}->fetch_global_variable($_[1]); }
sub get_var { $_[0]->{core}->fetch_user_variable($_[1]); }
sub set_var { $_[0]->{core}->update_user_variable($_[1], $_[2]); }
sub chat_send { $_[0]->{core}->transmit_chat_message($_[1], $_[2]); }
sub chat_fetch { $_[0]->{core}->retrieve_chat_history($_[1]); }

1;
