
There are two implemented modes of using Build-Interceptor:

* RENAME: renames the original executables, e.g. /usr/bin/gcc to
  /usr/bin/gcc_orig, and replaces it with gcc_intercept.

* LD_PRELOAD: uses LD_PRELOAD to override exec* libc calls

and three other known methods, not yet implemented:

* PTRACE: uses ptrace(2) to intercept the execve syscall

* GCC_EXEC_PREFIX: uses the GCC_EXEC_PREFIX environment variable

* PATH PREFIX: create a new program "gcc" earlier in $PATH

Comparison
==========

The five methods have advantages and disadvantages:

* RENAME:
    * Expected success in the face of complex builds: perfect.
    * Con: requires root or virtual machine; modifies the system.

* LD_PRELOAD:
    * Expected success in the face of complex builds: excellent.
    * Con: fails if any program is statically linked or makes direct libc
      calls; fails if any program is setuid root.  May also fail when used in
      conjunction with other LD_PRELOAD programs.

* PTRACE:
    * Expected success in the face of complex builds: perfect.
    * Con: not portable, small performance hit; fails if any program is setuid
      root.

* GCC_EXEC_PREFIX:
    * Expected success in the face of complex builds: mediocre.
    * Con: susceptible to user modifying environment [1]_

* PATH PREFIX:
    * Expected success in the face of complex builds: poor.
    * Con: susceptible to hard-coded paths as well as user modifying environment [1]_


.. [1] Don't underestimate the user modifying environment variables in the
       build process.  For example, "Cons" always clears the environment and
       then sets it to fixed values.
