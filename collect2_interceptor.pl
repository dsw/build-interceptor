#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";

# When used as a replacement to the system collect2 will just pass the
# arguments through.

warn "collect2_interceptor.pl:".getppid()."/$$: $0 @ARGV\n";

my @av = @ARGV;                 # @ARGV has magic, so copy it
my $prog = "${0}_orig";         # compute the new executable name we are calling

my @raw_args = @av;

# make a unique id for breaking symmetry with any other occurances of
# this process
my $time0 = time;
my $unique = "$$-$time0";

my $tmpdir = "/tmp/build_interceptor";
mkdir $tmpdir unless -e $tmpdir;
my $cachedir = "/tmp/build_interceptor/cache";
mkdir $cachedir unless -e $cachedir;
my $cachedir_ok = "/tmp/build_interceptor/cache/ok/";
mkdir $cachedir_ok unless -e $cachedir_ok;
my $cachedir_bad = "/tmp/build_interceptor/cache/bad/";
mkdir $cachedir_bad unless -e $cachedir_bad;

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
my $tmpfile = "/tmp/build_interceptor/collect2/tmp.$unique";
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
#warn "collect2_interceptor.pl: system $cmd\n";
my $trace_output0 = `$cmd`;      # hidden system call here to run real linker
my $ret = $?;
my $exit_value = $ret >> 8;
if ($ret) {
  if ($exit_value) {
    exit $exit_value;
  } else {
    die "Failure return not reflected in the exit value: ret:$ret";
  }
}

die "no such file: $outfile_abs" unless -f $outfile_abs;

# Double-indent this to quote it.
my $trace_output = $trace_output0;
$trace_output =~ s|^(.*)$|\t\t$1|gm;
# Make sure ends in a newline, since we count on that below for tab quoting.
die unless $trace_output =~ m|\n$|;

touchFile($tmpfile);
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

# You can't re-use a section name, and it seems that sometimes both
# collect2 and ld are called on the same file.  Update: It seems that
# collect2 calls ld.
my $sec_name = `basename $0`;
chomp $sec_name;
die "bad sec_name:$sec_name:" unless
  $sec_name eq 'ld' ||
  $sec_name eq 'collect2';

# test-only extract
my $extract = "${FindBin::RealBin}/extract_section.pl -t -q";

# why don't utilities like touch make all the interveening
# directories?
sub touchFile {
  my ($file) = @_;
  my $dirname = `dirname $file`;
  system ("mkdir --parents $dirname") == 0 or die $!;
  system ("touch $file") == 0 or die $!;
}

my @not_intercepted;
# if we are ld, then iterate through the .o files that were generated
# warn "trace_output0 -----\n$trace_output0\n-----\n";
for my $line (split '\n', $trace_output0) {
  chomp $line;

  # skip this line: /usr/bin/ld_orig: mode elf_i386
  next if $line =~ m/: mode elf_i386$/;

  my $file;
  if ($line =~ m/^\((.*)\)(.*)$/) {
    # a .o file from an archive, like this:
    # (/opt/gcc-X.XX/lib/gcc/i686-pc-linux-gnu/3.4.0/../../../libstdc++.a)globals_io.o
    my $archive = $1;
    # FIX: canonicalize the pathname
    my $file2 = $2;
    # see if the archive exists
    die "Something is wrong, no such archive $archive" unless -f $archive;
    # get the file out of the archive; NOTE: we want this name to be
    # purely a function of the archive and file names so that caching
    # below works
    my $ar_tmpfile = "/tmp/build_interceptor/collect2/archive/$archive/$file2";
    die "ar_tmpfile:${ar_tmpfile} exists !?" if -e $ar_tmpfile;
    touchFile($ar_tmpfile);
    my $cmd = "ar p $archive $file2 > $ar_tmpfile";
    die "failed: $cmd" if system($cmd)!=0;
    $file = $ar_tmpfile;
  } elsif ($line =~ m/^-lm \((.*)\)$/) {
    # one of these strange lines:
    # -lm (/usr/lib/libm.so)
    $file = $1;
    # FIX: canonicalize the pathname
  } elsif ($line =~ m/^(.*)$/) {
    # a .o file not from an archive, like this:
    # /usr/lib/crt1.o
    $file = $1;
    # FIX: canonicalize the pathname
  } else {
    die;
  }

  # see if the file exists
  die "Something is wrong, no such file :$file:" unless -f $file;

  # see if the file was the result of compiling with build
  # interception turned on
  my $built_with_interceptor;

  # check for cached results; from 'perldoc -f stat':
#    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
#        $atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
  my (undef,$ino,undef,undef,undef,undef,undef,undef,
      undef,$mtime,$ctime,undef,undef) = stat($file);
  my $file_id = "${ino}_${ctime}_${mtime}";
  my $cachefile_ok = "$cachedir_ok/$file_id";
  my $cachefile_bad = "$cachedir_bad/$file_id";
  if (-e $cachefile_ok) {
    $built_with_interceptor = 1;
  } elsif (-e $cachefile_bad) {
    $built_with_interceptor = 0;
  } else {
    # actually run the extractor
    my $cmd = "$extract .note.cc1_interceptor $file";
    system($cmd);
    $built_with_interceptor = ($?==0);
  }

  # record if ok or not
  if ($built_with_interceptor) {
    touchFile($cachefile_ok);   # update the cache
  } else {
    touchFile($cachefile_bad);  # update the cache
    push @not_intercepted, $line;
  }
}

if (@not_intercepted) {
  # bad; some files we were built with were not intercepted

  # put a bad file into the global space
  open (BAD, ">>$tmpdir/collect2_bad") or die $!;
  print BAD "$outfile\n";
  for my $input (@not_intercepted) {
    print BAD "\t$input\n";
  }
  close (BAD) or die $!;

  # put a bad section into the file
  my $bad_tmpfile = "/tmp/build_interceptor/collect2/bad_tmp.$unique";
  die "bad_tmpfile:$bad_tmpfile exists !?" if -e $bad_tmpfile;
  touchFile($bad_tmpfile);
  open (BAD, ">$bad_tmpfile") or die $!;
  for my $input (@not_intercepted) {
    print BAD "$input\n";
  }
  close (BAD) or die $!;
  my @objcopy_cmd =
    ('objcopy', $outfile_abs, '--add-section', ".note.${sec_name}_interceptor_bad=$bad_tmpfile");
  #warn "collect2_interceptor.pl: @objcopy_cmd";
  die $! if system(@objcopy_cmd);
  # Delete the temporary file.
  unlink $bad_tmpfile or die $!;
} else {
  # good
  open (GOOD, ">>$tmpdir/collect2_good") or die $!;
  print GOOD "$outfile";
  close (GOOD) or die $!;
}

# Stick this stuff into the object file
#  die "no such file:$tmpfile" unless -e $tmpfile;
#  die "no such file:$outfile_abs" unless -e $outfile_abs;

my @objcopy_cmd =
  ('objcopy', $outfile_abs, '--add-section', ".note.${sec_name}_interceptor=$tmpfile");
#warn "collect2_interceptor.pl: @objcopy_cmd";
die $! if system(@objcopy_cmd);

# Delete the temporary file.
unlink $tmpfile or die $!;

exit $exit_value;
