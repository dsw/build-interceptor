#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;
use FindBin;
use lib "$FindBin::Bin/../lib";
use Cwd 'abs_path';

# When used as a replacement to the system collect2 will just pass the
# arguments through.

#my $splash = "collect2_interceptor.pl:".getppid()."/$$: $0 @ARGV\n"; # LOUD
#warn $splash;                   # LOUD
#open (LOG, ">>$ENV{HOME}/build_interceptor.log") or die $!; # LOUD
#print LOG $splash;              # LOUD

my @av = @ARGV;                 # @ARGV has magic, so copy it
my $prog = "${0}_orig";         # compute the new executable name we are calling

my @raw_args = @av;

# make a unique id for breaking symmetry with any other occurances of
# this process
my $time0 = time;
my $unique = "$$-$time0";

# directory for all build interceptor temporaries
my $tmpdir_interceptor = "$ENV{HOME}/build_interceptor_tmp";
mkdirParents($tmpdir_interceptor);
# directory for all the temporaries relevant to collect2 interceptor
my $tmpdir = "$tmpdir_interceptor/collect2";
mkdirParents($tmpdir);

# directory where we cache the "built with cc1" test
my $cc1_test_cache = "$tmpdir/cc1_test";
mkdirParents($cc1_test_cache);
my $cc1_test_cache_ok = "$cc1_test_cache/ok/";
mkdirParents($cc1_test_cache_ok);
my $cc1_test_cache_bad = "$cc1_test_cache/bad/";
mkdirParents($cc1_test_cache_bad);

# directory where archives are unpacked
my $ar_cache = "$tmpdir/ar_cache";
mkdirParents($ar_cache);

# directory where elf temporaries go before being inserted as an ELF
# section into the output file
my $elftemp = "$tmpdir/elf_tmp";
mkdirParents($elftemp);

# directory where bad temporaries go before being inserted as an ELF
# section into the output file
my $badtemp = "$tmpdir/bad_tmp";
mkdirParents($badtemp);

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

#die "no outfile specified" unless defined $outfile;
# Karl seems to want this feature
$outfile = 'a.out' unless defined $outfile;

my $outfile_abs = $outfile;
if ($outfile_abs !~ m|^/|) {
  $outfile_abs = "$pwd/$outfile";
}

# Temporary directory where we put the file that will become an ELF
# section.
my $tmpfile = "$elftemp/elftmp.$unique";
die "tmpfile:$tmpfile exists !?" if -e $tmpfile;

# Print out the files that are linked in.
unshift @av, "--trace";
my $run_args = join(':', @av);

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
    my $archive0 = $1;
    # FIX: canonicalize the pathname
    my $file2 = $2;
    # see if the archive exists
    die "Something is wrong, no such archive $archive0" unless -f $archive0;
    # get the file out of the archive; NOTE: we want this name to be
    # purely a function of the archive and contained file so that
    # caching below works; We have to use the inode and modification
    # times as the identity of the archive rather than its name for
    # the same reasons we have to do that for the cache; Note that I
    # do *not* canonicalize the filename within the archive because it
    # is relative to the archive.  Not sure exactly how names work
    # within an archive, but I don't think I have much choice and
    # having two entries with the same name in an archive would only
    # mean we did the same work twice.
#    warn "archive0 '$archive0'";
    die "bad filename ? $archive0"
      unless $archive0 =~ m|^(.*?)([^/]*)$|;
    my $ardir0 = $1;
    my $arfile0 = $2;
    die unless defined $ardir0 && defined $arfile0;
    # Map the empty string to "."; why do people put such
    # non-orthogonalities into their APIs?
    $ardir = "." unless length $ardir;
    my $ardir = abs_path($ardir0);
    my $archive = "$ardir/$arfile0";
    die "no such file $archive" unless -f $archive;
    my $ar_id = getCanonIdForFile($archive);
#      warn "getting id for archive: $archive, id:$ar_id\n";
    my $ar_dir = "$ar_cache/$ar_id";
    unless (-e $ar_dir) {
      mkdirParents($ar_dir);
      my $cmd = "cd $ar_dir; ar x $archive";
#        warn "extracting archive: $cmd\n";
      # FIX: this isn't working; I keep going even if the ar fails (?).
      die "failed: $cmd" if system($cmd);
    }
    $file = "$ar_dir/$file2";
  } elsif ($line =~ m/^-l\S* \((.*)\)$/) {
    # one of these strange lines:
    # -lm (/usr/lib/libm.so)
    # -lgtk (/opt/gnome/lib/libgtk.so)
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

  # get the file id
  die "Something is wrong, no such file :$file:" unless -f $file;
  my $file_id = getCanonIdForFile($file);

  # see if the file was the result of compiling with build
  # interception turned on
  my $built_with_interceptor;

  # check the cc1 test cache; NOTE: in case you are afraid of the
  # complexity of this, for a simple C++ hello world on my system with
  # a warm cache the link time went from 5.9 seconds to 1.4 seconds
  my $cachefile_ok = "$cc1_test_cache_ok/$file_id";
  my $cachefile_bad = "$cc1_test_cache_bad/$file_id";
#    warn "cachefile_ok: '$cachefile_ok', cachefile_bad: '$cachefile_bad'\n";
  if (-e $cachefile_ok) {
    $built_with_interceptor = 1;
#      warn "\tfound cache ok $cachefile_ok";
    outputToFile($cachefile_ok, $file); # update the cache
  } elsif (-e $cachefile_bad) {
    $built_with_interceptor = 0;
#      warn "\tfound cache bad $cachefile_ok";
    outputToFile($cachefile_bad, $file);  # update the cache
  } else {
    # actually run the extractor
#      warn "\tNOT found in cache";
    my $cmd = "$extract .note.cc1_interceptor $file";
    system($cmd);
    $built_with_interceptor = ($?==0);
    if ($built_with_interceptor) {
      outputToFile($cachefile_ok, $file); # update the cache
    } else {
      outputToFile($cachefile_bad, $file); # update the cache
    }
  }

  # record if ok or not
  unless ($built_with_interceptor) {
    push @not_intercepted, $line;
  }
}

if (@not_intercepted) {
  # bad; some files we were built with were not intercepted

  # put a bad file into the global space
  open (BAD, ">>$tmpdir/cc1_bad") or die $!;
  print BAD "$outfile\n";
  for my $input (@not_intercepted) {
    print BAD "\t$input\n";
  }
  close (BAD) or die $!;

  # put a bad section into the file
  my $bad_tmpfile = "$badtemp/badtmp.$unique";
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
  open (GOOD, ">>$tmpdir/cc1_good") or die $!;
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

#close (LOG) or die $!;          # LOUD
exit $exit_value;

# subroutines ****************

# get a canonical id for a file; this is better than the absolute path
# because the id will become invalid if the inode changes but also
# even if it or the file is modified
sub getCanonIdForFile {
  my ($filename) = @_;
  # check for cached results; from 'perldoc -f stat':
#    my ($dev,$ino,$mode,$nlink,$uid,$gid,$rdev,$size,
#        $atime,$mtime,$ctime,$blksize,$blocks) = stat($file);
  my (undef,$ino,undef,undef,undef,undef,undef,undef,
      undef,$mtime,$ctime,undef,undef) = stat($filename);
  die "no such file $filename"
    unless defined $ino && defined $mtime && defined $ctime;
  my $file_id = "${ino}_${ctime}_${mtime}";
  return $file_id;
}

# ensure a directory exists no matter how many levels deep we have to
# make
sub mkdirParents {
  my ($dirname) = @_;
  # NOTE: unlike normal mkdir, this works even if it already exists
  system ("mkdir --parents $dirname") == 0 or die $!;
}

# why don't utilities like touch make all the intervening directories?
sub touchFile {
  my ($file) = @_;
  my $dirname = `dirname $file`;
  mkdirParents($dirname);
  system ("touch $file") == 0 or die $!;
}

sub outputToFile {
  my ($file, $data) = @_;
  die unless defined $file && defined $data;
  my $dirname = `dirname $file`;
  mkdirParents($dirname);
  open (FILE, ">>$file") or die $!;
  print FILE $data;
  close (FILE) or die $!;
}

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
