#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;

# When used as a replacement to the system cpp0 or tradcpp0 will just
# pass the arguments through.

my @av = @ARGV;                 # @ARGV has magic, so copy it
my $prog = "${0}_orig";         # compute the new executable name we are calling

# Get rid of any -P arguments.
@av = grep {!/^-P$/} @av;

# Just delegate to the real thing.
system($prog, @av);
exit $? >> 8;
