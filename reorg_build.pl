#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;
use FindBin;
use IO::File;

# Reorganize the build and preproc directories into the ball
# directory.

my $home = "$ENV{HOME}";

# Directory containing one sub-directory where each project was built.
my $build = "$home/build";

# Directory that was used by cc1_interceptor.pl to store the
# intercepted preprocessed output in .i files.
my $oldpreproc = "$home/preproc";

# If you moved the preproc directory after building, you need to say
# where you moved it to here; this is because the preproc directory
# names are embedded into the ELF files and we need to know how to
# translate them into the real locations
my $newpreproc = $oldpreproc;

# Directory to put the reorganized output into.
my $ball = "$home/ball";

# timing state
my $all_start_time;
my $all_stop_time;

# http://gcc.gnu.org/onlinedocs/gcc-3.4.0/gcc/Invoking-G--.html#Invoking%20G++
# "C++ source files conventionally use one of the suffixes .C, .cc,
# .cpp, .CPP, .c++, .cp, or .cxx; C++ header files often use .hh or
# .H; and preprocessed C++ files use the suffix .ii."
my %is_cpp_suffix;
for my $suff(qw(C cc cpp CPP c++ cp cxx)) {
  $is_cpp_suffix{$suff}++;
}

# extract command
my $extract = "${FindBin::RealBin}/extract_section.pl";
die "Can't find $extract" unless -f $extract;

# tmpfiles that we have seen and that we already have a hardlink to
my %tmpfileToArtname;
my %packages;

sub read_command_line {
  while(@ARGV) {
    my $arg = shift @ARGV;
    if ($arg =~ /-build/) {
      $build = shift @ARGV;
    } elsif ($arg =~ /-oldpreproc/) {
      $oldpreproc = shift @ARGV;
    } elsif ($arg =~ /-newpreproc/) {
      $newpreproc = shift @ARGV;
    } elsif ($arg =~ /-ball/) {
      $ball = shift @ARGV;
    } else {
      die "Illegal argument: $arg";
    }
  }
}

sub validate_state {
  die unless -d $build;
  die unless -d $ball;
  die unless -d $newpreproc;
}

sub start_timing {
  die unless system ("date") == 0;
  $all_start_time = `date +'%s'`;
  chomp $all_start_time;
}

sub stop_timing {
  die unless system ("date") == 0;
  my $all_stop_time = `date +'%s'`;
  chomp $all_stop_time;
}

sub do_one_file {
  my ($f, $f_friendlyname, $pkgdir) = @_;
  die unless -f $f;
  my $extractCmd = "$extract .note.cc1_interceptor $f 2>/dev/null";
#    print "$extractCmd\n";
  my $exOut = `$extractCmd`;
  return if $exOut eq '';
  eval {
    # make a FILE.ld file in the package
    $f_friendlyname =~ s|^.*/([^/]*)$|$1|;
    die "does not match:$f" if $f_friendlyname eq '';
    my $ldFile = "$pkgdir/$f_friendlyname.ld";
    # check for collisions
    if (-e $ldFile) {
      for (my $i = 1; 1; ++$i) {
        $ldFile = "${pkgdir}/${f_friendlyname}.${i}.ld";
        last if (! -e $ldFile);
      }
    }
    print "ldFile:$ldFile\n";
    open (LD_FILE, ">$ldFile") or die $!;

    # for each .i file mentioned:
    my @components = ($exOut =~ m/\s* ( ^ \( $ .*? ^ \) $ ) \s*/gmsx);
    for my $comp (@components) {
#        warn "---- comp\n";
#        warn "$comp\n";
#        warn "\n----\n";
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
      die "bad ELF file: $extractCmd" unless
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
#        die "tmpfile undefined; extractCmd:$extractCmd; comp---\n$comp\n---\n"
#          unless defined $tmpfile;
#        print "extracted tmpfile: $tmpfile\n";

      die "bad ld file: $extractCmd"
        unless $tmpfile =~ s|^$oldpreproc|$newpreproc|;

      die "no such file tmpfile:$tmpfile"
        unless -f $tmpfile;

      # check if we have seen this tempfile before
      my $artName;
      if ($tmpfileToArtname{$tmpfile}) {
        $artName = $tmpfileToArtname{$tmpfile};
        print "reusing name; tmpfile:$tmpfile; artName:$artName\n";
        die "no such file $artName" unless -f $artName;
      } else {
        # Make an artifical name for it and enter it into the map
        # from real paths to artifical names.
        my $tf_friendlyname = $tmpfile;
        $tf_friendlyname =~ s|^.*/([^/]*)$|$1|;
        die "does not match:$f" if $tf_friendlyname eq '';
        $artName = "$pkgdir/$tf_friendlyname";

        # End this name in .i or .ii if the original is so; otherwise,
        # look at the first line.
        unless ($artName =~ /\.ii?$/) {
          my $isC = 1;          # default to assuming that it is C

          # get the first line of the file
          my $firstline;
          open (F, $tmpfile) or die $!;
          while (<F>) {
            die if defined $firstline; # ensure just one iteration around the loop
            $firstline = $_;
            last;               # we only want the first line
          }
          close (F) or die $!;

          # see if it is a C++ file
          if (defined $firstline) {
            if ($firstline =~ m|^# \d+ "\S+\.(\S+)"$|) {
              my $suffix = $1;
              #            print "suffix: $suffix\n";
              if ($is_cpp_suffix{$suffix}) {
                $isC = 0;
              }
            }
          }

          # fix the ending
          if ($isC) {
            $artName .= '.g.i';
          } else {
            $artName .= '.g.ii';
          }
        }
        die unless $artName =~ /\.ii?$/;

        # check for collisions
        if (-e $artName) {
          my ($base, $suff) = ($artName =~ m/^(.*)\.(ii?)$/);
          for (my $i = 1; 1; ++$i) {
            $artName = "$base.$i.$suff";
            last if (! -e $artName);
          }
        }

        #      print "artName:$artName\n";

        # Hardlink the artificial name to the real file.
        die if -e $artName;     # check one last time
        my $linkCmd = "ln $tmpfile $artName"; # NOTE: hardlink!
        die "$!: $linkCmd" if system($linkCmd);
        $tmpfileToArtname{$tmpfile} = $artName;
      }

      # Print its artificial name into the .ld file.
      print "\ttmpfile:$tmpfile artName:$artName\n";
      print LD_FILE "$artName\n";
    }

    close (LD_FILE) or die $!;
  };
  if ($@) {
    if ($@=~/^bad ld file:/) {
      print "$@\n";
    } else {
      print "ERROR: $@\n";
    }
  }
}

sub do_one_package {
  my ($pkg) = @_;
  die unless -d "$build/$pkg";

  print "**** $pkg: ";
  die if system("date");

  print "ERROR: duplicate package:$pkg" if $packages{$pkg};
  $packages{$pkg}++;

  # make a dir under ball
  my $pkgdir = "$ball/$pkg";

  # ARG!  This is very unsatisfying to simply comment-out, but
  # sometimes this test fails and what directory it is and whether or
  # not it fails is not reproducible.  Since it is redundant, since
  # the mkdir will fail if it already exists, I simply comment it out.
  #    die "already exists:$pkgdir" if -e $pkgdir;
  print "ERROR: already exists:$pkgdir" if -e $pkgdir;

  my $mkdirCmd = "mkdir $pkgdir";
  print "make directory:$mkdirCmd\n";
  # NOTE: this will fail if the directory already exists
  die "$!:$mkdirCmd" if system($mkdirCmd);

  # run a find script on that subtree of build
  my $findCmd = "find $build/$pkg -type f";
  my @files = split(/\n/, `$findCmd`);
  # skip some files we know aren't built by linking; NOTE: do not skip
  # .a files
  @files = grep
    {
      !/\.(txt|xml|dtd|html|gif|jpg|c|h|C|cc|cpp|CPP|c\+\+|cp|cxx|py|pl|tgz|tar|gz)$/}
      @files;

  # for each file, extract section '.note.cc1_interceptor'
  for my $f (@files) {
    if ($f=~/\.a$/) {
      # archive
      print "**** archive $f\n";
      my @arfiles = `ar t $f`;
      for my $arf (@arfiles) {
        chomp $arf;             # IMPORTANT
        # get a temporary name
        my $tempname;
        for (my $i=0; 1; ++$i) {
          # not a race because nobody is competing for this prefix
          $tempname = "/tmp/reorg_$i.o";
          last unless -e $tempname;
        }
        die if -e $tempname;
        my $arexCmd = "ar p $f $arf > $tempname";
        print "arexCmd: $arexCmd\n";
        die "couldn't extract: $arexCmd" if system("$arexCmd");
        die unless -f $tempname;
        my $friendlyname = "${f}.${arf}";
        do_one_file($tempname, $friendlyname, $pkgdir);
        unlink $tempname or die $!;
      }
      print "**** end archive $f\n";
    } else {
      # normal file
      do_one_file($f, $f, $pkgdir);
    }
  }
}

# ****

autoflush STDOUT 1;
autoflush STDERR 1;
read_command_line();
validate_state();

start_timing();
# for each package in build
my @packages = split(/\n/, `ls $build`);
for my $pkg (@packages) {
  chomp $pkg;
  do_one_package($pkg);
}
stop_timing();

my $all_total_time = $all_stop_time - $all_start_time;
print "all total time: $all_total_time\n";
