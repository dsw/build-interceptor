#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;
use FindBin;

# When used as a replacement to the system cpp0 or tradcpp0 will just
# pass the arguments through.

if (!$ENV{HOME}) {
    $ENV{HOME} = "${FindBin::RealBin}/..";
}

#my $splash = "cpp0_interceptor.pl:".getppid()."/$$: $0 @ARGV\n"; # LOUD
#warn $splash;                   # LOUD
#open (LOG, ">>$ENV{HOME}/build_interceptor.log") or die $!; # LOUD
#print LOG $splash;              # LOUD

my @av = @ARGV;                 # @ARGV has magic, so copy it

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


my $prog = "${dollar_zero}_orig"; # compute the new executable name we are calling

# Get rid of any -P arguments.
@av = grep {!/^-P$/} @av;

# Just delegate to the real thing.
#close (LOG) or die $!;          # LOUD
exec($prog, @av);
