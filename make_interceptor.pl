#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;

#warn "make_interceptor.pl:".getppid()."/$$: $0 @ARGV\n"; # LOUD

# When used as a replacement to the system as will just pass the
# arguments through.

my $prog = "${0}_orig";         # compute the new executable name we are calling

# Remove the -j argument.  If we are going to replay the build
# process, I want the order in which things are built to be as
# canonical as possible.

my @av;
my $skip_next = 0;
for my $a (@ARGV) {
  if ($skip_next) {
    $skip_next = 0;
    next;
  }
  if ($a =~ /^-j/) {
    if ($a eq '-j') {
      # of the form '-j 2'
      $skip_next = 1;
#      warn "form 2";
    } else {
      # of the form '-j2'
#      warn "form 1";
    }
    next;
  }
  # not an argument we want to exclude, so let it through
  push @av, $a;
}

# Just delegate to the real thing.
#warn "make_interceptor.pl: $prog @av";
exec($prog, @av);
