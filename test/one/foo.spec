# This spec file modifies the build process for build interception.
# See http://gcc.gnu.org/onlinedocs/gcc-3.4.0/gcc/Spec-Files.html#Spec%20Files

# Remove -P from the gcc command line.  This makes sure that hash-line
# directives are going to show up in the .i files.
%rename cpp_options cpp_options_old0
*cpp_options:
%<P %(cpp_options_old0)
# Note that this does not work.  I don't know what the *cpp spec
# string is for.
#  %rename cpp cpp_old0
#  *cpp:
#  %<P %(cpp_old0)

# Make sure that the preprocessor runs separately and not integrated.
# This doesn't work.
#  *cc1plus:
#  + --no-integrated-cpp 
*cc1plus:
boink
