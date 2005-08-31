# Disk.mk; see License.txt for copyright and terms of use

DIR := build-interceptor
VERSION := 2005.08.31

.SUFFIXES:

# **** no default target
.PHONY: default_target
default_target:; @echo "You must give an explicit target to make -f Dist.mk"

# **** make a distribution
.PHONY: dist
dist: distclean
	svn export http://build-interceptor.tigris.org/svn/build-interceptor/trunk $(DIR)
	mv $(DIR) $(DIR)-$(VERSION)
	tar cvzf $(DIR)-$(VERSION).tar.gz $(DIR)-$(VERSION)
	chmod 444 $(DIR)-$(VERSION).tar.gz
# 	cp Readme Readme_$(DIR)-$(VERSION).txt
# 	chmod 444 Readme_$(DIR)-$(VERSION).txt

# **** clean the distribution
.PHONY: distclean
distclean:
	rm -rf $(DIR) $(DIR)-*
	rm -f *.tar.gz
#	rm -f Readme_$(DIR)-*.txt
