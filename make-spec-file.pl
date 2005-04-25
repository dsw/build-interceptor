#!/usr/bin/perl

# $Id: make-spec-file.pl,v 1.2 2005/04/25 00:18:53 dsw Exp $

# syntax: make-spec-file.pl interceptor.specs.in interceptor.specs-3.4

use strict;
use warnings;
use FileHandle;

my ($input, $output) = @ARGV or die;

my $in  = new FileHandle($input) or die $!;
my $out = new FileHandle(">$output") or die $!;

my ($ver) = ($output =~ m/-([0-9][.][0-9.]+)$/) or die;

print $out "# specs for gcc $ver\n";

for (<$in>) {
    if (!/^!/ || s/^!!!gcc-$ver!!! //) {
        print $out $_;
    }
}
