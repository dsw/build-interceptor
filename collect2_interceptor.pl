#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;

# When used as a replacement to the system collect2 will just pass the
# arguments through.

my @av = @ARGV;                 # @ARGV has magic, so copy it
my $prog = "${0}_orig";         # compute the new executable name we are calling

my @raw_args = @av;

# mapping from build filesystem to isomorphic copy.  Make this
# directory.
my $prefix = "$ENV{HOME}/preproc";

# where are we?
my $pwd = `pwd`;
chomp $pwd;

# Find the output file.
my $outfile;
for (my $i=0; $i<@av; ++$i) {
  if ($av[$i] =~ /^-o/) {
    die "multiple -o options" if defined $outfile;
    if ($av[$i] eq '-o') {
      $outfile = $av[$i+1];
      ++$i;
    } elsif ($av[$i] =~ /^-o(.*)$/) {
      $outfile = $1;
    } else {
      die "should have matched: $av[$i]"; # something is very wrong
    }
    die "-o without file" unless defined $outfile;
  }
}
die "no outfile specified" unless defined $outfile;
my $outfile_abs = $outfile;
if ($outfile_abs !~ m|^/|) {
  $outfile_abs = "$pwd/$outfile";
}

# We want to capture the output of the system call below.
my $tmpfile = "$prefix/collect2.$$.tmp";
die "tmpfile:$tmpfile exists !?" if -e $tmpfile;

# Print out the files that are linked in.
unshift @av, "--trace";
my $run_args = join(':', @av);

# We have to pass to the shell in order to collect from standard err
# or else re-write this all in C.  No, does not seem to be any way to
# use the list-argument version of system or exec and capture the
# stderr output of a subprocess without going all the way down to
# doing the process and pipe manipulation myself; I might then more
# easily do this in C.
sub quoteit {
  my ($arg) = @_;
  $arg =~ s|'|'\\''|;
  return "'$arg'";
}

my @av2 = map {quoteit($_)} @av;
my $cmd = $prog . ' ' . join(' ', @av2) . ' 2>&1';

# Just delegate to the real thing.
warn "collect2_interceptor.pl: system $cmd\n";
my $trace_output = `$cmd`;      # hidden system call here to run real linker
my $exit_value = $? >> 8;
die "no such file: $outfile_abs" unless -f $outfile_abs;

# Double-indent this to quote it.
$trace_output =~ s|^(.*)$|\t\t$1|gm;
# Make sure ends in a newline, since we count on that below for tab quoting.
die unless $trace_output =~ m|\n$|;

open (TMP, ">$tmpfile") or die $!;
#  print TMP $trace_output;
print TMP <<END1                # do interpolate!
(
\tpwd:${pwd}
\tdollar_zero:$0
\traw_args: (
END1
  ;

for my $a (@raw_args) {
print TMP <<END2b          # do interpolate!
\t\t${a}
END2b
  ;
}

print TMP <<END3                # do interpolate!
\t)
\trun_args:${run_args}
\tcmd:${cmd}
\ttmpfile:${tmpfile}
\toutfile:${outfile}
\toutfile_abs:${outfile_abs}
\ttrace_output: (
${trace_output}\t)
)
END3
  ;
close (TMP) or die $!;

# Stick this stuff into the object file
#  die "no such file:$tmpfile" unless -e $tmpfile;
#  die "no such file:$outfile_abs" unless -e $outfile_abs;

# You can't re-use a section name, and it seems that sometimes both
# collect2 and ld are called on the same file (?)
my $sec_name = `basename $0`;
chomp $sec_name;
die "bad sec_name:$sec_name:" unless
  $sec_name eq 'ld' ||
  $sec_name eq 'collect2';
my @objcopy_cmd =
  ('objcopy', $outfile_abs, '--add-section', ".note.${sec_name}_interceptor=$tmpfile");
warn "collect2_interceptor.pl: @objcopy_cmd";
die $! if system(@objcopy_cmd);

# Delete the temporary file.
unlink $tmpfile or die $!;

exit $exit_value;
