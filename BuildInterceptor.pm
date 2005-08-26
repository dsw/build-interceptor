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
     $arg0
     $prog
     $raw_args
     $argv
);

our %EXPORT_TAGS = (all => [@EXPORT_OK]);

my $p0 = $0;
# if invoked directly, e.g. make_interceptor.pl.
if ($0 =~ /_interceptor/) {
    $p0 =~ s,_interceptor.*,,;
    $p0 =~ s,.*/,,;
    # $p0 = `which $p0`; chomp $p0;
}

our $arg0 = _follow_interceptor_links($p0);
# compute the new executable name we are calling
our $prog = "${arg0}_orig";
our $raw_args = [@ARGV];
our $argv = [@ARGV];

# POSIXLY_CORRECT breaks objcopy
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
        my $logfile = "$ENV{HOME}/build_interceptor.log";
        $logfh = new FileHandle(">>$logfile") || die "$0: $!";
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

sub run_prog {
    logline("  system([$prog @$argv])");
    system($prog, @$argv);
    check_exit_code($?);
}

sub exec_prog {
    logline("  exec([$prog @$argv])");
    exec($prog, @$argv) or die "$0: couldn't exec $argv->[0]";
}

sub pipe_prog {
    # TODO: use IPC::Run
    logline("  pipe([$prog @$argv])");
    my $quoted_argv = [map{_quoteit($_)} @$argv];
    my $stdout = `$prog @$quoted_argv`;
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
    return Digest::MD5->new->addfile(new FileHandle($filename))->hexdigest;
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
        $prog = $l;
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
        die "$0: $prog didn't produce $outfile\n";
    }
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
