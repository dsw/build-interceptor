#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;

# When used as a replacement to the system as will just pass the
# arguments through.

#warn "as_interceptor.pl:".getppid()."/$$: $0 @ARGV\n"; # LOUD

my @av = @ARGV;                 # @ARGV has magic, so copy it
my $prog = "${0}_orig";         # compute the new executable name we are calling

# Just delegate to the real thing.
exec($prog, @av);
