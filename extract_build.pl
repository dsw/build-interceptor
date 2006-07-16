#!/usr/bin/perl -w
# -*-perl-*-
# See License.txt for copyright and terms of use
use strict;
use FindBin;
use File::Copy;                 # move()

# One way to present the results of build-interceptor is a as an
# 'abstraction' of the build process: a directory containing the .i
# files and a Makefile such that typing 'make' replays the build.
# This script does that.

# Given an input ELF file infile and a non-existant directory name
# outdir, this script
# 1) reads the notes left by build interceptor
# 2) renders out a directory that containing an abstraction of the
#    build process

# command-line parameters
my $infile;                     # input ELF file that was intercepted
my $outdir;                     # the output directory containing the abstracted build

# other globals
my $srcdir;                     # source directory under the $outdir

# read from the ELF file
my $dash_l_flags = "";          # -l flags on the intercepted link line
# my $dash_O_flags = "";          # -O flags on the intercepted link line

my $real_bin = $FindBin::RealBin;

# scripts and files from build-interceptor that we need
my $extract_section  = "$real_bin/extract_section.pl";
my $extract_preproc  = "$real_bin/extract_preproc.pl";
my $generic_makefile = "$real_bin/extract_generic_Makefile";
my $main_makefile    = "$real_bin/extract_main_Makefile";
die "Can't find $extract_section"  unless -f $extract_section;
die "Can't find $extract_preproc"  unless -f $extract_preproc;
die "Can't find $generic_makefile" unless -f $generic_makefile;
die "Can't find $main_makefile"    unless -f $main_makefile;

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
    die "provide an outdir using the flag -outdir" unless $outdir;
}

# make the directory structure for the abstracted build
sub make_output_dirs {
    die "directory exists: $outdir" if -e $outdir;
    mkdir $outdir or die "can't make directory $outdir";
    $srcdir = "$outdir/src";
    # extract_preproc.pl will do this
    # mkdir $srcdir or die "can't make directory $srcdir";
}

# extract the preprocessed files
sub extract_preproc_files {
    my $extract_preprocCmd = "$extract_preproc -infile $infile -outdir $srcdir";
    print "$extract_preprocCmd\n";
    die "command failed: $extract_preprocCmd" if system($extract_preprocCmd);
}

# rename all the preprocessed files to end in .i
sub rename_preproc_files_to_i {
    opendir(DIR, $srcdir) or die "can't opendir $srcdir: $!";
    my @srcfiles = grep { $_ !~ m/^\./ && -f "$srcdir/$_" } readdir(DIR);
    closedir DIR or die "can't closedir $srcdir: $!";
    my %old2new_srcfiles;
    for my $old (@srcfiles) {
        my $new = $old;
        $new =~ s/\.[^\.]*$//;  # remove trailing filename ending
        $new .= '.i';           # add .i
        die "somehow got a duplicate name old:$old, new:$new"
            if defined $old2new_srcfiles{$old};
        die "new name collides with an old name old:$old, new:$new"
            if defined $old2new_srcfiles{$new};
        $old2new_srcfiles{$old} = $new;
    }
    while(my($old, $new) = each %old2new_srcfiles) {
#          print "renaming $old to $new\n";
        move("$srcdir/$old", "$srcdir/$new")
            or die "can't rename $srcdir/$old to $srcdir/$new\n";
    }
}

sub read_ld_notes {
#      print "read_ld_notes\n";
    my $extract_sectionCmd = "$extract_section .note.ld_interceptor $infile 2>/dev/null";
    print "$extract_sectionCmd\n";
    my $exOut = `$extract_sectionCmd`;
    die "no ld_interceptor notes in $infile" if $exOut eq '';
    eval {
        # for each .i file mentioned:
        my @components = ($exOut =~ m/\s* ( ^ \( $ .*? ^ \) $ ) \s*/gmsx);
        for my $comp (@components) {
#              print "---- comp\n";
#              print "$comp\n";
#              print "\n----\n";
            my ($pwd, $dollar_zero, $raw_args, $run_args, $outfile, $outfile_abs, $trace_output) =
                $comp =~
                    m| ^\t pwd:           (.*?) $
                    \n ^\t dollar_zero:   (.*?) $
                    \n ^\t raw_args: \s \(   $
                        (.*?)
                    \n ^\t \)                $
                    \n ^\t run_args:      (.*?) $
                    \n ^\t outfile:       (.*?) $
                    \n ^\t outfile_abs:   (.*?) $
                    \n ^\t trace_output: \s \(  $
                        (.*?)
                    \n ^\t \)                $
                    |xsm;
            die "bad ELF file: $extract_sectionCmd" unless
                defined $pwd           &&
                defined $dollar_zero   &&
                defined $raw_args      &&
                defined $run_args      &&
                defined $outfile       &&
                defined $outfile_abs   &&
                defined $trace_output;
#              print "pwd:$pwd\ndollar_zero:$dollar_zero\nraw_args:$raw_args\nrun_args:$run_args\noutfile:$outfile\noutfile_abs:$outfile_abs\ntrace_output:$trace_output\n";
#              my @raw_args_list = map {s/^\t\t// or die "bad raw_args:$_"} split /\n/, $raw_args;
            my @raw_args_list = ($raw_args =~ m/^\t\t(.*)$/mg);
#              print ("raw_args_list: " . join('\n', @raw_args_list) . "\n");

            # **** get what we want out of it
            $dash_l_flags .= join(' ', grep { $_ =~ m/^-l/ } @raw_args_list);
            print "dash_l_flags:$dash_l_flags\n";
# arg, no such thing as a linker argument
#            $dash_O_flags .= join(' ', grep { $_ =~ m/^-O/ } @raw_args_list);
#            print "dash_O_flags:$dash_O_flags\n";
        }
    };
    print ($@) if ($@);
}

# set up the makefiles in the output dir that are an abstraction of
# the build process
sub make_output_makefiles {
    # copy in generic makefile
    my $linkCmd = "cp $generic_makefile $outdir/generic_Makefile";
    print "$linkCmd\n";
    die "command failed: $linkCmd" if system($linkCmd);

    # copy in the main makefile
#      copy($main_makefile, "$outdir/Makefile") or die "can't copy";
    open (CONFIG, $main_makefile) or die "can't open: $main_makefile";
    open (CONFIG_OUT, ">$outdir/Makefile") or die "can't open: $outdir/Makefile";
    while(<CONFIG>) {
        s/\$\(error define LD-l\)/$dash_l_flags/;
# arg, no such thing as a linker argument, leave it
#          s/\$\(error define CFLAGS\)/$dash_O_flags/;
        print CONFIG_OUT $_;
    }
    close (CONFIG_OUT) or die "can't close: $outdir/Makefile";
    close (CONFIG) or die "can't close: $main_makefile";
}

# ****

read_command_line();
make_output_dirs();
extract_preproc_files();
rename_preproc_files_to_i();
read_ld_notes();
make_output_makefiles();
