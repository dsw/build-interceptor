#!/usr/bin/make -f

# $Id$

# This makefile is a deprecated way of invoking build-interceptor in rename-mode.

ifeq ($(wildcard Intercept.mk),)
  $(error Run this makefile in the build-interceptor directory.)
endif

.PHONY: print
print on off: rc/intercept.progs
	./build-interceptor-rename $@
