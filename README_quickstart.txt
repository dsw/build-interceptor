
To use LD_PRELOAD mode:
    build-interceptor gcc foo.c
    build-interceptor make

To use RENAME mode:
    sudo build-interceptor-rename on
    gcc foo.c
    make
    sudo build-interceptor-rename off
