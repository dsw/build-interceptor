#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;
use Cwd;
use File::Basename;
use File::Path;
use File::Spec;
use File::Copy;
use Digest::MD5;
use FileHandle;

# When used as a replacement to the system cc1 or cc1plus this script
# will intercept the build process and keep a copy of the .i files
# generated.

#my $splash = "cc1_interceptor.pl:".getppid()."/$$: $0 @ARGV\n"; # LOUD
#warn $splash;                   # LOUD
#open (LOG, ">>$ENV{HOME}/build_interceptor.log") or die $!; # LOUD
#print LOG $splash;              # LOUD

my @av = @ARGV;                 # @ARGV has magic, so copy it
my $prog = "${0}_orig";         # compute the new executable name we are calling

# If we being invoked as a preprocessor, just delegate to the real
# thing.
if (grep {/^-E$/} @av) {
#    warn "non-compile call to $prog, @av\n";
    # system($prog, @av);
    # exit $? >> 8;
    exec($prog, @av) || die "$0: failed to exec @av";
}

# make a unique id for breaking symmetry with any other occurances of
# this process
my $time0 = time;
my $unique = "$$-$time0";

#  # print out our raw args
#  open OUT, ">>build.$unique.cc1_out" or die $!;
#  print OUT "---raw args---\n";
#  print OUT (join("\n", @av), "\n---end-args---\n");
my @raw_args = @av;

# mapping from build filesystem to isomorphic copy.  Make this
# directory.
my $prefix = "$ENV{HOME}/preproc";

# where are we?
my $pwd = getcwd;

# Input behavior:
# If you specify multiple input files, it just uses the last one.
# If there is no input file, it uses standard in.
#
# Assumptions:
# I assume any .i or .ii file is an input file and that no other files
# are input files.
# If you give as an input file '-' then it will make a file -.s as the
# output file!  I don't reproduce this behavior.

# If we have been told the original name of the file, use that.
my $orig_filename = '';
my @orig_filenames = grep {/^---build_interceptor-orig_filename=.*$/} @av;
if (@orig_filenames) {
  die "more than one orig_filenames" if ($#orig_filenames > 0);
  $orig_filenames[0] =~ /^---build_interceptor-orig_filename=(.*)$/;
  $orig_filename = File::Spec->rel2abs($1);
#    warn "tmpfile:${tmpfile}: from --build_interceptor-orig_filenames\n";
  @av = grep {!/^---build_interceptor-orig_filename=.*$/} @av;
}

# POSIXLY_CORRECT breaks objcopy
delete $ENV{POSIXLY_CORRECT};

sub ensure_dir_of_file_exists($) {
    my ($f) = (@_);
    mkpath(dirname($f));
}

sub md5_file {
    my ($filename) = @_;
    return Digest::MD5->new->addfile(new FileHandle($filename))->hexdigest;
}

my @infiles = grep {/\.ii?$/} @av; # get any input files
my $infile;
my $tmpfile;
my $rel_tmpfile;
if (@infiles) {
  $infile = $infiles[$#infiles]; # the last infile
  die "no such file $infile" unless -f $infile;
  @av = grep {!/\.ii?$/} @av;   # remove from @av
  # we need an absolute name for $infile
  my $infile_abs = File::Spec->rel2abs($infile);
  die unless -f $infile_abs;
  # make the temp file name
  if (defined $orig_filename) {
      $tmpfile = $orig_filename;
  } else {
      $tmpfile = $infile_abs;
  }
  $tmpfile =~ s|\.(.*)$|-$unique.$1|;
  die "not absolute filename:$tmpfile" unless $tmpfile =~ m|^/|;
  $rel_tmpfile = ".$tmpfile";
  $tmpfile = "$prefix$tmpfile";
  ensure_dir_of_file_exists($tmpfile);
  # put the contents there
  die "already a file $tmpfile" if -e $tmpfile;
  copy($infile_abs, $tmpfile) || die $!;
} else {
  # make the temp file name
  die unless $pwd =~ m|^/|;
  my $tmpdir = $pwd;
  if (defined $orig_filename) {
      $tmpfile = $orig_filename;
      $tmpfile =~ s|\.(.*)$|-$unique.$1|;
  } else {
      $tmpfile = "/STDIN-$unique";
  }
  die "not absolute filename:$tmpfile" unless $tmpfile =~ m|^/|;
  $tmpfile = "$tmpdir$tmpfile";
  $rel_tmpfile = ".$tmpfile";
  $tmpfile = "$prefix$tmpfile";
  ensure_dir_of_file_exists($tmpfile);
  # put the contents there
  die "already a file $tmpfile" if -e $tmpfile;
  copy(\*STDIN, $tmpfile) || die $!;
}
die "no such file $tmpfile" unless -f $tmpfile;

my $md5 = md5_file($tmpfile);

unshift @av, $tmpfile;        # add input file to @av

# Output behavior:
# You can specify an output file with -o FILE; the space before FILE is required
my $outfile;                    # the output file
my $dumpbase;                   # this seems to be the original source file
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
  } elsif ($av[$i] eq '-dumpbase') {
    if (defined $dumpbase) {
      # I suspect this will never happen; NOTE: it has been tested by
      # inserting artificial stuff into @av.
      $dumpbase .= ":";
      $dumpbase .= $av[$i+1];
    } else {
      $dumpbase = $av[$i+1];
    }
  }
}
# if file is '-' it uses standard out.
if (!defined $outfile) {
  # If you don't say, it uses standard out if the input was standard
  # in
  if (!@infiles) {
    $outfile = '-';
  }
  # Otherwise, it puts it in the last .i file mentioned with .i
  # replaced with .s
  else {
    $outfile = $infile;
    $outfile =~ s|\.ii?$|.s|;
  }
}
die unless defined $outfile;

# prefix with the name of the program we are calling
unshift @av, $prog;

# run
#  print OUT "---modified---\n";
#  print OUT (join("\n", @av), "\n---end-args---\n");
my $run_args = join(':', @av);
#warn "cc1_interceptor.pl: @av\n";
system(@av);
my $ret = $?;
my $exit_value = $ret >> 8;
if ($ret) {
  if ($exit_value) {
    exit $exit_value;
  } else {
    die "Failure return not reflected in the exit value: ret:$ret";
  }
}

if (!-f $outfile) {
    die "$0: $prog didn't produce $outfile\n";
}

# append metadata to output
my $metadata = <<'END1'         # do not interpolate
        .section        .note.cc1_interceptor,"",@progbits
END1
  ;

# initialize anything still uninitialized
$infile = '-' unless defined $infile;
$dumpbase = '' unless defined $dumpbase;
$metadata .= <<END2             # do interpolate!
        .ascii "("
        .ascii "\\n\\tpwd:${pwd}"
        .ascii "\\n\\tdollar_zero:$0"
        .ascii "\\n\\traw_args: ("
END2
  ;

for my $a (@raw_args) {
  $metadata .= <<END2b          # do interpolate!
        .ascii "\\n\\t\\t${a}"
END2b
  ;
}

my $pkg = $ENV{BUILD_INTERCEPTOR_PACKAGE} || '';
my $timestamp = $ENV{BUILD_INTERCEPTOR_TIMESTAMP} || '';
my $chroot_id = $ENV{BUILD_INTERCEPTOR_CHROOT_ID} || '';

$metadata .= <<END3             # do interpolate!
        .ascii "\\n\\t)"
        .ascii "\\n\\trun_args:${run_args}"
        .ascii "\\n\\torig_filename:${orig_filename}"
        .ascii "\\n\\tinfile:${infile}"
        .ascii "\\n\\tdumpbase:${dumpbase}"
        .ascii "\\n\\ttmpfile:${tmpfile}"
        .ascii "\\n\\tifile:${rel_tmpfile}"
        .ascii "\\n\\tpackage:${pkg} ${timestamp} ${chroot_id}"
        .ascii "\\n\\tmd5:${md5}"
        .ascii "\\n)\\n"
END3
  ;

if ($outfile eq "-") {
  print $metadata;
} else {
  die unless -f $outfile;
  open (FILEOUT, ">>$outfile") or die $!;
  print FILEOUT $metadata;
  close (FILEOUT) or die $!;
}

# exit
#  close OUT or die $!;
#close (LOG) or die $!;          # LOUD
exit $exit_value;               # exit with the same value as cc1 did
