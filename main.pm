#!/usr/bin/perl
use strict;
use warnings;
use FindBin;
use lib $FindBin::Bin;
use AuthVaultix;

#  Initialize API
AuthVaultix::Api(
  "",
  "",
  "",
  ""
);

print "\nConnecting...\n";
AuthVaultix::Init();
#  Menu
print "\n1) Login\n2) Register\n3) License Login\n4) Exit\nChoose: ";
chomp(my $opt = <STDIN>);

if ($opt == 1) {
  print "Username: "; chomp(my $u = <STDIN>);
  print "Password: "; chomp(my $p = <STDIN>);
  AuthVaultix::Login($u, $p);
}
elsif ($opt == 2) {
  print "Username: "; chomp(my $u = <STDIN>);
  print "Password: "; chomp(my $p = <STDIN>);
  print "License: ";  chomp(my $l = <STDIN>);
  AuthVaultix::Register($u, $p, $l);
}
elsif ($opt == 3) {
  print "License: "; chomp(my $l = <STDIN>);
  AuthVaultix::License($l);
}
else {
  print "Goodbye!\n";
  exit;
}
