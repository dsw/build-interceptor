#!/usr/bin/perl -w
use strict;

#my $splash = "gcc_interceptor.pl:".getppid()."/$$: $0 @ARGV\n"; # LOUD
#warn $splash;                   # LOUD
#open (LOG, ">>$ENV{HOME}/build_interceptor.log") or die $!; # LOUD
#print LOG $splash;              # LOUD

# Move the system gcc executable to gcc_orig and make a softlink from
# the name gcc to this script.

# We need to know the name of the directory where we are so we can
# tell the real gcc to look there for cpp0, cc1, cc1plus, as, and ld.
use FindBin;
use lib "$FindBin::Bin/../lib";

# The intent is that when gcc is run, dirname $0 will be the directory
# that contains the link to this script, and should be the directory
# where the gcc executable got moved to gcc_orig.

my $dollar_zero = ${0};

my $l;
# if gcc is a link to something that's not an interceptor (e.g. gcc-3.3), use
# gcc-3.3_orig instead of gcc_orig
$l = readlink($dollar_zero);
if ($l && $l !~ /interceptor/) {
    $dollar_zero = $l;
}
# quick hack to support triple links (/usr/bin/cc -> /etc/alternatives/cc ->
# /usr/bin/gcc -> /usr/bin/gcc-3.3).  Do a nice recursive solution in the
# future.
$l = readlink($dollar_zero);
if ($l && $l !~ /interceptor/) {
    $dollar_zero = $l;
}
$l = readlink($dollar_zero);
if ($l && $l !~ /interceptor/) {
    $dollar_zero = $l;
}

if ("@ARGV" =~ /-E -P -\s*$/) {
    # Hack for glibc: don't output line markers if the program is just using
    # gcc to get preprocessor definitions.  What glibc does is:
    #     echo '#include <linux/version.h>\nUTS_RELEASE' | gcc -E -P -
    exec("${dollar_zero}_orig", @ARGV) || die;
}

my @cmd_line =
  ("${dollar_zero}_orig",
   "--no-integrated-cpp",
   "-specs=${FindBin::RealBin}/interceptor.specs",
# We no longer need this
#     "-B$FindBin::RealBin",
   @ARGV);

# debug: dump it out
#  for my $a (@cmd_line) {
#      print LOG ":$a:\n";
#  }

# run the command
# warn "gcc_interceptor.pl: @cmd_line\n";
#close (LOG) or die $!;          # LOUD
exec(@cmd_line);
