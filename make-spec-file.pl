#!/usr/bin/perl

# $Id$

# syntax: make-spec-file.pl interceptor.specs.in interceptor.specs-3.4

# Note that we can't use cpp because it doesn't respect whitespace, and
# whitespace is important.  We can't use m4 because we don't want to require
# m4 in the chroots at build-interceptor installation time.

use strict;
use warnings;
use FileHandle;

my ($input, $output) = @ARGV or die;

my $in  = new FileHandle($input) or die $!;
my $out = new FileHandle(">$output") or die $!;

my ($ver) = ($output =~ m/-([0-9][.][0-9.]+)$/) or die;

print $out "### specs for gcc $ver\n";

my $found = 0;

for (<$in>) {
    if (/^!/) {
        if (s/^!!!gcc-$ver!!! //) {
            ++$found;
        } else {
            next;
        }
    }
    print $out $_;
}

if (!$found) {
    die "$0: no data for gcc version $ver\n";
}
