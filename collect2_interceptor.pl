#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;
use FindBin;
use Cwd;
use Cwd 'abs_path';
use File::Spec;
use File::Path;                 # provides mkpath
use File::Basename;
use File::Temp;
use FileHandle;
use Digest::MD5;
use Memoize;

# When used as a replacement to the system collect2 will just pass the
# arguments through.

if (!$ENV{HOME}) {
    $ENV{HOME} = "${FindBin::RealBin}/..";
}

#my $splash = "collect2_interceptor.pl:".getppid()."/$$: $0 @ARGV\n"; # LOUD
#warn $splash;                   # LOUD
#open (LOG, ">>$ENV{HOME}/build_interceptor.log") or die $!; # LOUD
#print LOG $splash;              # LOUD

my @av = @ARGV;                 # @ARGV has magic, so copy it
my $prog = "${0}_orig";         # compute the new executable name we are calling

my @raw_args = @av;

if (grep {/^--help$/ || /^--version$/ || /^-[vV]$/ } @raw_args) {
    exec ( ($prog, @raw_args) ) || die "Couldn't exec $prog @raw_args\n";
}

# make a unique id for breaking symmetry with any other occurances of
# this process
my $time0 = time;
my $unique = "$$-$time0";

# directory for all build interceptor temporaries
my $tmpdir_interceptor = "$ENV{HOME}/build_interceptor_tmp";
mkpath($tmpdir_interceptor);
# directory for all the temporaries relevant to collect2 interceptor
my $tmpdir = "$tmpdir_interceptor/collect2";
mkpath($tmpdir);

# directory where we cache the "built with cc1" test
my $cc1_test_cache = "$tmpdir/cc1_test";
mkpath($cc1_test_cache);
my $cc1_test_cache_good = "$cc1_test_cache/good/";
mkpath($cc1_test_cache_good);
my $cc1_test_cache_bad = "$cc1_test_cache/bad/";
mkpath($cc1_test_cache_bad);

# directory where archives are unpacked
my $ar_cache = "$tmpdir/ar_cache";
mkpath($ar_cache);

# You can't re-use a section name, and it seems that sometimes both
# collect2 and ld are called on the same file.  Update: It seems that
# collect2 calls ld.
my $sec_name = basename($0);
die "bad sec_name:$sec_name:" unless
  $sec_name eq 'ld' ||
  $sec_name eq 'collect2';

# test-only extract
my $extract_pl = "${FindBin::RealBin}/extract_section.pl";
if (!-f $extract_pl) {
    die "Couldn't find extract_section.pl (should be $extract_pl)\n";
}
my $extract = "$extract_pl -t -q";

# POSIXLY_CORRECT breaks objcopy
delete $ENV{POSIXLY_CORRECT};

sub find_output_filename {
    my $outfile;

    for (my $i=0; $i<@raw_args; ++$i) {
        if ($raw_args[$i] =~ /^-o/) {
            die "multiple -o options" if defined $outfile;
            if ($raw_args[$i] eq '-o') {
                $outfile = $raw_args[$i+1];
                ++$i;
            } elsif ($raw_args[$i] =~ /^-o(.+)$/) {
                $outfile = $1;
            } else {
                die "should have matched: $raw_args[$i]"; # something is very wrong
            }
            die "-o without file" unless defined $outfile;
        }
    }

    if (!defined $outfile) {
        $outfile = 'a.out';
    }
    return $outfile;
}

sub md5_file {
    my ($filename) = @_;
    return Digest::MD5->new->addfile(new FileHandle($filename))->hexdigest;
}
memoize('md5_file');

sub canonicalize {
    my ($filename) = @_;
    if (!-f $filename) {
        die "$0: can't find $filename";
    }
    my $canon = Cwd::realpath(File::Spec->rel2abs($filename));
    if (!$canon) {
        die "$0: can't find $filename";
    }
    if (!-f $canon) {
        die "$0: can't find $filename [$canon]";
    }
    return $canon;
}

sub archive_extract_object {
    my ($archive, $object) = @_;
    if (!-f $archive) {
        die "$0: archive not found: $archive";
    }

    my $md5sum = md5_file($archive);
    my $dname = "$ar_cache/$md5sum";

    if (!-d $dname) {
        mkdir $dname || die;
        if (system("cd $dname && ar x $archive")) {
            die;
        }
    }

    my $file = "$dname/$object";
    if (! -f $file) {
        die "Couldn't find archive $archive object $object";
    }

    return $file;
}

sub check_object_intercepted {
    my ($file) = @_;
    return 0 == system("$extract .note.cc1_interceptor $file");
}

sub check_object_interceptless {
    my ($file) = @_;
    return 0 == system("$extract .note.ignore_cc1_interceptor $file");
}

sub check_object_fortran_only {
    # check that an executable was Fortran, and not C/C++
    my ($file) = @_;
    return ((0==system("$extract .note.f771_interceptor $file")) &&
            (!check_object_intercepted($file)));
}

sub check_object_has_ld_interception {
    my ($file) = @_;
    return 0 == system("$extract .note.ld_interceptor $file");
}

sub add_section {
    my ($file, $section, $content) = @_;

    my $tmpfile = new File::Temp(TEMPLATE=>"/tmp/elf.XXXXXXXXX");
    print $tmpfile $content;
    $tmpfile->close();

    my @objcopy_cmd =
      ('objcopy', $file, '--add-section', ".note.${section}=$tmpfile");
    if (system(@objcopy_cmd)) {
        die "$0: Error executing @objcopy_cmd\n";
    }
}

sub remove_section {
    my ($file, $section) = @_;
    my @cmd = ('objcopy', $file, '--remove-section', ".note.${section}");
    if (system(@cmd)) {
        die "$0: Error executing @cmd\n";
    }
}

sub add_or_append_section {
    my ($file, $section, $content) = @_;

    my $existing_note = `$extract_pl .note.$section $file 2>/dev/null`;
    my $err = $? >> 8;
    if ($err == 1) {
        # no existing note
        if ($existing_note) { die; }
    } elsif ($err == 0) {
        # existing note
        if (!$existing_note) { die; }
        remove_section($file, $section);
    } else {
        die "$0: unknown exit code extracting .note.$section from '$file': $err\n";
    }

    add_section($file, $section, $existing_note . $content);
}

sub do_not_add_interceptions_to_this_file {
    my ($outfile_abs) = @_;
    my $r = $ENV{BUILD_INTERCEPTOR_DO_NOT_ADD_INTERCEPTIONS_TO_FILES};
    return ($r and $outfile_abs =~ /^$r$/);
}

# where are we?
my $pwd = getcwd;

my $outfile = find_output_filename();
my $outfile_abs = File::Spec->rel2abs($outfile);

# Print out the files that are linked in.
unshift @av, "--trace";
my $run_args = join(':', @av);

my @av2 = map {quoteit($_)} @av;
my $cmd = $prog . ' ' . join(' ', @av2) ;
#. ' 2>&1';

# Don't catch stderr -- random error messages go there and can confuse us
# [this would break for example linking any object that invokes tmpnam()].

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

if (!-e $outfile_abs) {
    warn "$0: output file $outfile_abs not found\n";
    exit($exit_value || 1);
}

my $executable = -x $outfile_abs &&
 $outfile_abs !~ /[.](?:so(?:[.]\d+)*(?:-UTF8)?|la|al|o|lo|os|oS|po|opic|pic_o|sho)$/;

if (do_not_add_interceptions_to_this_file($outfile_abs)) {
    # Don't add .note.ld_interceptor, and in addition, remove
    # .note.cc1_interceptor.
    #
    # Some build processes break when we insert these; and we aren't going to
    # analyze them so it's OK to remove notes.
    remove_section($outfile_abs, 'cc1_interceptor');
    exit(0);
}

# Double-indent this to quote it.
my $trace_output = $trace_output0;
$trace_output =~ s|^(.*)$|\t\t$1|gm;
# Make sure ends in a newline, since we count on that below for tab quoting.
die unless $trace_output =~ m|\n$|;

my $intercept_data = '';


$intercept_data .= <<END        # do interpolate!
(
\tpwd:${pwd}
\tdollar_zero:$0
\traw_args: (
END
  ;

for my $a (@raw_args) {
$intercept_data .= <<END        # do interpolate!
\t\t${a}
END
  ;
}

$intercept_data .= <<END        # do interpolate!
\t)
\trun_args:${run_args}
\tcmd:${cmd}
\toutfile:${outfile}
\toutfile_abs:${outfile_abs}
\ttrace_output: (
${trace_output}\t)
)
END
  ;

my @not_intercepted;
# if we are ld, then iterate through the .o files that were generated
# warn "trace_output0 -----\n$trace_output0\n-----\n";
for my $line (split '\n', $trace_output0) {
  chomp $line;

  # skip this line: /usr/bin/ld_orig: mode elf_i386
  next if $line =~ m/: mode elf_i386$/;

  my $file;
  if ($line =~ m/^\(([^()]+[.]al?)\)([^()]+[.](?:o|os|oS|lo|ao))$/) {
      # .o from .a:
      # (/path/archive.a)object.o
      my $archive = canonicalize($1);
      my $object = $2;

      $file = archive_extract_object($archive, $object);
  } elsif ($line =~ m/^-l[^ ()]+ \(([^()]+[.]so(?:[.][0-9]+)*)\)$/) {
      # shared libraries:
      # -lm (/usr/lib/libm.so)
      # -lgtk (/opt/gnome/lib/libgtk.so)
      # ignore for now
      next;
      # $file = $1;
  } elsif ($line =~ m/^([^()]+\.(?:o|os|oS|lo|sho|po|opic|pic_o|ro))$/) {
      # a .o file not from an archive, like this:
      #   /usr/lib/crt1.o
      # Can also include .lo (libtool object) files.
      $file = canonicalize($1);
  } elsif ($line =~ m/^([^()]+\.so(?:[.][0-9]+)*(?:-UTF8)?)$/) {
      # $file = canonicalize($1);
      next;
  } else {
      die "unknown trace_output line: $line\n\nTrace output:\n$trace_output0";
  }

  # get the file id
  die "Something is wrong, no such file :$file:" unless -f $file;
  # my $file_id = getCanonIdForFile($file);
  my $file_id = md5_file($file);

  # see if the file was the result of compiling with build
  # interception turned on
  my $built_with_interceptor;

  # check the cc1 test cache; NOTE: in case you are afraid of the
  # complexity of this, for a simple C++ hello world on my system with
  # a warm cache the link time went from 5.9 seconds to 1.4 seconds
  my $cachefile_good = "$cc1_test_cache_good/$file_id";
  my $cachefile_bad = "$cc1_test_cache_bad/$file_id";
#    warn "cachefile_ok: '$cachefile_ok', cachefile_bad: '$cachefile_bad'\n";
  if (-e $cachefile_good) {
    $built_with_interceptor = 1;
#      warn "\tfound cache ok $cachefile_ok";
    # outputToFile($cachefile_ok, $file); # update the cache
  } elsif (-e $cachefile_bad) {
    $built_with_interceptor = 0;
#      warn "\tfound cache bad $cachefile_ok";
    # outputToFile($cachefile_bad, $file);  # update the cache
  } else {
      # actually run the extractor
      #      warn "\tNOT found in cache";
      $built_with_interceptor = check_object_intercepted($file) || check_object_interceptless($file) || check_object_fortran_only($file);
      if ($built_with_interceptor) {
          outputToFile($cachefile_good, $file); # update the cache
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
    my $bad = new FileHandle(">>$tmpdir/cc1_bad") or die $!;
    print $bad "$outfile_abs\n";
    for my $input (@not_intercepted) {
        print $bad "\t$input\n";
    }

    # categorize into executable and non-executable
    my $bad_ftype = $executable ? "exec" : "nonexec";
    $bad = new FileHandle(">>$tmpdir/cc1_bad_${bad_ftype}") or die $!;
    print $bad "$outfile_abs\n";
    for my $input (@not_intercepted) {
        print $bad "\t$input\n";
    }

    # put a bad section into the file
    my $bad_section_data = join("", map{"$_\n"} @not_intercepted);
    add_or_append_section($outfile_abs, "${sec_name}_interceptor_bad",
                          $bad_section_data);
} else {
    # good
    my $good = new FileHandle(">>$tmpdir/cc1_good") or die $!;
    print $good "$outfile_abs\n";
}

# Stick this stuff into the object file
add_or_append_section($outfile_abs, "${sec_name}_interceptor", $intercept_data);

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

sub touchFile {
    my ($file) = @_;
    mkpath(dirname($file));
    new FileHandle(">$file") || die $!;
}

sub outputToFile {
    my ($file, $data) = @_;
    die unless defined $file && defined $data;
    mkpath(dirname($file));
    my $f = new FileHandle(">>$file") || die $!;
    print $f $data;
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
