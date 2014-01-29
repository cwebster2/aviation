#!/usr/bin/perl
# Copyright 2014, Casey Webster

require "aviation.pl";

# BEGIN MAIN PROG

unless (defined ($ARGV[0])) {
        die "Usage: av.pl metar ICAO-code\n"
        . "Usage: av.pl taf ICAO-code\n"
        . "Usage: av.pl metar-decode ICAO-code\n"
        . "Usage: av.pl metar-detail ICAO-code\n"
        . "Usage: av.pl metar-debug metar-code\n"
        . "Usage: av.pl airport ICAO-code\n"
        . "Usage: av.pl navaid Navaid-name/id\n";
}
if ($ARGV[0] =~ /^metar$/) {
  my $ICAO = uc($ARGV[1]);
  my $metar = aviation::metar::get($ICAO);
  print $metar . "\n";
} elsif ($ARGV[0] =~ /^taf$/) {
  my $ICAO = uc($ARGV[1]);
  my $taf = aviation::taf::get($ICAO);
  print $taf . "\n";
} elsif ($ARGV[0] =~ /^metar-decode$/) {
  my $ICAO = uc($ARGV[1]);
  my $metar = aviation::metar::get($ICAO);
  my $doot = aviation::metar::decode($metar);
  print $doot . "\n";
} elsif ($ARGV[0] =~ /^metar-detail$/) {
  my $ICAO = uc($ARGV[1]);
  my $doot = aviation::metar::detail($ICAO);
  print $doot . "\n";
} elsif ($ARGV[0] =~ /^metar-debug$/) {
  shift @ARGV;
  print "metar-debug!\n";
  my $metar = join(" ",@ARGV);
  print "$metar\n";
  my $doot = aviation::metar::decode($metar);
  print $doot . "\n";
} elsif ($ARGV[0] =~ /^airport$/) {
  my $ICAO = uc($ARGV[1]);
  my $rpt = aviation::airport($ICAO);
  print $rpt . "\n";
} elsif ($ARGV[0] =~ /^navaid$/) {
  my $NAVAID = $ARGV[1];
  my $rpt = aviation::navaid($NAVAID);
  print $rpt . "\n";
} else { print "oops\n\n"; }

