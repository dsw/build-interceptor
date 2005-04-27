#!/usr/bin/perl -w
# See License.txt for copyright and terms of use

use warnings;
use strict;
use FindBin;
use File::Spec;
use FileHandle;
use File::Basename;

if (!$ENV{HOME}) {
    $ENV{HOME} = "${FindBin::RealBin}/..";
}

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

sub find_input_filename {
    my @infiles = grep { /[.][sS]$/ } @av;
    return $infiles[0];
}

sub file_contains_ocaml_asm {
    # Returns 1 iff we think this .s file was the output of ocamlopt.  They're
    # named /tmp/camlasm*.s, and their contents start with ".data\n.globl
    # caml".

    my ($filename) = @_;
    return 0 unless $filename =~ m,^/tmp/caml.*[.]s$,;

    my $fh = new FileHandle($filename) or die;
    my ($l1, $l2) = <$fh>;
    return ($l1 && $l1 =~ /^\t[.]data/ and
            $l2 && $l2 =~ /^\t[.]globl\s+caml/);
}

sub file_is_empty_p {
    # returns 1 iff file is composed entirely of empty/comment lines

    my ($filename) = @_;
    my $fh = new FileHandle($filename) or die;
    local $_;
    for (<$fh>) {
        if (/^\s*#/) { next; }
        if (/^\s*$/) { next; }
        return 0;
    }
    return 1;
}

sub do_not_add_interceptions_to_this_file {
    my ($outfile_abs) = @_;
    my $r = $ENV{BUILD_INTERCEPTOR_DO_NOT_ADD_INTERCEPTIONS_TO_FILES};
    return ($r and $outfile_abs =~ /^$r$/);
}

unshift @av, $prog;

my $infile = find_input_filename();

if ($infile && -f $infile && file_is_empty_p($infile)) {
    # if the file was empty, remember so.  (This is needed later by
    # as_interceptor as well as collect2_interceptor)
    my $metadata = <<'END'         # do not interpolate
        .section        .note.as_interceptor_empty,"",@progbits
        .ascii "dummy\n"
END
;

    my $fh = new FileHandle(">>$infile") or die;
    print $fh $metadata;
}

my $lang = 'x';
if ($infile && -f $infile && file_contains_ocaml_asm($infile)) {
    # It's hard to intercept ocamlopt, so for now it's good enough to ignore
    # it here.
    $lang = 'ocaml';

    my $metadata = <<'END'         # do not interpolate
        .section        .note.ocaml_interceptor,"",@progbits
        .ascii "dummy\n"
END
;
    my $fh = new FileHandle(">>$infile") or die;
    print $fh $metadata;
}

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

# if ($infile && -f $infile && file_is_empty_p($infile)) {
#     # We don't need interceptions if the .S was empty.  Some packages have
#     # some #ifdefs that end up creating empty .S files -- it's OK to link
#     # them.

#     exit(0);
# }

if (do_not_add_interceptions_to_this_file($outfile_abs)) {
    # there shouldn't be an .notes at this point, but don't add or check for
    # more.
    exit(0);
}

my $cc1_note = `$extract_pl .note.cc1_interceptor $outfile 2>/dev/null`;
if ($? || !$cc1_note) {
    my $empty_note = `$extract_pl .note.as_interceptor_empty $outfile 2>/dev/null`;
    if ($empty_note && !$?) {
        # ignore empty .S files
        exit 0;
    }

    my $f771_note = `$extract_pl .note.f771_interceptor $outfile 2>/dev/null`;
    if ($f771_note && !$?) {
        # Ignore fortran files for now
        exit 0;
    }

    my $ocaml_note = `$extract_pl .note.ocaml_interceptor $outfile 2>/dev/null`;
    if ($ocaml_note && !$?) {
        # Ignore ocaml files for now
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

if (! $ENV{DONT_EMBED_PREPROC}) {
    system('objcopy', $outfile, '--add-section', ".file.$md5=$tmpfile") &&
      die "$0: couldn't objcopy .file.$md5=$tmpfile";
}
