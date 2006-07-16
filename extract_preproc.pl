#!/usr/bin/perl -w
# -*-perl-*-
# See License.txt for copyright and terms of use
use strict;
use FindBin;

# Given an input ELF file infile and a non-existant directory name
# outdir:
# 1) read the notes and extract the names of the .i files embedded and
#   the sections where embedded
# 2) extract those sections and put them all into a new directory of
#   the given name

# NOTE: I don't know why, but emacs CPerl mode does not work for this
# file.

my $infile;
my $outdir;
my %md5sum2orig_filename;
my %md5sum2friendly_name;
my %friendly_name2md5sum;

my $extract_section = "${FindBin::RealBin}/extract_section.pl";
die "Can't find $extract_section" unless -f $extract_section;

sub read_command_line {
  while(@ARGV) {
    my $arg = shift @ARGV;
    if ($arg =~ /-infile/) {
      $infile = shift @ARGV;
    } elsif ($arg =~ /-outdir/) {
      $outdir = shift @ARGV;
    } else {
      die "Illegal argument $arg";
    }
  }
  # verify
  die "provide an infile using the flag -infile" unless $infile;
  die "no such file: $infile" unless -f $infile;
  die "provide an outdir using the flag -outdir" unless $outdir;
  die "directory already exists: $outdir" if -e $outdir;
}

sub read_cc1_notes {
  my $extract_sectionCmd = "$extract_section .note.cc1_interceptor $infile 2>/dev/null";
#    print "$extract_sectionCmd\n";
  my $exOut = `$extract_sectionCmd`;
  die "no cc1_interceptor notes in $infile" if $exOut eq '';
  eval {
    # for each .i file mentioned:
    my @components = ($exOut =~ m/\s* ( ^ \( $ .*? ^ \) $ ) \s*/gmsx);
    for my $comp (@components) {
#        print "---- comp\n";
#        print "$comp\n";
#        print "\n----\n";
      my ($pwd, $dollar_zero, $raw_args, $run_args, $orig_filename,
          $infile, $dumpbase, $tmpfile, $ifile, $package0, $md5) =
        $comp =~
      m|   ^\t pwd:           (.*?) $
        \n ^\t dollar_zero:   (.*?) $
        \n ^\t raw_args: \s \(   $
          (.*?)
        \n ^\t \)                $
        \n ^\t run_args:      (.*?) $
        \n ^\t orig_filename: (.*?) $
        \n ^\t infile:        (.*?) $
        \n ^\t dumpbase:      (.*?) $
        \n ^\t tmpfile:       (.*?) $
        \n ^\t ifile:         (.*?) $
        \n ^\t package:       (.*?) $
        \n ^\t md5:           (.*?) $
        |xsm;
      die "bad ELF file: $extract_sectionCmd" unless
          defined $pwd           &&
          defined $dollar_zero   &&
          defined $raw_args      &&
          defined $run_args      &&
          defined $orig_filename &&
          defined $infile        &&
          defined $dumpbase      &&
          defined $tmpfile       &&
          defined $ifile         &&
          defined $package0      &&
          defined $md5;

      # **** get what we want out of it
      $md5sum2orig_filename{$md5} = $orig_filename;
    }
  };
  print ($@) if ($@);
}

sub try_one_prefix {
    my ($len) = @_;
    %friendly_name2md5sum = ();
    # try this prefix length of the md5 to see if it makes things
    # unique
    while(my ($md5, $orig_filename) = each %md5sum2orig_filename) {
        $md5 =~ /(.{$len})/;
        my $stuff = $1;
        die unless length($stuff) == $len;
        my $delim = $len ? '_' : ''; # don't use a delimiter if using none of the md5
        $orig_filename =~ m|^.*?([^/]*)(\.[^\.]+)$| or die "can't match name '$orig_filename'";
        my ($stem, $suffix) = ($1, $2);
        my $friendly_name = "${stem}${delim}${stuff}${suffix}";
        if ($friendly_name2md5sum{$friendly_name}) {
            # name collision; abort and try a longer prefix
            return 0;
        } else {
            $friendly_name2md5sum{$friendly_name} = $md5;
        }
    }
    return 1;
}

sub compute_friendly_names {
    # yes, <= 32
    for (my $len=0; $len<=32; ++$len) {
        # try a prefix of length $len
        if (try_one_prefix($len)) {
            return;
        }
    }
    die "No fucking way can this ever happen.  Go buy a lottery ticket today.";
}

sub reverse_friendly_name_map {
    die if %md5sum2friendly_name;
    while(my ($friendly_name, $md5) = each %friendly_name2md5sum) {
        $md5sum2friendly_name{$md5} = $friendly_name;
    }
}

sub extract_preproc_sections {
  while(my ($md5, $orig_filename) = each %md5sum2orig_filename) {
#    print "extracting md5:$md5, orig_filename:$orig_filename\n";
    my $friendly_name = $md5sum2friendly_name{$md5};
    die unless defined $friendly_name;
    my $outfile = "$outdir/$friendly_name";
    die "something's wrong: file already exists: $outfile" if -e $outfile;
    my $extract_sectionCmd = "$extract_section .file.$md5 $infile 2>/dev/null > $outfile";
#    print "$extract_sectionCmd\n";
    die "command failed" if system($extract_sectionCmd);
  }
}

# ****

read_command_line();
read_cc1_notes();
die "directory exists: $outdir" if -e $outdir;
mkdir $outdir or die "can't make directory $outdir";
compute_friendly_names();
reverse_friendly_name_map();
extract_preproc_sections();
