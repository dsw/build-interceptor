#!/usr/bin/perl -w
# See License.txt for copyright and terms of use

use warnings;
use strict;
use FindBin;
use File::Spec;

my $extract_pl = "${FindBin::RealBin}/extract_section.pl";
if (!-f $extract_pl) {
    die "$0: Couldn't find extract_section.pl (should be $extract_pl)\n";
}

#my $splash = "as_interceptor.pl:".getppid()."/$$: $0 @ARGV\n"; # LOUD
#warn $splash;                   # LOUD
#open (LOG, ">>$ENV{HOME}/build_interceptor.log") or die $!; # LOUD
#print LOG $splash;              # LOUD

my @av = @ARGV;                 # @ARGV has magic, so copy it
my @raw_args = @ARGV;
my $prog = "${0}_orig";         # compute the new executable name we are calling

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

sub do_not_add_interceptions_to_this_file {
    my ($outfile_abs) = @_;
    my $r = $ENV{BUILD_INTERCEPTOR_DO_NOT_ADD_INTERCEPTIONS_TO_FILES};
    return ($r and $outfile_abs =~ /^$r$/);
}

unshift @av, $prog;

# delegate to the real thing.
#close (LOG) or die $!;          # LOUD
system (@av);

my $ret = $?;
my $exit_value = $ret >> 8;
if ($ret) {
    if ($exit_value) {
        exit $exit_value;
    } else {
        die "$0: Failure return not reflected in the exit value: ret:$ret";
    }
}

my $outfile = find_output_filename();

my $outfile_abs = File::Spec->rel2abs($outfile);

if (!-f $outfile) {
    die "$0: @av didn't produce $outfile\n";
}

if (do_not_add_interceptions_to_this_file($outfile_abs)) {
    # there shouldn't be an .notes at this point, but don't add or check for
    # more.
    exit(0);
}

my $cc1_note = `$extract_pl .note.cc1_interceptor $outfile 2>/dev/null`;
if ($? || !$cc1_note) {
    my $f771_note = `$extract_pl .note.f771_interceptor $outfile 2>/dev/null`;
    if ($f771_note && !$?) {
        # Ignore fortran files for now
        exit 0;
    }

    die "$0: assembled file with no .note.cc1_interceptor: $outfile\n";
}

my ($tmpfile) = ($cc1_note =~ /^\ttmpfile:(.*)$/m) or
  die "$0: couldn't find tmpfile in .note.cc1_interceptor in $outfile:\n$cc1_note\n";
my ($md5) = ($cc1_note =~ /^\tmd5:(.*)$/m) or
  die "$0: couldn't find md5 in .note.cc1_interceptor in $outfile:\n$cc1_note\n";


if (!-f $tmpfile) {
    die "$0: couldn't find tmpfile $tmpfile from $outfile\n";
}

system('objcopy', $outfile, '--add-section', ".file.$md5=$tmpfile") &&
  die "$0: couldn't objcopy .file.$md5=$tmpfile";
