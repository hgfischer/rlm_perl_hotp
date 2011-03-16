#!/usr/bin/env perl

use strict;
use warnings;

use Getopt::Std;
use Cwd qw(abs_path);
use MIME::Base64;

use constant SEPARATOR => '~';

my $ARGC = $#ARGV + 1;

if ($ARGC != 1) {
	my $path = abs_path($0);
	die "$path [filename]\n";
}

my $filename = $ARGV[0];
open(OTPFILE, $filename) || die("Could not open file '$filename'!");

while (my $line = <OTPFILE>) {
	chomp($line);
	next if $line =~ /^#/;
	my ($username, $serial, $offset, $secret) = split SEPARATOR, $line;
	print "'$username', '$serial', '$offset', '$secret'\n";
	my $key = substr("$username$serial" x 2, 0, length($secret));
	print "key = '$key'\n";
	my $cysecret = $key ^ $secret;
	my $b64cysecret = encode_base64($cysecret);
	chomp($b64cysecret);
	print "'$b64cysecret'\n";
	my $nsecret = $key ^ decode_base64($b64cysecret);
	print "'$nsecret'\n";
}

close(OTPFILE);
