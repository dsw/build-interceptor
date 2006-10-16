#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;

# Find configure files in directory 'ball'.

my $home = "$ENV{HOME}";
my $balldir = "$home/ball";
my $findCmd = "find $balldir -type f";

my @files = split (/\n/, `$findCmd`);

for my $file (@files) {
  chomp $file;
  my $infile = $file;
  next if $infile =~ /\.ld$/;

  # get the first line of the file
  my $firstline;
  die "$!:no file $infile" unless -f $infile;
  open (F, $infile) or die $!;
#    my $firstline = `head -n 1 $infile`;
  while (<F>) {
    die if defined $firstline;  # ensure just one iteration around the loop
    $firstline = $_;
    last;                       # we only want the first line
  }
  close (F) or die $!;

  # line looks like '# 1 "Array-ch.cc"'
  if (!defined $firstline) {
    print "no first line:$file\n";
    next;
  }
  chomp $firstline;

  if ($firstline =~ m|^# \d+ "configure"$|) {
    print "configure:$file\n";
  } elsif ($firstline =~ m|^# \d+ "conftest\S*"$|) {
    print "conftest:$file\n";
  }
}
