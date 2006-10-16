# You need to run targets in this makefile to get things set up in the
# first place.  Generally, run targets in this makefile as a normal
# user.

ifeq ($(wildcard build-interceptor-version),)
  $(error Run this makefile in the build-interceptor directory.)
endif

ifneq (${BUILD_INTERCEPTOR_FORCE_ROOT},1)
  ifeq ($(shell whoami),root)
    $(error Do not run any targets in this makefile as root.)
  endif
endif

# Prefix to install to, e.g. /usr.  To use build-interceptor from the source
# location, just leave this as is (run from the source directory).
INSTALL_PREFIX = ${PWD}
export INSTALL_PREFIX

INSTALL_LIBDIR = $(INSTALL_PREFIX)/lib/build-interceptor

.PHONY: all
all: lib/build-interceptor/make_interceptor rc/intercept.progs

.PHONY: clean
clean: clean-intercept.progs
	rm -f lib/build-interceptor/make_interceptor

.PHONY: clean-intercept.progs
clean-intercept.progs:
	@if test -w rc/intercept.progs; then                                            \
          C="rm -f rc/intercept.progs"; echo $$C; $$C;                                  \
        elif test -e rc/intercept.progs; then                                           \
          echo "Do not attempt to change intercept.progs while interception is on.";    \
          false;                                                                        \
        else echo "No intercept.progs to remove.";                                      \
        fi

rc/intercept.progs: clean-intercept.progs
	./list-programs-to-intercept > $@
	@echo
	@echo "$@: " && sed 's/^/  /' $@

lib/build-interceptor/make_interceptor: script_interceptor.c
	gcc -o $@ -DIPROGNAME='"make"' -DINTERCEPTORPATH='"$(INSTALL_LIBDIR)/make_interceptor0"' $^
