# Disk.mk; see License.txt for copyright and terms of use

DIR := build_interceptor
VERSION := 2004.7.14

# for people at Berkeley who aren't me
# CICH := :ext:cich:/home/cvs/repository
CICH := /home/cvs/repository

CVS_TAG := now

HERE := $(shell pwd)

.SUFFIXES:

# **** no default target
.PHONY: default_target
default_target:; @echo "You must give an explicit target to make -f Dist.mk"

# **** make a distribution
.PHONY: dist
dist: distclean
	cvs -d $(CICH) export -D $(CVS_TAG) $(DIR)
	tar cvzf $(DIR)-$(VERSION).tar.gz $(DIR)

# **** clean the distribution
.PHONY: distclean
distclean:
	rm -rf $(DIR)
	rm -f *.tar.gz
