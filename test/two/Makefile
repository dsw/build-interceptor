EXE :=
EXE += a.out

EXTRACT := ../../extract_section.pl

.PHONY: all
all: $(EXE)

.PHONY: clean
clean:
	rm -f *.o a.out

.PHONY: clean-build_interceptor
clean-build_interceptor:
	rm -rf ${HOME}/build_interceptor_tmp
	rm -rf ${HOME}/preproc

.PHONY: check
check:
	./a.out

.PHONY: check-interception
check-interception:
	@echo "----------------------------------------"
	-$(EXTRACT) .note.cc1_interceptor a.out
# 	@echo "----------------------------------------"
# 	-$(EXTRACT) .note.collect2_interceptor a.out
	@echo "----------------------------------------"
	-$(EXTRACT) .note.ld_interceptor a.out

a.out: gronk.o blort.o
	/usr/bin/c++ $^
# 	/usr/bin/c++ -o $@ $^

%.o: %.cc
	/usr/bin/c++ -c $<
# 	/usr/bin/c++ -c -o $@ $<
