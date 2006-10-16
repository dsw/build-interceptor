#!/usr/bin/perl

# $Id: build-interceptor-ldpreload 325 2006-10-16 11:00:04Z quarl $

package BuildInterceptor::Preload;

use strict;
use warnings;
use FindBin;
use Cwd;
use File::Spec;
use IO::File;

my $LIB_DIR = "$FindBin::RealBin";
my $preload_interceptor = "$LIB_DIR/preload_interceptor";
my $preload_lib_filename = "$LIB_DIR/preload_helper.so";

sub clean_ld_preload {
    my $ld_preload = $ENV{BUILD_INTERCEPTOR_ORIG_LD_PRELOAD} = $ENV{LD_PRELOAD} || '';
    # remove existing $PRELOAD, if any.
    $ld_preload =~ s/ /:/g;
    $ld_preload =~ s/::/:/g;
    $ld_preload = ":$ld_preload:";
    $ld_preload =~ s/:$preload_lib_filename://g;

    $ld_preload =~ s/^:+//;
    $ld_preload =~ s/:+$//;
    $ENV{LD_PRELOAD} = $ld_preload;
}

sub add_ld_preload {
    # TODO: if installing, this should be hard-coded.
    # NOTE: do this *before* setting LD_PRELOAD, because rel2abs calls pwd, an
    # external program affected by LD_PRELOAD!
    # my $ld_interceptor_preload_script = File::Spec->rel2abs($0);
    # if (!$ld_interceptor_preload_script) {
    #     die "$0: can't find myself (\$0=$0)\n";
    # }
    # if (!-e $ld_interceptor_preload_script) {
    #     die "$0: can't find myself ($ld_interceptor_preload_script, \$0=$0)\n";
    # }
    # if (!-x $ld_interceptor_preload_script) {
    #     die "$0: I'm not executable ($ld_interceptor_preload_script)\n";
    # }
    # my $ld_interceptor_preload_script = $preload_interceptor;

    # Needed by preload_lib to get back here.
    $ENV{BUILD_INTERCEPTOR_LDPRELOAD_SCRIPT} = $preload_interceptor;

    if (! -f $preload_lib_filename) {
        die "$0: couldn't find $preload_lib_filename.\n";
    }

    my $ld_preload = $ENV{LD_PRELOAD};
    # add new preload
    $ld_preload = "$preload_lib_filename:$ld_preload";

    # remove trailing ':' if empty.
    $ld_preload =~ s/:$//;

    $ENV{LD_PRELOAD} = $ld_preload;
}
