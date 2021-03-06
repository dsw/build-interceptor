# You need to run targets in this makefile to get things set up in the first
# place.  Run targets in this makefile as a normal user.

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
all: rc/intercept.progs all-recurse PRINT-INSTRUCTIONS

all-recurse:
	cd lib/build-interceptor && $(MAKE) all

.PHONY: clean
clean: clean-intercept.progs clean-recurse

clean-recurse:
	cd lib/build-interceptor && $(MAKE) clean

.PHONY: clean-intercept.progs
clean-intercept.progs:
	@if test \! -e rc/rename-mode.on -a -w rc/intercept.progs; then                 \
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

.PHONY: PRINT-INSTRUCTIONS
PRINT-INSTRUCTIONS:
	@echo
	@echo "**** Done building Build-Interceptor."
	@echo
	@cat www/quickstart.txt
