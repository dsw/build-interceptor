#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;

# Run gcc/g++ on all the .i/.ii files in directory 'ball'

my $home = "/home";

my $balldir = "$home/ball";
die unless -d $balldir;
my $findCmd = "find $balldir -type f";

print "start "; system "date";

my @files = split (/\n/, `$findCmd`);

my $fail_c_files = "$home/ball_fail_c.files";
die if -f $fail_c_files;
open (C_FAIL, ">$fail_c_files") or die $!;
my $fail_cc_files = "$home/ball_fail_cc.files";
die if -f $fail_cc_files;
open (CC_FAIL, ">$fail_cc_files") or die $!;

for my $file (@files) {
  chomp $file;
  die unless -f $file;

  # skip .ld files
  next if $file =~ /\.ld$/;

  if ($file =~ /\.i$/) {
    my $cmd = "gcc -c -O0 -o /dev/null $file";
    print "$cmd\n";
    if (system($cmd)) {
      print C_FAIL "$file\n";
    }
  } elsif  ($file =~ /\.ii$/) {
    my $cmd = "g++ -c -O0 -o /dev/null $file";
    print "$cmd\n";
    if (system($cmd)) {
      print CC_FAIL "$file\n";
    }
  }
}

close C_FAIL or die $!;
close CC_FAIL or die $!;

print "stop "; system "date";
