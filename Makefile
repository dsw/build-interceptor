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
USRTOOLS += make
USRTOOLS += gcc
USRTOOLS += g++
USRTOOLS += cpp
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

# Script sharing: These tools are intercepted by a script that is also
# intercepting another tool.
SOFTLINKS :=
SOFTLINKS += g++_interceptor.pl
SOFTLINKS += cpp_interceptor.pl
SOFTLINKS += tradcpp0_interceptor.pl
SOFTLINKS += cc1plus_interceptor.pl
SOFTLINKS += ld_interceptor.pl

.PHONY: all
# NOTE: for a subtle reason, softlinks should come before
# intercept.progs: if you run this target after interception is
# already happening, the tools that point to softlinks here that are
# not built yet will not be included.
all: softlinks intercept.progs

.PHONY: clean
clean: clean-intercept.progs clean-softlinks

.PHONY: clean-intercept.progs
clean-intercept.progs:
	@if test -w intercept.progs; then  \
          C="rm -f intercept.progs"; echo $$C; $$C; \
        elif test -e intercept.progs; then \
          echo "Do not attempt to change intercept.progs while interception is on."; \
        else echo "No intercept.progs to remove."; \
        fi

.PHONY: clean-softlinks
clean-softlinks:
	rm -f $(SOFTLINKS)

.PHONY: clean-preproc
clean-preproc:
	rm -rf ${HOME}/preproc/*

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
