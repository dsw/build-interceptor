#!/usr/bin/perl -w
# See License.txt for copyright and terms of use

use warnings;
use strict;
use FileHandle;

# Intercepts f771 to add a dummy .note.f771_interceptor, for now just so that
# the assembler interceptor knows this is coming from Fortran.

my @av = @ARGV;                 # @ARGV has magic, so copy it
my $prog = "${0}_orig";         # compute the new executable name we are calling
my @raw_args = @av;

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

my $outfile = find_output_filename();

# prefix with the name of the program we are calling
unshift @av, $prog;

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

if ($outfile ne '-' && !-f $outfile) {
    die "$0: $prog didn't produce $outfile\n";
}

# append metadata to output
my $metadata = <<'END1'         # do not interpolate
        .section        .note.f771_interceptor,"",@progbits
        .ascii "dummy\n"
END1
  ;

if ($outfile eq "-") {
    print $metadata;
} else {
    open (FILEOUT, ">>$outfile") or die $!;
    print FILEOUT $metadata;
    close (FILEOUT) or die $!;
}

exit $exit_value;
