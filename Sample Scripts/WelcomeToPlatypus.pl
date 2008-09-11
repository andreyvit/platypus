#!/usr/bin/perl
#
# A simple script which bids you hello verbally and opens the Platypus website
#
# Open this script with Platypus and select Output Type: Text Window, then
# press Create

use Shell;

@lines = finger("-lg", "$ENV{'USER'}");

($ble, $longname) = split(/Name\:/, $lines[0]);
$longname =~ s/\n//g;
$hellostr = "Welcome to $ENV{'APP_BUNDLER'}, $longname.";
print $hellostr;
say($hellostr);
system('open http://sveinbjorn.sytes.net/platypus');