#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;

# Reorganize the ball_build and ball_preproc directories.

use IO::File;

autoflush STDOUT 1;
autoflush STDERR 1;

my $home = "$ENV{HOME}";

my $ball = "$home/ball";
die unless -d $ball;
my $ball_build = "$home/ball_build";
die unless -d $ball_build;
my $ball_preproc = "$home/ball_preproc";
die unless -d $ball_preproc;

my $extract = "$home/extract_section.pl";
die "Can't find $extract" unless -f $extract;

# tmpfiles that we have seen and that we already have a hardlink to
my %tmpfileToArtname;

# start timing
die unless system ("date") == 0;
my $all_start_time = `date +'%s'`;
chomp $all_start_time;

sub do_one_file {
  my ($f, $f_friendlyname, $pkgdir) = @_;
  die unless -f $f;
  my $extractCmd = "$extract .note.cc1_im $f 2>/dev/null";
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
    my @components = ($exOut =~ m/(\([^\)]*\))/g);
    for my $comp (@components) {
      #        print "---- comp\n";
      #        print $comp;
      #        print "\n----\n";
      my ($dollar_zero, $raw_args, $run_args, $pwd, $infile, $dumpbase, $tmpfile) =
        $comp =~
          m|dollar_zero:(.*)\s*
            raw_args:(.*)\s*
            run_args:(.*)\s*
            pwd:(.*)\s*
            infile:(.*)\s*
            dumpbase:(.*)\s*
            tmpfile:(.*)\s*
           |x;
      # we can get garbage sometimes; just skip it
      die "bad ld file: $extractCmd" unless
        defined $dollar_zero && 
          defined $raw_args && 
            defined $run_args && 
              defined $pwd && 
                defined $infile && 
                  defined $dumpbase && 
                    defined $tmpfile;
      #        die "tmpfile undefined; extractCmd:$extractCmd; comp---\n$comp\n---\n"
      #          unless defined $tmpfile;
      #        print "extracted tmpfile: $tmpfile\n";
      die "bad ld file: $extractCmd"
        unless $tmpfile =~ s|^$home/preproc|$home/ball_preproc|;

      # NOTE: it is not necessary for /disk2/ to exist on your system,
      # but it did on mine when these .i files where built.  If you
      # build them yourself, you will have to edit the next line.
      die "bad ld file: $extractCmd"
        unless $tmpfile = "/disk2/$tmpfile";

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
              if ($suffix eq 'cc' || $suffix eq 'C' || $suffix eq 'cxx'
                  || $suffix eq 'cpp' || $suffix eq 'c++') {
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

my %packages;

# for each package in ball_build
my @packages = split(/\n/, `ls $ball_build`);
#my @packages = qw(Glide3-20010520-13);
for my $pkg(@packages) {
  chomp $pkg;
  die unless -d "$ball_build/$pkg";

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
#  next;                         # REMOVE

  # run a find script on that subtree of ball_build
  my $findCmd = "find $ball_build/$pkg -type f";
  my @files = split(/\n/, `$findCmd`);
  # skip some files we know aren't built by linking; NOTE: do not skip
  # .a files
  @files = grep
    {!/\.(txt|xml|dtd|html|gif|jpg|c|h|cc|cpp|cxx|c\+\+|C|py|pl|tgz|tar|gz)$/}
      @files;

  # for each file, extract section '.note.cc1_im'
  for my $f (@files) {
    if ($f=~/\.a$/) {
      # archive
      print "**** archive $f\n";
      my @arfiles = `ar t $f`;
      for my $arf(@arfiles) {
        chomp $arf;             # IMPORTANT
        # get a temporary name
        my $tempname;
        for(my $i=0; 1; ++$i) {
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

# stop timing
die unless system ("date") == 0;
my $all_stop_time = `date +'%s'`;
chomp $all_stop_time;
my $all_total_time = $all_stop_time - $all_start_time;
print "all total time: $all_total_time\n";
