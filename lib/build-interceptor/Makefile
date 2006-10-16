all: make_interceptor preload_helper.so

make_interceptor: shebang_helper.c
	gcc -o $@ -DIPROGNAME='"make"' -DINTERCEPTORPATH='"$(INSTALL_LIBDIR)/make_interceptor0"' $^

preload_helper.so: preload_helper.c strlcpy.c
	gcc -shared -o $@ $^ -ldl

clean:
	rm -f make_interceptor
	rm -f preload_helper.so
