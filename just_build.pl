#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;

# Build all the RPMs.

my $rpm_files = "RedHat7.3.files";

# This script contains code from The MOPS project
# (http://sourceforge.net/projects/mopscode) by Hao Chen where he and
# Geoff Morrison in particular worked on the build-process
# interception aspect.

my $home = "$ENV{HOME}";
my $build = "ball_build";
my $preproc = "ball_preproc";

my $build_dir = "$home/$build";
die unless -d $build_dir;
#  die if -e $build_dir;
#  die if system("mkdir $build_dir");

my $preproc_dir = $ENV{BUILD_INTERCEPTOR_PREPROC} || "$ENV{HOME}/preproc";
die unless -d $preproc_dir;
#  die if -e $preproc_dir;
#  die if system("mkdir $preproc_dir");
#  die if system("cd $home; ln -s $preproc preproc");

# Get the names of the PRM files to build.
my @rpm_files;
open (DATA, $rpm_files) or die $!;
while(<DATA>) {
  chomp;                        # remove any trailing newline
  s/\#.*$//;                    # remove comments
  s/^\s*//;                     # remove initial whitespace
  s/\s*$//;                     # remove trailing whitespace
  next if /^$/;                 # skip blank lines
  push @rpm_files, $_;
}
close (DATA) or die $!;

# start timing
die unless system ("date") == 0;
my $all_start_time = `date +'%s'`;
chomp $all_start_time;

# build each rpm
for my $rpm_file (@rpm_files) {
  # check if we should stop
  if (-f "BUILD_STOP") {
    print "stopping due to existence of BUILD_STOP\n";
    last;
  }

  # get the fully qualified name
  my $fq_rpm_file = "/usr/src/redhat/SRPMS/$rpm_file";
  die unless -f "$fq_rpm_file";

  # get the package name
  my $package = $rpm_file;
  $package =~ s/\.src\.rpm$//;
  print "**** package: $package\n";

  # time this package
  die unless system ("date") == 0;
  my $start_time = `date +'%s'`;
  chomp $start_time;

  # make the subdirectory names
  my $package_build_dir="$build_dir/$package";
  die if -d $package_build_dir;
  die if system("mkdir $package_build_dir");
  die if system("mkdir $package_build_dir/BUILD");
  # use the same dir for now as we generate no metadata
  #my $rpm_dir="$package_build_dir/RPM";
  my $rpm_dir="$package_build_dir";

  # extract the package
  my $extractCmd="rpm --define \"_topdir $rpm_dir\" -i $fq_rpm_file";
  print "$extractCmd\n";
  if (system($extractCmd)) {
    print "failed: $extractCmd\n";
    next;
  }

  # build each 'spec'(?) in the package
  my @specs = (split /\n/, `ls $rpm_dir/SPECS/*.spec`);
  for my $spec (@specs) {
    # use -bp instead of -bc if you want to just unpack and not
    # actually build the package
    my $mode = "-bc";           # unpack and build
#    my $mode = "-bp";           # unpack only
    my $buildCmd="rpmbuild --define \"_topdir $rpm_dir\" --nodeps $mode $spec";
    print "$buildCmd\n";
    if (system($buildCmd)) {
      print "****FAILED package:$package, spec:$spec, cmd:$buildCmd\n";
      last;
    }
  }

  # stop timing this package
  my $stop_time = `date +'%s'`;
  chomp $stop_time;
  my $total_time = $stop_time - $start_time;
  my $total_str = "done $package, time=$total_time";
}

# stop timing
die unless system ("date") == 0;
my $all_stop_time = `date +'%s'`;
chomp $all_stop_time;
my $all_total_time = $all_stop_time - $all_start_time;
print "all total time: $all_total_time\n";
