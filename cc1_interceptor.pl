#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;

# When used as a replacement to the system cc1 or cc1plus this script
# will intercept the build process and keep a copy of the .i files
# generated.

my @av = @ARGV;                 # @ARGV has magic, so copy it
my $prog = "${0}_orig";         # compute the new executable name we are calling

# If we being invoked as a preprocessor, just delegate to the real
# thing.
if (grep {/^-E$/} @av) {
#    warn "non-compile call to $prog, @av\n";
  system($prog, @av);
  exit $? >> 8;
}

#  # print out our raw args
#  open OUT, ">>build.$$.cc1_out" or die $!;
#  print OUT "---raw args---\n";
#  print OUT (join("\n", @av), "\n---end-args---\n");
my @raw_args = @av;

# mapping from build filesystem to isomorphic copy.  Make this
# directory.
my $prefix = "$ENV{HOME}/preproc";

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

# If we have been told the original name of the file, use that.
my $tmpfile;
my @orig_filenames = grep {/^---build_interceptor-orig_filename=.*$/} @av;
if (@orig_filenames) {
  die "more than one orig_filenames" if ($#orig_filenames > 0);
  $orig_filenames[0] =~ /^---build_interceptor-orig_filename=(.*)$/;
  $tmpfile = $1;
#    warn "tmpfile:${tmpfile}: from --build_interceptor-orig_filenames\n";
  @av = grep {!/^---build_interceptor-orig_filename=.*$/} @av;
}

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
  if (defined $tmpfile) {
    if ($tmpfile !~ m|^/|) {
      $tmpfile = "$pwd/$tmpfile";
    }
  } else {
    $tmpfile = $infile_abs;
  }
  $tmpfile =~ s|\.(.*)$|-$$.$1|;
  die "not absolute filename:$tmpfile" unless $tmpfile =~ m|^/|;
  $tmpfile = "$prefix$tmpfile";
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
  if ($tmpfile) {
    if ($tmpfile !~ m|^/|) {
      $tmpfile = "$pwd/$tmpfile";
    }
    $tmpfile =~ s|\.(.*)$|-$$.$1|;
  } else {
    $tmpfile = "/STDIN-$$";
  }
  die "not absolute filename:$tmpfile" unless $tmpfile =~ m|^/|;
  $tmpfile = "$tmpdir$tmpfile";
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

# prefix with the name of the program we are calling
unshift @av, $prog;

# run
#  print OUT "---modified---\n";
#  print OUT (join("\n", @av), "\n---end-args---\n");
my $run_args = join(':', @av);
#warn "cc1_interceptor.pl: @av\n";
system(@av);
my $exit_value = $? >> 8;

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

$metadata .= <<END3             # do interpolate!
        .ascii "\\n\\t)"
        .ascii "\\n\\trun_args:${run_args}"
        .ascii "\\n\\tinfile:${infile}"
        .ascii "\\n\\tdumpbase:${dumpbase}"
        .ascii "\\n\\ttmpfile:${tmpfile}"
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
exit $exit_value;               # exit with the same value as cc1 did
