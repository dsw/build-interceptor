# This makefile will move your system gcc toolchain away and point
# softlinks at the intereceptor scripts.  Generally, run targets in
# this makefile as root.  Use Makefile to build intercept.files as a
# normal user.

ifneq ($(notdir ${PWD}),build_interceptor)
  $(error Run this makefile in the build_interceptor directory under your HOME directory)
endif

# Print the current interception state.
.PHONY: print
print: intercept.files
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
on: intercept.files
	@if test `whoami` != root; then echo "run this target as root"; false; fi
	chmod a-w $<
	@for F in `cat $<`; do                                \
          if ! test -e $${F}_orig; then                       \
            C="mv $$F $${F}_orig"; echo $$C; $$C;             \
            C="ln -s ${PWD}/`basename $${F}`_interceptor.pl $$F"; echo $$C; $$C; \
          else echo "Interception already on for $${F}";      \
          fi                                                  \
        done

.PHONY: off
off: intercept.files
	@if test `whoami` != root; then echo "run this target as root"; false; fi
	@for F in `cat $<`; do                            \
          if test -e $${F}_orig; then                     \
            C="mv -f $${F}_orig $$F"; echo $$C; $$C;      \
          else echo "Interception already off for $${F}"; \
          fi                                              \
        done
	chmod u+w $<