#!/usr/bin/make -f

# TODO: fix bug when e.g. gcc is a symlink to gcc-3.3

# This makefile will move your system gcc toolchain away and point
# softlinks at the intereceptor scripts.  Generally, run targets in
# this makefile as root.  Use Makefile to build intercept.progs as a
# normal user.

ifneq ($(notdir ${PWD}),build_interceptor)
  $(error Run this makefile in the build_interceptor directory under your HOME directory)
endif

# Print the current interception state.
.PHONY: print
print: intercept.progs
	@echo "Interception is:"
	@for F in `cat $<`; do        \
          if test -e $${F}_orig; then \
            echo -n "on";             \
          else                        \
            echo -n "off";            \
          fi;                         \
          echo " for $${F}";          \
        done

# Note: I use $PWD rather than $HOME because this script will be run
# as root and $HOME will be /root.  Just type 'cd build_interceptor'
# before su-ing to root.
#
# If you don't run these two targets as root then some non-atomic
# partial result may occur, so I check for you.
.PHONY: on
on: intercept.progs
	@if test `whoami` != root; then echo "run this target as root"; false; fi
	chmod a-w $<
	@for F in `cat $<`; do                                                                             \
          if readlink $${F} >/dev/null && grep -x -F `dirname $${F}`/`readlink $${F}` $< >/dev/null ; then \
            echo "Ignoring $${F} -- it's a symlink to `readlink $${F}`, also intercepted.";                \
          elif ! test -e $${F}_orig; then                                                                  \
            C="mv $$F $${F}_orig"; echo $$C; $$C;                                                          \
            I=`basename $${F} | sed 's,-.*,,'`;                                                            \
            if test -e $${I}_interceptor.pl -a -e $${I}_interceptor ; then                                 \
              C="ln -s ${PWD}/$${I}_interceptor $$F"; echo $$C; $$C;                                       \
              if ! test -e $${F}_interceptor.pl ; then                                                     \
                C="ln -s ${PWD}/$${I}_interceptor.pl $${F}_interceptor.pl";echo $$C; $$C;                  \
              fi                                                                                           \
            else                                                                                           \
              C="ln -s ${PWD}/$${I}_interceptor.pl $$F"; echo $$C; $$C;                                    \
            fi                                                                                             \
          else echo "Interception already on for $${F}";                                                   \
          fi                                                                                               \
        done

.PHONY: off
off: intercept.progs
	@if test `whoami` != root; then echo "run this target as root"; false; fi
	@for F in `cat $<`; do                            \
          if test -e $${F}_orig; then                     \
            C="mv -f $${F}_orig $$F"; echo $$C; $$C;      \
          else echo "Interception already off for $${F}"; \
          fi                                              \
        done
	chmod u+w $<
