EXTRACT := ${HOME}/build_interceptor/extract_section.pl

.PHONY: all
all: main_dynamic
all: main_static

# statically linked
main_static: main.o shared.o
	gcc -o $@ $^
# 	gcc -Wl,-t -o $@ $^

# dynamically linked
main_dynamic: main.o libshared.so
	gcc -o $@ $< -L. -lshared
# this doesn't work, so you do need to mention it
#	gcc -o $@ $<

%.o: %.c
	gcc -c -o $@ -static -fPIC $^

lib%.so: %.o
	gcc -o $@ -shared $^
# Andy says you need this for some types of linking
# 	gcc -o $@ -shared -Wl,-export-dynamic $^
# -Wl,--whole-archive libfoo.a -Wl,--no-whole-archive

.PHONY: clean
clean:
	rm -f *.o *.so main_*

.PHONY: clean-build_interceptor
clean-build_interceptor:
	rm -rf ${HOME}/build_interceptor_tmp
	rm -rf ${HOME}/preproc

.PHONY: check
check: check/static check/dynamic

check/static:
	@echo "..............................."
	ldd main_static
	strace -eopen ./main_static
check/dynamic:
	@echo "..............................."
	ldd main_dynamic
	LD_LIBRARY_PATH=$LD_LIBRARY_PATH:. strace -eopen ./main_dynamic

.PHONY: check-interception
check-interception: check-interception/main_static check-interception/main_dynamic
.PHONY: check-interception/%
check-interception/%:
	@echo
	@echo "$@ cc1 ----------------------------------------"
	-$(EXTRACT) .note.cc1_interceptor $*
	@echo "$@ ld ----------------------------------------"
	-$(EXTRACT) .note.ld_interceptor $*
