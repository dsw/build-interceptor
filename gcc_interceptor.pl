#!/usr/bin/perl -w
use strict;

#warn "gcc_interceptor.pl:".getppid()."/$$: $0 @ARGV\n"; # LOUD

# Move the system gcc executable to gcc_orig and make a softlink from
# the name gcc to this script.

# We need to know the name of the directory where we are so we can
# tell the real gcc to look there for cpp0, cc1, cc1plus, as, and ld.
use FindBin;
use lib "$FindBin::Bin/../lib";

# The intent is that when gcc is run, dirname $0 will be the directory
# that contains the link to this script, and should be the directory
# where the gcc executable got moved to gcc_orig.
my @cmd_line = 
  ("${0}_orig",
   "--no-integrated-cpp",
   "-specs=${FindBin::RealBin}/interceptor.specs",
# We no longer need this
#     "-B$FindBin::RealBin",
   @ARGV);

# debug: dump it out
#  for my $a (@cmd_line) {
#      print ":$a:\n";
#  }

# run the command
#warn "gcc_interceptor.pl: @cmd_line\n";
exec(@cmd_line);
