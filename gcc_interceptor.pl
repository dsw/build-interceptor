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

# first, see if we need to map ${0} to a canonical name
my %canonName =
  ('/usr/bin/cc' => '/usr/bin/gcc',
   '/usr/bin/c++' => '/usr/bin/g++'
);
my $dollar_zero = ${0};
#  warn "before: $dollar_zero\n";
if (defined $canonName{$dollar_zero}) {
  $dollar_zero = $canonName{$dollar_zero};
}
#  warn "after: $dollar_zero\n";

if ("@ARGV" eq "-E -P -") {
    # Hack for glibc: don't output line markers if the program is just using
    # gcc to get preprocessor definitions.  What glibc does is:
    #     echo '#include <linux/version.h>\nUTS_RELEASE' | gcc -E -P -
    execvp("${dollar_zero}_orig", @ARGV) || die;
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
