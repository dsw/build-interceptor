EXE :=
EXE += foo

EXTRACT := ../../extract_section.pl

.PHONY: all
all: clean-build_interceptor $(EXE)

.PHONY: clean
clean: clean-build_interceptor
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
	g++ -o $@ $^

%.o: %.cc
	g++ -c -o $@ $<
