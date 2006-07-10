#!/usr/bin/make -f

# This makefile will move your system gcc toolchain away and point
# softlinks at the intereceptor scripts.  Generally, run targets in
# this makefile as root.  Use Makefile to build intercept.progs as a
# normal user.

ifeq ($(wildcard Intercept.mk),)
  $(error Run this makefile in the build-interceptor directory.)
endif

# Print the current interception state.
.PHONY: print
print: intercept.progs
	@echo "Interception is:"
	@for F in `cat $<`; do        \
          if test -e $${F}_orig; then \
            echo -n "on ";            \
          else                        \
            echo -n "off";            \
          fi;                         \
          echo " for $${F}";          \
        done

# Note: I use $PWD rather than $HOME because this script will be run
# as root and $HOME will be /root.  Just type 'cd build-interceptor'
# before su-ing to root.
#
# If you don't run these two targets as root then some non-atomic
# partial result may occur, so I check for you.
#
# TODO: the double readlink is a quick hack -- make it recursively check.
#
# Note: readlink -f won't work since we might have already changed some of the
# links.
.PHONY: on
on: intercept.progs
	@if test `whoami` != root; then echo "run this target as root"; false; fi
	chmod a-w $<
	@for F in `cat $<`; do                                                                                                                    \
          if readlink $${F} | grep ccache >/dev/null ; then                                                                                       \
            echo "ERROR: Do not use Build-Interceptor in conjunction with CCache." >&2 ;                                                          \
            echo "1) Turn off interception: 'cd build-interceptor; make -f Intercept.mk off'." >&2 ;                                                          \
            echo "2) Move away ccache." >&2 ;                                                          \
            echo "3) Re-configure build-interceptor: 'cd build-interceptor; make clean; make'" >&2 ;                                                          \
            echo "4) Turn on interception: 'cd build-interceptor; make -f Intercept.mk on'." >&2 ;                                                          \
            exit 1 ;                                                                                                                              \
          fi ;                                                                                                                                    \
          if readlink $${F} >/dev/null && grep -x -F `dirname $${F}`/`readlink $${F}` $< >/dev/null ; then                                        \
            echo "Ignoring $${F} -- it's a symlink to `readlink $${F}`, also intercepted.";                                                       \
          elif readlink $${F} >/dev/null && readlink `readlink $${F}` >/dev/null && grep -x -F `readlink \`readlink $${F}\`` $< >/dev/null ; then \
            echo "Ignoring $${F} -- it's a symlink to `readlink \`readlink $${F}\``, also intercepted.";                                          \
          elif ! test -e $${F}_orig; then                                                                                                         \
            C="mv $$F $${F}_orig"; echo $$C; $$C;                                                                                                 \
            I=`basename $${F} | sed 's,-.*,,'`;                                                                                                   \
            if test -e $${I}_interceptor.pl -a -e $${I}_interceptor ; then                                                                        \
              C="ln -s ${PWD}/$${I}_interceptor $$F"; echo $$C; $$C;                                                                              \
              if ! test -e $${F}_interceptor.pl ; then                                                                                            \
                C="ln -s ${PWD}/$${I}_interceptor.pl $${F}_interceptor.pl";echo $$C; $$C;                                                         \
              fi                                                                                                                                  \
            else                                                                                                                                  \
              C="ln -s ${PWD}/$${I}_interceptor.pl $$F"; echo $$C; $$C;                                                                           \
            fi                                                                                                                                    \
          else echo "Interception already on for $${F}";                                                                                          \
          fi                                                                                                                                      \
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
