#!/usr/bin/env perl

use strict;
use warnings;

use Redis;
use Getopt::Std;
use Cwd qw(abs_path);
use MIME::Base64;

use constant SEPARATOR => '~';

my $ARGC = $#ARGV + 1;

if ($ARGC != 1) {
	my $path = abs_path($0);
	die "$path [filename]\n";
}

my $redis = Redis->new || die("Could not connect in Redis!");

my $filename = $ARGV[0];
open(OTPFILE, $filename) || die("Could not open file '$filename'!");

$redis->flushall;

while (my $line = <OTPFILE>) {
	chomp($line);
	next if $line =~ /^#/;
	my ($username, $serial, $offset, $b64cysecret) = split SEPARATOR, $line;
	my $cysecret = decode_base64($b64cysecret);
	my $key = substr("$username$serial" x 2, 0, length($cysecret));
	my $secret = $key ^ $cysecret;
	print "Registering token '$serial' for '$username'...";
	$redis->set("$username:offset" => $offset);
	$redis->set("$username:original:offset" => $offset);
	$redis->set("$username:secret" => $secret);
	$redis->set("$username:serial" => $serial);
	print "done.\n";
}

close(OTPFILE);
$redis->quit;
