#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use AuthVaultix;

# Initialize API Instance
my $app = AuthVaultixClient->new(
  "", # app
  "", # owner id
  "", # secret
  "1.0" # version
);

print "\nConnecting...\n";
$app->init();

while (1) {
    print "\n[1] Login\n[2] Register\n[3] License Login\n[4] Upgrade\n[5] Forgot Password\n[6] Exit\nChoose option: ";
    chomp(my $opt = <STDIN>);

    if ($opt eq '1') {
        print "Username: "; chomp(my $u = <STDIN>);
        print "Password: "; chomp(my $p = <STDIN>);
        $app->login($u, $p);
    }
    elsif ($opt eq '2') {
        print "Username: "; chomp(my $u = <STDIN>);
        print "Password: "; chomp(my $p = <STDIN>);
        print "License: ";  chomp(my $l = <STDIN>);
        $app->register($u, $p, $l, "");
    }
    elsif ($opt eq '3') {
        print "License: "; chomp(my $l = <STDIN>);
        $app->license_login($l);
    }
    elsif ($opt eq '4') {
        print "Username: "; chomp(my $u = <STDIN>);
        print "License: ";  chomp(my $l = <STDIN>);
        $app->upgrade($u, $l);
    }
    elsif ($opt eq '5') {
        print "Username: "; chomp(my $u = <STDIN>);
        print "Email: ";    chomp(my $e = <STDIN>);
        $app->forgot_password($u, $e);
    }
    elsif ($opt eq '6') {
        print "Goodbye!\n";
        last;
    }
    else {
        print "Invalid option!\n";
    }
}
