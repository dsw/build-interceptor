#!/usr/bin/perl -w
use strict;
use warnings;
use FindBin;
use lib "${FindBin::RealBin}";
use BuildInterceptor ':all';

# Move the system gcc executable to gcc_orig and make a softlink from
# the name gcc to this script.

# The intent is that when gcc is run, dirname $0 will be the directory
# that contains the link to this script, and should be the directory
# where the gcc executable got moved to gcc_orig.

my $specfile = "${FindBin::RealBin}/interceptor.specs";

if ($arg0 =~ /(-[0-9][.][0-9.]+)$/) {
    $specfile .= $1;
}

if (!-f $specfile) {
    die "$0: can't find specfile $specfile";
}

if ("@$raw_args" =~ /-E -P -\s*$/ || grep {$_ eq '-V'} @$raw_args) {
    # -E -P kludge: don't output line markers if the program is just using gcc
    # to get preprocessor definitions.  What glibc does is:
    #     echo '#include <linux/version.h>\nUTS_RELEASE' | gcc -E -P -
    # -V kludge: with -V argument (which must be first): just call gcc-VERSION
    # (which is also intercepted)
    exec_prog();
}

my $BUILD_INTERCEPTOR_EXTRA_GCC_ARGS = [
    split(/ /, $ENV{BUILD_INTERCEPTOR_EXTRA_GCC_ARGS}||'')];

unshift(@$argv,
        "--no-integrated-cpp",
        "-specs=$specfile",
        @$BUILD_INTERCEPTOR_EXTRA_GCC_ARGS,
        # We no longer need this:
        #     "-B$FindBin::RealBin"
    );

exec_prog();
