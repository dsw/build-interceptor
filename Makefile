# You need to run targets in this makefile to get things set up in the
# first place.  Generally, run targets in this makefile as a normal
# user.

ifeq ($(wildcard Intercept.mk),)
  $(error Run this makefile in the build-interceptor directory.)
endif

ifneq (${BUILD_INTERCEPTOR_FORCE_ROOT},1)
  ifeq ($(shell whoami),root)
    $(error Do not run any targets in this makefile as root.)
  endif
endif

.PHONY: all
all: intercept.progs lib/build-interceptor/make_interceptor

# timestamp the $HOME/build-interceptor.log; useful to run between
# compilations
.PHONY: stamp-log
stamp-log: stamp-log/---
.PHONY: stamp-log/%
stamp-log/%:
	echo >> ${HOME}/build-interceptor.log
	date >> ${HOME}/build-interceptor.log
	echo '$*' >> ${HOME}/build-interceptor.log
	echo >> ${HOME}/build-interceptor.log

.PHONY: clean
clean: clean-intercept.progs clean-script-interceptor clean-bak

.PHONY: clean-intercept.progs
clean-intercept.progs:
	@if test -w intercept.progs; then  \
          C="rm -f intercept.progs"; echo $$C; $$C; \
        elif test -e intercept.progs; then \
          echo "Do not attempt to change intercept.progs while interception is on."; \
          false; \
        else echo "No intercept.progs to remove."; \
        fi

# .bak files are created when perl -i.bak filters files; this is done
# by loud-on/loud-off
.PHONY: clean-bak
clean-bak:
	rm -f *.bak

.PHONY: clean-build-interceptor
clean-build-interceptor: clean-build-interceptor-tmp clean-preproc

.PHONY: clean-build-interceptor-tmp
clean-build-interceptor-tmp:
	rm -rf ${HOME}/build-interceptor-tmp

.PHONY: clean-preproc
clean-preproc:
	rm -rf ${HOME}/preproc/*

.PHONY: clean-script-interceptor
clean-script-interceptor:
	rm -rf make_interceptor

intercept.progs: clean-intercept.progs
	./list-programs-to-intercept > $@
	@echo
	@echo "$@: " && cat $@

lib/build-interceptor/make_interceptor: script_interceptor.c
	gcc -o $@ -DIPROGNAME='"make"' -DINTERCEPTORPATH='"make_interceptor.pl"' $^
