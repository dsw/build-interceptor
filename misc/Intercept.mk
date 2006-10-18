#!/usr/bin/make -f

# $Id$

# This makefile is a deprecated way of invoking build-interceptor-rename.

ifeq ($(wildcard build-interceptor-version),)
  $(error Run this makefile in the build-interceptor directory.)
endif

.PHONY: print
print on off: rc/intercept.progs
	./build-interceptor-rename $@
