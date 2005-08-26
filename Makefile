# You need to run targets in this makefile to get things set up in the
# first place.  Generally, run targets in this makefile as a normal
# user.

ifeq ($(wildcard Intercept.mk),)
  $(error Run this makefile in the build-interceptor directory.)
endif

ifneq (${BI_FORCE_ROOT},1)
  ifeq ($(shell whoami),root)
    $(error Do not run any targets in this makefile as root.)
  endif
endif

# The list of user tools that we are intercepting.  The user could
# build this file by hand if this automated way doesn't work.
USRTOOLS :=
USRTOOLS += make
USRTOOLS_GCC = gcc $(notdir $(wildcard /usr/bin/gcc-* /usr/bin/*-linux-gcc))
USRTOOLS += $(USRTOOLS_GCC)
USRTOOLS += g++ $(notdir $(wildcard /usr/bin/g++-*))
USRTOOLS += cpp $(notdir $(wildcard /usr/bin/cpp-*))
USRTOOLS += cc
USRTOOLS += c++
USRTOOLS += as
USRTOOLS += ld

# Internal gcc tools usually not called by the user.
GCCTOOLS :=
GCCTOOLS += cpp0
GCCTOOLS += tradcpp0
GCCTOOLS += cc1
GCCTOOLS += cc1plus
# at least under gcc 3.4 this just runs ld
# GCCTOOLS += collect2
GCCTOOLS += f771

get_paths = $(shell for F in $(1); do which $$F 2>/dev/null; done | sort -u)

USRTOOLS_FULL = $(call get_paths,$(USRTOOLS))

# the wildcard function filters out non-existing files
USRTOOLS_GCC_FULL = $(wildcard $(shell          \
	for F in $(GCCTOOLS); do                \
	    for gcc in $(USRTOOLS_GCC); do      \
	        $$gcc -print-prog-name=$$F;     \
	    done                                \
	done | sort -u) )

.PHONY: all interceptor.specs.ALL
all: intercept.progs make_interceptor interceptor.specs.ALL

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
clean: clean-intercept.progs clean-script-interceptor clean-bak clean-interceptor.specs

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

.PHONY: clean-interceptor.specs
clean-interceptor.specs:
	rm -f interceptor.specs-* interceptor.specs

# make interceptor specs for all gcc versions we need
interceptor.specs.ALL: $(subst gcc,interceptor.specs,$(USRTOOLS_GCC:%-gcc=gcc))
#interceptor.specs interceptor.specs-3.4 interceptor.specs-3.3 interceptor.specs-3.2 interceptor.specs-3.0

# interceptor specs for a particular version
interceptor.specs-%: interceptor.specs.in
	./make-spec-file.pl $< $@

# default interceptor specs for gcc 3.3
interceptor.specs: interceptor.specs-3.3
	ln -fs $< $@

intercept.progs: clean-intercept.progs
	echo $(USRTOOLS_FULL) $(USRTOOLS_GCC_FULL) | xargs -n 1 > $@
	@echo
	@echo "$@: " && cat $@

make_interceptor: script_interceptor.c
	gcc -o $@ -DIPROGNAME='"make"' -DINTERCEPTORPATH='"make_interceptor.pl"' $^
