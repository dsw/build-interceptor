#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;

# Count the number of .c and .cc files and the number of source lines
# in each package.

die <<END
You will probably need to fix this script.
END
  ;

my $home = "$ENV{HOME}";
my $ball_build = "$home/ball_build";
die unless -d $ball_build;

my @packages = split (/\n/, `ls $ball_build`);
for my $pkg(@packages) {
  print "**** $pkg\n";
  my $srcdir = "$ball_build/$pkg/BUILD/";

  # count C files
  my $cmd = "cd $srcdir; find -name \"*.c\" | wc -l";
  my $numCfiles = 0+`$cmd`;

  # count C++ files
  $cmd = "cd $srcdir; find -regex '.*\\.\\(cc\\|cxx\\|cpp\\|C\\|c\\+\\+\\)' | wc -l";
  my $numCPPfiles = 0+`$cmd`;

  print "$pkg $numCfiles $numCPPfiles\n";
}
