#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;

#my $splash = "make_interceptor.pl:".getppid()."/$$: $0 @ARGV\n"; # LOUD
#warn $splash;                   # LOUD
#open (LOG, ">>$ENV{HOME}/build_interceptor.log") or die $!; # LOUD
#print LOG $splash;              # LOUD

# When used as a replacement to the system as will just pass the
# arguments through.

# first, see if we need to map ${0} to a canonical name
my %canonName =
  ('/usr/bin/gmake' => '/usr/bin/make'
);
my $dollar_zero = ${0};
#  warn "before: $dollar_zero\n";
$dollar_zero =~ s/_interceptor[.]pl$//;
if (defined $canonName{$dollar_zero}) {
  $dollar_zero = $canonName{$dollar_zero};
}
#  warn "after: $dollar_zero\n";

# compute the new executable name we are calling
my $prog = "${dollar_zero}_orig";

# Remove the -j argument.  If we are going to replay the build
# process, I want the order in which things are built to be as
# canonical as possible.

my @av;
my $skip_next = 0;
for my $a (@ARGV) {
  if ($skip_next) {
    $skip_next = 0;
    next;
  }
  if ($a =~ /^-j/) {
    die "FIX: this is wrong; you can give a -j without an argument " .
      "and I would eat the next argument in that case";
    if ($a eq '-j') {
      # of the form '-j 2'
      $skip_next = 1;
#      warn "form 2";
    } else {
      # of the form '-j2'
#      warn "form 1";
    }
    next;
  }
  # not an argument we want to exclude, so let it through
  push @av, $a;
}

# Just delegate to the real thing.
#warn "make_interceptor.pl: $prog @av";
#close (LOG) or die $!;          # LOUD
exec($prog, @av);
