# You need to run targets in this makefile to get things set up in the
# first place.  Generally, run targets in this makefile as a normal
# user.

ifneq ($(notdir ${PWD}),build_interceptor)
  $(error Run this makefile in the build_interceptor directory under your HOME directory.)
endif

ifeq ($(shell whoami),root)
  $(error Do not run any targets in this makefile as root.)
endif

# The list of user tools that we are intercepting.  The user could
# build this file by hand if this automated way doesn't work.
USRTOOLS :=
# NOTE: make interceptor doesn't look for the -j flag correctly, so
# don't use it for now.  It isn't critical to the correct operation of
# build_interceptor.
# USRTOOLS += make
USRTOOLS += gcc $(notdir $(wildcard /usr/bin/gcc-*))
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

# Script sharing: These tools are intercepted by a script that is also
# intercepting another tool.
SOFTLINKS :=
SOFTLINKS += g++_interceptor.pl
SOFTLINKS += cpp_interceptor.pl
SOFTLINKS += tradcpp0_interceptor.pl
SOFTLINKS += cc1plus_interceptor.pl
SOFTLINKS += ld_interceptor.pl

.PHONY: all interceptor.specs.ALL
# NOTE: for a subtle reason, softlinks should come before
# intercept.progs: if you run this target after interception is
# already happening, the tools that point to softlinks here that are
# not built yet will not be included.
all: softlinks intercept.progs make_interceptor interceptor.specs.ALL

INTER_SCRIPS :=
INTER_SCRIPS += as_interceptor.pl
INTER_SCRIPS += cc1_interceptor.pl
INTER_SCRIPS += collect2_interceptor.pl
INTER_SCRIPS += cpp0_interceptor.pl
INTER_SCRIPS += gcc_interceptor.pl
INTER_SCRIPS += make_interceptor.pl

LOUD_ON := $(addprefix loud-on/,$(INTER_SCRIPS))
.PHONY: loud-on $(LOUD_ON)
loud-on: $(LOUD_ON)
$(LOUD_ON): loud-on/%:
	perl -i.bak -pe 's/^(\s*)\#+/$1/ if /LOUD/' $*

LOUD_OFF := $(addprefix loud-off/,$(INTER_SCRIPS))
.PHONY: loud-off $(LOUD_OFF)
loud-off: $(LOUD_OFF)
$(LOUD_OFF): loud-off/%:
	perl -i.bak -pe 's/^(\s*)\#*/$1\#/ if /LOUD/' $*

# timestamp the $HOME/build_interceptor.log; useful to run between
# compilations
.PHONY: stamp-log
stamp-log: stamp-log/---
.PHONY: stamp-log/%
stamp-log/%:
	echo >> ${HOME}/build_interceptor.log
	date >> ${HOME}/build_interceptor.log
	echo '$*' >> ${HOME}/build_interceptor.log
	echo >> ${HOME}/build_interceptor.log

.PHONY: clean
clean: clean-intercept.progs clean-softlinks clean-script-interceptor clean-bak

.PHONY: clean-intercept.progs
clean-intercept.progs:
	@if test -w intercept.progs; then  \
          C="rm -f intercept.progs"; echo $$C; $$C; \
        elif test -e intercept.progs; then \
          echo "Do not attempt to change intercept.progs while interception is on."; \
          false; \
        else echo "No intercept.progs to remove."; \
        fi

.PHONY: clean-softlinks
clean-softlinks:
	rm -f $(SOFTLINKS)

# .bak files are created when perl -i.bak filters files; this is done
# by loud-on/loud-off
.PHONY: clean-bak
clean-bak:
	rm -f *.bak

.PHONY: clean-build_interceptor
clean-build_interceptor: clean-build_interceptor_tmp clean-preproc

.PHONY: clean-build_interceptor_tmp
clean-build_interceptor_tmp:
	rm -rf ${HOME}/build_interceptor_tmp

.PHONY: clean-preproc
clean-preproc:
	rm -rf ${HOME}/preproc/*

.PHONY: clean-script-interceptor
clean-script-interceptor:
	rm -rf make_interceptor

interceptor.specs.ALL: interceptor.specs interceptor.specs-3.4 interceptor.specs-3.3 interceptor.specs-3.2 interceptor.specs-3.0

interceptor.specs-%: interceptor.specs.in
	./make-spec-file $< $@

interceptor.specs: interceptor.specs-3.3
	cp $< $@

intercept.progs: clean-intercept.progs
	for F in $(USRTOOLS); do         \
          if which $$F &>/dev/null; then \
            echo "to intercept.progs $$F"; \
            which $$F >> $@;             \
          fi                             \
        done
	for F in $(GCCTOOLS); do                      \
          if test -e `gcc -print-prog-name=$$F`; then \
            echo "to intercept.progs $$F";            \
            gcc -print-prog-name=$$F >> $@;           \
          fi                                          \
        done

.PHONY: softlinks
softlinks: $(SOFTLINKS)

# It doesn't seem that you can easily check softlinks into cvs, so I
# make them here.
g++_interceptor.pl:
	ln -s gcc_interceptor.pl $@
cpp_interceptor.pl:
	ln -s cpp0_interceptor.pl $@
tradcpp0_interceptor.pl:
	ln -s cpp0_interceptor.pl $@
cc1plus_interceptor.pl:
	ln -s cc1_interceptor.pl $@
ld_interceptor.pl:
	ln -s collect2_interceptor.pl $@

make_interceptor: script_interceptor.c
	gcc -o $@ -DIPROGNAME='"make"' -DINTERCEPTORPATH='"make_interceptor.pl"' $^
