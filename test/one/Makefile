all:

.SUFFIXES:

TOCLEAN =

EXE :=
EXE += hello

COBJ := waga.o

CPPOBJ := hello.o

TOCLEAN += $(EXE) $(COBJ) $(CPPOBJ)

TOCLEAN += hello2
all: $(EXE) hello2

clean:
	rm -f $(TOCLEAN)
	rm -rf /home/dsw/preproc/*

check-hello:
	./hello
	/home/dsw/build_interceptor/extract_section.pl .note.cc1_interceptor hello
	/home/dsw/build_interceptor/extract_section.pl .note.collect2_interceptor hello
	/home/dsw/build_interceptor/extract_section.pl .note.ld_interceptor hello

check-hello2:
	/home/dsw/build_interceptor/extract_section.pl .note.cc1_interceptor hello2
	/home/dsw/build_interceptor/extract_section.pl .note.collect2_interceptor hello2
	/home/dsw/build_interceptor/extract_section.pl .note.ld_interceptor hello2

GCC := gcc
GPP := g++

$(EXE): %:
	$(GPP) -o $@ $^

# This is separated out so we have an excuse to call ld
LD_LIBS := /usr/lib/crt1.o /usr/lib/crti.o /opt/gcc-X.XX/lib/gcc/i686-pc-linux-gnu/3.4.0/crtbegin.o
LD_L_FLAGS := -L/opt/gcc-X.XX/lib/gcc/i686-pc-linux-gnu/3.4.0 -L/opt/gcc-X.XX/lib/gcc/i686-pc-linux-gnu/3.4.0/../../..
hello2:
	ld -m elf_i386 -dynamic-linker /lib/ld-linux.so.2 -o $@ ${LD_LIBS} ${LD_L_FLAGS} $^ \
          -lstdc++ -lm -lgcc -lc -lgcc \
           /opt/gcc-X.XX/lib/gcc/i686-pc-linux-gnu/3.4.0/crtend.o /usr/lib/crtn.o

CCFLAGS :=
CCFLAGS += -Wall
CCFLAGS += -Werror
#CCFLAGS += -save-temps

TOCLEAN += *.o *.ii *.i *.s
$(COBJ): %.o: %.c
	@echo this call to cpp is gratuitous
	cpp $< > /dev/null
	@echo now calling gcc
	$(GCC) -o $@ -c $< $(CCFLAGS)

$(CPPOBJ): %.o: %.cc
	$(GPP) -o $@ -c $< $(CCFLAGS)

# 	$(GPP) -specs=foo.spec -\#\#\# -o $@ -c $^ $(CCFLAGS)
#	$(GPP) --no-integrated-cpp -\#\#\# -o $@ -c $^ $(CCFLAGS)
#	$(GPP) -v -o $@ -c $^ $(CCFLAGS)
#	$(GPP) -o $@ -c $^ $(CCFLAGS)
# 	$(GPP) -P -specs=foo.spec -o $@ -c $^ $(CCFLAGS)

hello: hello.o
hello: waga.o

hello2: hello.o
hello2: waga.o
