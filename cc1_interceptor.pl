#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;

# When used as a replacement to the system cc1 this script will
# intercept the build process and keep a copy of the .i files
# generated.

# mapping from build filesystem to isomorphic copy.  Make this
# directory.
my $prefix = "$ENV{HOME}/preproc";

my @av = @ARGV;                 # @ARGV has magic, so copy it
my $prog = $0;                  # perhaps $0 does as well

#  # print out our raw args
#  open OUT, ">>build.$$.cc1_out" or die $!;
#  print OUT "---raw args---\n";
#  print OUT (join("\n", @av), "\n---end-args---\n");
my $raw_args = join(':', @av);

# where are we?
my $pwd = `pwd`;
chomp $pwd;

# Input behavior:
# If you specify multiple input files, it just uses the last one.
# If there is no input file, it uses standard in.
#
# Assumptions:
# I assume any .i or .ii file is an input file and that no other files
# are input files.
# If you give as an input file '-' then it will make a file -.s as the
# output file!  I don't reproduce this behavior.
my $tmpfile;
my @infiles = grep {/\.ii?$/} @av; # get any input files
my $infile;
if (@infiles) {
  $infile = $infiles[$#infiles]; # the last infile
  die "no such file $infile" unless -f $infile;
  @av = grep {!/\.ii?$/} @av;   # remove from @av
  # we need an absolute name for $infile
  my $infile_abs = $infile;
  if ($infile !~ m|^/|) {
    $infile_abs = "$pwd/$infile_abs";
  }
  die unless -f $infile_abs;
  # make the temp file name
  die unless $infile_abs =~ m|^/|;
  $tmpfile = "$prefix$infile_abs";
  $tmpfile =~ s|\.(ii?)$|-$$.$1|;
  my $tmpdir = $tmpfile;
  $tmpdir =~ s|/[^/]*$|/|; #/
  die if system("mkdir --parents $tmpdir");
  # put the contents there
  die "already a file $tmpfile" if -e $tmpfile;
  die $! if system("cp $infile_abs $tmpfile");
} else {
  # make the temp file name
  die unless $pwd =~ m|^/|;
  my $tmpdir = "$prefix$pwd";
  die if system("mkdir --parents $tmpdir");
  $tmpfile = "$tmpdir/STDIN-$$";
  # put the contents there
  die "already a file $tmpfile" if -e $tmpfile;
  open (TEMP, ">$tmpfile") or die $!;
  while(<STDIN>) {print TEMP $_;}
  close (TEMP) or die $!;
}
die "no such file $tmpfile" unless -f $tmpfile;
unshift @av, $tmpfile;        # add input file to @av

# Output behavior:
# You can specify an output file with -o FILE; the space before FILE is required
my $outfile;                    # the output file
my $dumpbase;                   # this seems to be the original source file
for (my $i=0; $i<@av; ++$i) {
  if ($av[$i] eq '-o') {
    die "multiple -o options" if defined $outfile;
    $outfile = $av[$i+1];
    die "-o without file" unless defined $outfile;
  } elsif ($av[$i] eq '-dumpbase') {
    if (defined $dumpbase) {
      # I suspect this will never happen; NOTE: it has been tested by
      # inserting artifical stuff into @av.
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

# turn off optimizations
#
# UPDATE; Don't do this: Ben says not to do this as the preprocessor
# is aware of the -O flags and you can mess things up for example with
# inlined math functions, which I have observed does indeed happen.  I
# leave it here uncommented so you don't think of it yourself and try
# it.
#
#  @av = grep {!/^-O\d?$/} @av;
#  unshift @av, '-O0';

# compute the new executable name we are calling
$prog =~ s|([^/]+)$|old-$1|;
unshift @av, $prog;

# run
#  print OUT "---modified---\n";
#  print OUT (join("\n", @av), "\n---end-args---\n");
my $run_args = join(':', @av);
system(@av);
my $exit_value = $? >> 8;

# append metadata to output
my $metadata = <<'END1'         # do not interpolate
        .section        .note.cc1_im,"",@progbits
END1
  ;

# initialize anything still uninitialized
$infile = '-' unless defined $infile;
$dumpbase = '' unless defined $dumpbase;
$metadata .= <<END2             # do interpolate!
        .ascii "("
        .ascii "\\n\\tdollar_zero:$0"
        .ascii "\\n\\traw_args:${raw_args}"
        .ascii "\\n\\trun_args:${run_args}"
        .ascii "\\n\\tpwd:${pwd}"
        .ascii "\\n\\tinfile:${infile}"
        .ascii "\\n\\tdumpbase:${dumpbase}"
        .ascii "\\n\\ttmpfile:${tmpfile}"
        .ascii "\\n)\\n"
END2
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
exit $exit_value;               # exit with the same value as cc1 did
