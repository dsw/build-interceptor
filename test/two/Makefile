EXE :=
EXE += foo

EXTRACT := ../../extract_section.pl

.PHONY: all
all: $(EXE)

.PHONY: clean
clean:
	rm -f *.o foo

.PHONY: clean-build_interceptor
clean-build_interceptor:
	rm -rf /tmp/build_interceptor

.PHONY: check
check:
	./foo

.PHONY: check-interception
check-interception:
	@echo "----------------------------------------"
	-$(EXTRACT) .note.cc1_interceptor foo
	@echo "----------------------------------------"
	-$(EXTRACT) .note.collect2_interceptor foo
	@echo "----------------------------------------"
	-$(EXTRACT) .note.ld_interceptor foo

foo: gronk.o blort.o
	/usr/bin/c++ -o $@ $^

%.o: %.cc
	/usr/bin/c++ -c -o $@ $<
