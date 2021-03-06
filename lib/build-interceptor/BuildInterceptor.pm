# $Id$

use strict;
use warnings;

package BuildInterceptor;

use FileHandle;
use File::Basename;
use File::Path;
use Digest::MD5;
use FindBin;
use POSIX qw(strftime);
use Carp;
use BuildInterceptor::Preload;
use IPC::Run;

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
     timestamp
     logline
     run_prog
     exec_prog
     pipe_prog
     check_exit_code
     ensure_dir_of_file_exists
     md5_file
     get_output_filename
     append_to_file
     file_is_empty_p
     do_not_add_interceptions_to_this_file_p
     tab_indent_lines
     check_output_file
     split_var
     my_dirname
     $BUILD_INTERCEPTOR_MODE
     $ARGV0
     $PROGRAM
     $EXTRACT_SECTION
     $raw_args
     $argv
);

our %EXPORT_TAGS = (all => [@EXPORT_OK]);

my $ETC_DIR = "$FindBin::RealBin/../../rc";

if ($ENV{LD_PRELOAD} && $ENV{LD_PRELOAD} =~ /preload_helper/) {
    die "$0: LD_PRELOAD shouldn't have preload_helper.so here!";
}

our $BUILD_INTERCEPTOR_MODE = 'RENAME';

if (scalar(@ARGV) >= 2 && $ARGV[0] eq '--build-interceptor-mode') {
    shift @ARGV;
    $BUILD_INTERCEPTOR_MODE = shift @ARGV;
}

if ($BUILD_INTERCEPTOR_MODE eq 'RENAME') {
    if (! -f "$ETC_DIR/rename-mode.on") {
        die "$0: invoked in RENAME mode; enable with `build-interceptor-rename on'\n";
    }
} elsif ($BUILD_INTERCEPTOR_MODE eq 'LD_PRELOAD') {
    BuildInterceptor::Preload::clean_ld_preload();
} else {
    die "$0: invalid Build-Interceptor mode '$BUILD_INTERCEPTOR_MODE'\n";
}

our $ARGV0 = $0;
our $PROGRAM;

my $specified_program = 0;
if (scalar(@ARGV) >= 2 && $ARGV[0] eq '--build-interceptor-program') {
    shift @ARGV;
    $ARGV0 = $PROGRAM = shift @ARGV;
    $specified_program = 1;
}

if (scalar(@ARGV) >= 2 && $ARGV[0] eq '--build-interceptor-argv0') {
    shift @ARGV;
    $ARGV0 = shift @ARGV;
}

if ($BUILD_INTERCEPTOR_MODE eq 'RENAME') {
    if ($ARGV0 =~ s/_interceptor$//) {
        $ARGV0 =~ s,.*/,,;
    }
    $ARGV0 = _follow_interceptor_links($ARGV0);
    $PROGRAM = "${ARGV0}_orig" unless $specified_program;
}

if (!$PROGRAM) {
    die "$0: unknown program under interception\n";
}

if ($ENV{BUILD_INTERCEPTOR_DEBUG}) {
    print STDERR "$0 $BUILD_INTERCEPTOR_MODE ARGV0=$ARGV0 PROGRAM=$PROGRAM\n";
}

# we're in build-interceptor/lib/build-interceptor
our $EXTRACT_SECTION = "$FindBin::RealBin/../../extract_section";

if (! -x $EXTRACT_SECTION) {
    die "$0: Couldn't find extract_section (looked at $EXTRACT_SECTION)\n";
}

our $raw_args = [@ARGV];
our $argv = [@ARGV];

# POSIXLY_CORRECT breaks objcopy
# TODO: only remove it locally when calling objcopy
delete $ENV{POSIXLY_CORRECT};

if (!$ENV{HOME}) {
    $ENV{HOME} = "${FindBin::RealBin}/..";
}

my $logfh;

logline("raw_args = [@$raw_args]");

sub _open_log
{
    return if defined($logfh);
    if ($ENV{BUILD_INTERCEPTOR_LOG}) {
        my $logfile = $ENV{BUILD_INTERCEPTOR_LOG}; #"$ENV{HOME}/build-interceptor.log";
        $logfh = IO::File->new($logfile,'a') || die "$0: $!";
    } else {
        $logfh = 0;
    }
}

sub timestamp {
    return strftime("%Y-%m-%d %H:%M:%S", localtime());
}

sub logline {
    _open_log();
    if ($logfh) {
        my ($line) = @_;
        my $timestamp = timestamp();
        my $ppid = getppid();
        print $logfh "[$timestamp] ${0}[${ppid}/$$]: $line\n";
    }
}

# In PRELOAD, we preserve the invariant that we execve() exactly once to get
# to the target intercepted program.  This is necessary because the current
# process is not LD_PRELOAD-traced, but our child will be, so our
# grand-children will be re-intercepted.

sub run_prog {
    logline("  system([$PROGRAM @$argv])");
    local %ENV = %ENV;
    BuildInterceptor::Preload::add_ld_preload() if $BUILD_INTERCEPTOR_MODE eq 'LD_PRELOAD';
    # system($PROGRAM, @$argv);
    IPC::Run::run( [ $PROGRAM, @$argv ] );
    check_exit_code($?);
}

sub exec_prog {
    logline("  exec([$PROGRAM @$argv])");
    if ($ENV{BUILD_INTERCEPTOR_DEBUG}) {
        print STDERR "$0: exec_prog $PROGRAM\n";
    }
    # Make sure our children are intercepted.
    BuildInterceptor::Preload::add_ld_preload() if $BUILD_INTERCEPTOR_MODE eq 'LD_PRELOAD';
    logline("     LD_PRELOAD=$ENV{LD_PRELOAD}") if $BUILD_INTERCEPTOR_MODE eq 'LD_PRELOAD';
    exec($PROGRAM, @$argv) or die "$0: couldn't exec $argv->[0]";
}

sub pipe_prog {
    logline("  pipe([$PROGRAM @$argv])");
    local %ENV = %ENV;
    BuildInterceptor::Preload::add_ld_preload() if $BUILD_INTERCEPTOR_MODE eq 'LD_PRELOAD';
    # my $quoted_argv = [map{_quoteit($_)} @$argv];
    # my $stdout = `$PROGRAM @$quoted_argv`;

    # We must use IPC::Run here instead of `...`, to maintain the invariant
    # that we execute one process, absolutely necessary for preload mode.

    my $stdout;
    IPC::Run::run( [ $PROGRAM, @$argv ], '>', \$stdout);

    check_exit_code($?);
    return $stdout;
}

sub check_exit_code {
    my ($ret) = @_;
    my $exit_value = $ret >> 8;
    if ($ret) {
        if ($exit_value) {
            exit $exit_value;
        } else {
            die "$0: Failure return not reflected in the exit value: $ret";
        }
    }
}


sub ensure_dir_of_file_exists($) {
    my ($f) = (@_);
    mkpath(dirname($f));
}

sub md5_file {
    my ($filename) = @_;
    Carp::confess unless $filename;
    my $f = IO::File->new($filename, 'r') || die "$0: couldn't open $filename for md5: $!";
    return Digest::MD5->new->addfile($f)->hexdigest;
}

sub get_output_filename {
    my $outfile;

    for (my $i=0; $i<@$raw_args; ++$i) {
        if ($raw_args->[$i] =~ /^-o/) {
            my $prev_outfile = $outfile;
            # die "$0: multiple -o options" if defined $outfile;
            if ($raw_args->[$i] eq '-o') {
                $outfile = $raw_args->[$i+1];
                ++$i;
            } elsif ($raw_args->[$i] =~ /^-o(.+)$/) {
                $outfile = $1;
            } else {
                die "$0: should have matched: $raw_args->[$i]"; # something is very wrong
            }
            die "$0: -o without file" unless defined $outfile;

            # allow multiple -o options only if they're the same, i.e. "gcc -o
            # foo.o -o foo.o" is OK.
            die "$0: multiple -o options" if ($prev_outfile && $prev_outfile ne $outfile);
        }
    }
    return $outfile;
}

sub append_to_file {
    my ($filename, $data) = @_;
    if ($filename eq "-") {
        print $data;
    } else {
        if (!-f $filename) {
            die "$0: file '$filename' doesn't exist\n";
        }
        my $fh = new FileHandle(">>$filename") || die "$0: can't open '$filename': $!";
        print $fh $data;
        close $fh || die "$0: $!";
    }
}

sub file_is_empty_p {
    # returns 1 iff file is composed entirely of empty/comment lines

    my ($filename) = @_;
    my $fh = new FileHandle($filename) or die;
    local $_;
    for (<$fh>) {
        if (/^\s*#/) { next; }
        if (/^\s*$/) { next; }
        # The line ".text" (with nothing else after it) should still let the
        # file count as an "empty" file (.s files in allegro4.1 #ifdef out
        # everything except the ".text").
        if (/^[.]text$/) { next; }
        return 0;
    }
    return 1;
}

sub _follow_interceptor_links {
    # If gcc is a link to something that's not an interceptor (e.g. gcc-3.3),
    # use gcc-3.3_orig instead of gcc_orig.
    #
    # We could have up to triple links on a stock Debian system: /usr/bin/cc
    # -> /etc/alternatives/cc -> /usr/bin/gcc -> /usr/bin/gcc-3.3
    my ($prog) = @_;
    my $l;
    while ( ($l=readlink($prog)) && $l !~ /interceptor/ ) {
        $prog = File::Spec->rel2abs($l, my_dirname($prog));
    }
    return $prog;
}

sub do_not_add_interceptions_to_this_file_p {
    my ($outfile_abs) = @_;
    my $r = $ENV{BUILD_INTERCEPTOR_DO_NOT_ADD_INTERCEPTIONS_TO_FILES};
    return ($r and $outfile_abs =~ /^$r$/);
}

sub _quoteit {
    my ($arg) = @_;
    $arg =~ s|'|'\\''|;
    return "'$arg'";
}

sub tab_indent_lines {
    # double-tab-indent lines to quote it.

    my ($text) = @_;
    $text =~ s|^(.*)$|\t\t$1|gm;
    return $text;
}

sub check_output_file {
    my ($outfile) = @_;
    if ($outfile ne '-' && !-f $outfile) {
        die "$0: $PROGRAM didn't produce $outfile\n";
    }
}

# split a string at spaces, but not on "\ ".
#    join(",",split_var("x y   z\\ q")) => "x,y,z q"
sub split_var {
    my ($x) = @_;
    die unless defined $x;

    my $q = chr 255;
    die if $x =~ /$q/;

    $x =~ s/\\ /$q/g;
    my @r = map { s/$q/ /g; $_ } split(/ +/, $x);

    return @r;
}

sub my_dirname {
    my ($path) = @_;
    my ($vol,$dir,$file) = File::Spec->splitpath($path);
    return File::Spec->catpath($vol, $dir, "");
}

1;

=for emacs

    Use this function to update the export list:

(progn
 (save-excursion
  (goto-char (point-min))
  (re-search-forward "EXPORT_OK = qw(\n\\(\\(?:.\\|\n\\)*?\n\\))")
  (replace-match (concat
   (shell-command-to-string (concat "awk -F'[ (]'  '/^sub [^_]/ { print \"    \",$2 }' "
                             buffer-file-name))
   (shell-command-to-string (concat "perl -ne '/^our [(]?\\$([a-zA-Z90-9_]*?)[ ;)]/ && print \"     \\$$1\n\"' "
                             buffer-file-name)))
   t t nil 1)))
