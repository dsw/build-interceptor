# Demonstrate the effect of the -j flag.  Run this two different ways
# and see the difference.

# **** With interception off.

# make -f MakeTest.mk -j1
# sleep 1
# one
# two

# make -f MakeTest.mk -j2
# sleep 1
# two
# one

# **** With interception on, 'one' always comes first, since the -j
# flag is removed by make_interceptor.pl

# make -f MakeTest.mk -j2
# sleep 1
# one
# two

all: one two

one:
	sleep 1
	@echo one
two:
	@echo two
