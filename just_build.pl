#!/usr/bin/perl -w
# See License.txt for copyright and terms of use
use strict;

# Build all the RPMs.

# This script contains code from The MOPS project
# (http://sourceforge.net/projects/mopscode) by Hao Chen where he and
# Geoff Morrison in particular worked on the build-process
# interception aspect.

my $home = "$ENV{HOME}";
my $build = "ball_build";
my $preproc = "ball_preproc";

my $build_dir = "$home/$build";
die unless -d $build_dir;
#  die if -e $build_dir;
#  die if system("mkdir $build_dir");

my $preproc_dir = "$home/$preproc";
die unless -d $preproc_dir;
#  die if -e $preproc_dir;
#  die if system("mkdir $preproc_dir");
#  die if system("cd $home; ln -s $preproc preproc");

my @rpm_files = qw(
4Suite-0.11.1-8.src.rpm
Canna-3.5b2-62.src.rpm
Distutils-1.0.2-2.src.rpm
ElectricFence-2.2.2-8.src.rpm
FreeWnn-1.11-20.src.rpm
GConf-1.0.9-4.src.rpm
Glide3-20010520-13.src.rpm
Gtk-Perl-0.7008-13.src.rpm
Guppi-0.40.3-5.src.rpm
ImageMagick-5.4.3.11-1.src.rpm
LPRng-3.8.9-3.src.rpm
MAKEDEV-3.3-4.src.rpm
Maelstrom-3.0.1-18.src.rpm
MagicPoint-1.09a-1.src.rpm
MyODBC-2.50.39-4.src.rpm
MySQL-python-0.9.1-1.src.rpm
ORBit-0.5.13-3.src.rpm
Omni-0.5.1-3.src.rpm
PyQt-3.1-2.src.rpm
PyXML-0.7-4.src.rpm
SDL-1.2.3-7.src.rpm
SDL_image-1.2.1-4.src.rpm
SDL_mixer-1.2.1-4.src.rpm
SDL_net-1.2.3-2.src.rpm
SysVinit-2.84-2.src.rpm
VFlib2-2.25.6-4.src.rpm
WindowMaker-0.80.0-9.src.rpm
Wnn6-SDK-1.0-18.src.rpm
XFree86-4.2.0-8.src.rpm
XFree86-Servers-3.3.6-44.src.rpm
XFree86-compat-libs-4.0.3-2.src.rpm
Xaw3d-1.5-12.src.rpm
Xconfigurator-4.10.7-1.src.rpm
Xdialog-2.0.5-1.src.rpm
a2ps-4.13b-19.src.rpm
abiword-0.99.5-2.src.rpm
ac-archive-0.5.34-1.src.rpm
adjtimex-1.12-2.src.rpm
alchemist-1.0.23-1.src.rpm
alien-7.24-3.src.rpm
am-utils-6.0.7-4.src.rpm
amanda-2.4.2p2-7.src.rpm
ami-1.0.11-9.src.rpm
anaconda-7.3-7.src.rpm
anaconda-help-7.3-2.src.rpm
anaconda-images-7.3-6.src.rpm
anacron-2.3-17.src.rpm
anonftp-4.0-9.src.rpm
apache-1.3.23-11.src.rpm
apacheconf-0.8.2-2.src.rpm
apel-10.3-4.src.rpm
apmd-3.0.2-10.src.rpm
arts-1.0.0-4.src.rpm
ash-0.3.7-2.src.rpm
asp2php-0.76.2-1.src.rpm
aspell-0.33.7.1-9.src.rpm
aspell-ca-0.1-13.src.rpm
aspell-da-1.4.22-2.src.rpm
aspell-de-0.1.1-12.src.rpm
aspell-es-0.2-8.src.rpm
aspell-fr-0.1-1.src.rpm
aspell-it-0.1-11.src.rpm
aspell-nl-0.1-12.src.rpm
aspell-no-0.3-1.src.rpm
aspell-pt-0.1-6.src.rpm
aspell-pt_BR-2.4-7.src.rpm
aspell-sv-1.3.6-2.src.rpm
at-3.1.8-23.src.rpm
atk-1.0.1-1.src.rpm
audiofile-0.2.3-1.src.rpm
aumix-2.7-8.src.rpm
auth_ldap-1.6.0-4.src.rpm
authconfig-4.2.8-4.src.rpm
autoconf-2.13-17.src.rpm
autoconf253-2.53-3.src.rpm
autoconvert-0.3.7-6.src.rpm
autofs-3.1.7-28.src.rpm
automake-1.4p5-4.src.rpm
automake15-1.5-2.src.rpm
autorun-2.73-1.src.rpm
awesfx-0.4.3a-8.src.rpm
balsa-1.2.4-1.src.rpm
basesystem-7.0-2.src.rpm
bash-2.05a-13.src.rpm
bc-1.06-8.src.rpm
bdflush-1.5-17.src.rpm
bg5ps-1.3.0-7.src.rpm
bind-9.2.0-8.src.rpm
bindconf-1.6.3-1.src.rpm
binutils-2.11.93.0.2-11.src.rpm
bison-1.35-1.src.rpm
blt-2.4u-7.src.rpm
bonobo-1.0.19-2.src.rpm
bonobo-conf-0.14-5.src.rpm
bootparamd-0.17-7.src.rpm
bridge-utils-0.9.3-4.src.rpm
bug-buddy-2.0.6-9.src.rpm
busybox-0.60.2-4.src.rpm
byacc-1.9-19.src.rpm
bzip2-1.0.2-2.src.rpm
caching-nameserver-7.2-1.src.rpm
cadaver-0.19.1-3.src.rpm
cdecl-2.5-22.src.rpm
cdlabelgen-1.5.0-11.src.rpm
cdp-0.33-22.src.rpm
cdparanoia-alpha9.8-8.src.rpm
cdrdao-1.1.5-5.src.rpm
cdrtools-1.10-11.src.rpm
chkconfig-1.3.5-3.src.rpm
chkfontpath-1.9.5-2.src.rpm
chromium-0.9.12-13.src.rpm
cipe-1.4.5-9.src.rpm
cleanfeed-0.95.7b-12.src.rpm
compat-egcs-6.2-1.1.2.16.src.rpm
compat-glibc-6.2-2.1.3.2.src.rpm
compat-libs-6.2-3.src.rpm
comsat-0.17-3.src.rpm
console-tools-19990829-40.src.rpm
control-center-1.4.0.1-31.src.rpm
cpio-2.4.2-26.src.rpm
cproto-4.6-9.src.rpm
cracklib-2.7-15.src.rpm
crontabs-1.10-1.src.rpm
ctags-5.2.2-2.src.rpm
cups-1.1.14-15.src.rpm
curl-7.9.5-2.src.rpm
cvs-1.11.1p1-7.src.rpm
cyrus-sasl-1.5.24-25.src.rpm
dateconfig-0.7.5-5.src.rpm
db1-1.85-8.src.rpm
db2-2.4.14-10.src.rpm
db3-3.3.11-6.src.rpm
db3x-3.2.9-4.src.rpm
dbskkd-cdb-1.01-13.src.rpm
ddd-3.3.1-13.src.rpm
ddskk-11.6.0-6.src.rpm
dejagnu-1.4.2-3.src.rpm
desktop-backgrounds-1.1-4.src.rpm
dev86-0.15.5-1.src.rpm
dhcp-2.0pl5-8.src.rpm
dhcpcd-1.3.22pl1-7.src.rpm
dia-0.88.1-3.src.rpm
dialog-0.9a-5.src.rpm
dictd-1.5.5-1.src.rpm
dietlibc-0.15-2.src.rpm
diffstat-1.28-1.src.rpm
diffutils-2.7.2-5.src.rpm
dip-3.3.7o-23.src.rpm
diskcheck-1.2-1.src.rpm
dmalloc-4.8.1-6.src.rpm
docbook-dtds-1.0-8.src.rpm
docbook-style-dsssl-1.76-1.src.rpm
docbook-style-xsl-1.49-1.src.rpm
docbook-utils-0.6.9-25.src.rpm
dos2unix-3.1-10.src.rpm
dosfstools-2.8-1.src.rpm
doxygen-1.2.14-4.src.rpm
dtach-0.5-3.src.rpm
dump-0.4b27-3.src.rpm
dvdrtools-0.1.2-1.src.rpm
e2fsprogs-1.27-3.src.rpm
ed-0.2-25.src.rpm
ee-0.3.12-5.src.rpm
eel-1.0.2-11.src.rpm
efax-0.9-12.src.rpm
eject-2.0.12-4.src.rpm
elinks-0.3.0-1.src.rpm
elm-2.5.6-2.src.rpm
emacs-21.2-2.src.rpm
emacspeak-15.0-4.src.rpm
enscript-1.6.1-19.src.rpm
epic-1.0.1-4.src.rpm
eruby-0.9.7-1.src.rpm
esound-0.2.24-1.src.rpm
ethereal-0.9.3-3.src.rpm
ethtool-1.5-1.src.rpm
evolution-1.0.3-4.src.rpm
exmh-2.4-2.src.rpm
expat-1.95.2-2.src.rpm
extace-1.5.1-3.src.rpm
fam-2.6.7-6.src.rpm
fbset-2.1-8.src.rpm
festival-1.4.2-3.src.rpm
fetchmail-5.9.0-5.src.rpm
file-3.37-5.src.rpm
filesystem-2.1.6-2.src.rpm
fileutils-4.1-10.src.rpm
findutils-4.1.7-4.src.rpm
finger-0.17-9.src.rpm
firewall-config-0.97-2.src.rpm
flex-2.5.4a-23.src.rpm
flim-1.14.3-4.src.rpm
fonts-ISO8859-2-1.0-4.src.rpm
fonts-ISO8859-7-1.0-2.src.rpm
fonts-KOI8-R-1.0-1.src.rpm
fonts-ja-7.x-1.src.rpm
foomatic-1.1-0.20020313.3.src.rpm
fortune-mod-1.0-20.src.rpm
freeciv-1.12.0-1.src.rpm
freetype-2.0.9-2.src.rpm
ftp-0.17-13.src.rpm
ftpcopy-0.3.9-1.src.rpm
fvwm2-2.4.6-1.src.rpm
g-wrap-1.2.1-4.src.rpm
gaim-0.53-1.src.rpm
gal-0.19.1-2.src.rpm
galeon-1.2.0-7.src.rpm
gated-3.6-14.src.rpm
gawk-3.1.0-4.src.rpm
gcc-2.96-110.src.rpm
gd-1.8.4-4.src.rpm
gdb-5.1.90CVS-5.src.rpm
gdbm-1.8.0-14.src.rpm
gdk-pixbuf-0.14.0-8.src.rpm
gdm-2.2.3.1-22.src.rpm
gedit-0.9.7-8.src.rpm
genromfs-0.3-9.src.rpm
gettext-0.11.1-2.src.rpm
gftp-2.0.11-2.src.rpm
ggv-1.0.2-4.src.rpm
ghostscript-6.52-8.src.rpm
ghostscript-fonts-5.50-3.src.rpm
giftrans-1.12.2-11.src.rpm
gimp-1.2.3-4.src.rpm
gimp-data-extras-1.2.0-4.src.rpm
gkermit-1.0-9.src.rpm
gkrellm-1.2.9-1.src.rpm
glade-0.6.4-1.src.rpm
glib-1.2.10-5.src.rpm
glib2-2.0.1-2.src.rpm
glibc-2.2.5-34.src.rpm
glibc-kernheaders-2.4-7.14.src.rpm
glms-1.03-14.src.rpm
glut-3.7-4.src.rpm
gmp-4.0.1-3.src.rpm
gnome-applets-1.4.0.5-6.src.rpm
gnome-audio-1.4.0-1.src.rpm
gnome-core-1.4.0.4-54.src.rpm
gnome-games-1.4.0.1-5.src.rpm
gnome-kerberos-0.3-4.src.rpm
gnome-libs-1.4.1.2.90-14.src.rpm
gnome-lokkit-0.50-8.src.rpm
gnome-media-1.2.3-4.src.rpm
gnome-mime-data-1.0.4-1.src.rpm
gnome-pilot-0.1.64-3.src.rpm
gnome-print-0.35-4.src.rpm
gnome-python-1.4.2-3.src.rpm
gnome-spell-0.4.1-0.7x.src.rpm
gnome-user-docs-1.4.1-1.src.rpm
gnome-utils-1.4.0-9.src.rpm
gnome-vfs-1.0.5-4.src.rpm
gnome-vfs-extras-0.2.0-1.src.rpm
gnomeicu-0.96.1-3.src.rpm
gnomemeeting-0.85.1-3.src.rpm
gnorpm-0.96-14.src.rpm
gnucash-1.6.6-3.src.rpm
gnuchess-4.0.pl80-8.src.rpm
gnumeric-1.0.5-3.src.rpm
gnupg-1.0.6-5.src.rpm
gnuplot-3.7.1-17.src.rpm
gperf-2.7.2-2.src.rpm
gphoto-0.4.3-17.src.rpm
gphoto2-2.0-4.src.rpm
gpm-1.19.3-21.src.rpm
gq-0.4.0-5.src.rpm
gqview-0.8.1-5.src.rpm
grep-2.5.1-1.src.rpm
grip-2.96-2.src.rpm
groff-1.17.2-12.src.rpm
grub-0.91-4.src.rpm
gsl-1.1.1-1.src.rpm
gtk+-1.2.10-15.src.rpm
gtk+10-1.0.6-10.src.rpm
gtk-doc-0.5.9-1.src.rpm
gtk-engines-0.11-10.src.rpm
gtk2-2.0.2-4.src.rpm
gtkam-0.1.3-0.cvs20020225.2.src.rpm
gtkglarea-1.2.2-10.src.rpm
gtkhtml-1.0.2-1.src.rpm
gtoaster-1.0beta5-2.src.rpm
gtop-1.0.13-4.src.rpm
guile-1.3.4-19.src.rpm
gv-3.5.8-15.src.rpm
gzip-1.3.3-1.src.rpm
h2ps-2.06-2.src.rpm
hanterm-xf-p19-15.src.rpm
hdparm-4.6-1.src.rpm
hesiod-3.0.2-18.src.rpm
hexedit-1.2.2-3.src.rpm
hotplug-2002_04_01-3.src.rpm
htdig-3.2.0-2.011302.src.rpm
htmlview-2.0.0-1.src.rpm
hwbrowser-0.3.8-1.src.rpm
hwcrypto-1.0-3.src.rpm
hwdata-0.14-1.src.rpm
ical-2.2-26.src.rpm
im-sdk-20011223-3.src.rpm
imap-2001a-10.src.rpm
imlib-1.9.13-3.7.x.src.rpm
indent-2.2.7-3.src.rpm
indexhtml-7.3-3.src.rpm
initscripts-6.67-1.src.rpm
inn-2.3.2-12.src.rpm
intltool-0.17-1.src.rpm
ipchains-1.3.10-13.src.rpm
iproute-2.4.7-1.src.rpm
iptables-1.2.5-3.src.rpm
iptraf-2.5.0-3.src.rpm
iputils-20020124-3.src.rpm
irda-utils-0.9.14-3.src.rpm
iscsi-2.1.0.20-4.src.rpm
isdn4k-utils-3.1-53.src.rpm
isicom-3.05-3.src.rpm
jadetex-3.12-2.src.rpm
jcode.pl-2.13-2.src.rpm
jed-0.99.14-2.src.rpm
jfsutils-1.0.17-1.src.rpm
jikes-1.15-1.src.rpm
jisksp14-0.1-7.src.rpm
jisksp16-1990-0.1-6.src.rpm
joe-2.9.7-4.src.rpm
joystick-1.2.15-11.src.rpm
jpilot-0.99-87.src.rpm
junkbuster-2.0.2-31.src.rpm
kakasi-2.3.4-3.src.rpm
kappa20-0.3-7.src.rpm
kbdconfig-1.9.15-2.src.rpm
kcc-2.3-10.src.rpm
kdbg-1.2.4-4.src.rpm
kde-i18n-3.0.0-5.src.rpm
kde1-compat-1.1.2-11.src.rpm
kde2-compat-2.2.2-2.src.rpm
kdeaddons-3.0.0-4.src.rpm
kdeadmin-3.0.0-4.src.rpm
kdeartwork-3.0.0-4.src.rpm
kdebase-3.0.0-12.src.rpm
kdebindings-3.0.0-1.src.rpm
kdegames-3.0.0-2.src.rpm
kdegraphics-3.0.0-5.src.rpm
kdelibs-3.0.0-10.src.rpm
kdemultimedia-3.0.0-3.src.rpm
kdenetwork-3.0.0-4.src.rpm
kdepim-3.0.0-3.src.rpm
kdesdk-3.0.0-5.src.rpm
kdetoys-3.0.0-3.src.rpm
kdeutils-3.0.0-4.src.rpm
kdevelop-2.1-2.src.rpm
kdoc-3.0.0-0.cvs20020321.1.src.rpm
kernel-2.4.18-3.src.rpm
kernel-pcmcia-cs-3.1.27-18.src.rpm
kernel-utils-2.4-7.4.src.rpm
kinput2-v3-14.src.rpm
knm_new-1.1-5.src.rpm
koffice-1.1.1-5.src.rpm
kon2-0.3.9b-7.src.rpm
kontrol-panel-4.2.3-2.src.rpm
kpppload-1.04-36.src.rpm
krb5-1.2.4-1.src.rpm
krbafs-1.1.1-1.src.rpm
ksconfig-2.0-7.src.rpm
ksymoops-2.4.4-1.src.rpm
kterm-6.2.0-28.src.rpm
kudzu-0.99.52-1.src.rpm
lam-6.5.6-4.src.rpm
lapack-3.0-14.src.rpm
less-358-24.src.rpm
lesstif-0.93.18-2.src.rpm
lftp-2.4.9-1.src.rpm
lha-1.14i-4.src.rpm
libaio-0.3.12-1.src.rpm
libao-0.8.2-2.src.rpm
libcap-1.10-8.src.rpm
libdbi-0.6.4-2.src.rpm
libelf-0.7.0-2.src.rpm
libesmtp-0.8.4-2.src.rpm
libgal7-0.8-7.src.rpm
libgcj-2.96-29.src.rpm
libghttp-1.0.9-2.src.rpm
libglade-0.17-5.src.rpm
libglade2-1.99.9-2.src.rpm
libgtkhtml9-0.9.2-10.src.rpm
libgtop-1.0.12-8.src.rpm
libjpeg-6b-19.src.rpm
libjpeg6a-6a-8.src.rpm
libmad-0.14.2b-3.src.rpm
libmng-1.0.3-2.src.rpm
libogg-1.0rc3-1.src.rpm
libole2-0.2.4-1.src.rpm
libpng-1.0.12-2.src.rpm
librep-0.15.1-3.src.rpm
librsvg-1.0.2-1.src.rpm
libsigc++-1.0.3-5.src.rpm
libtabe-0.2.4a-10.src.rpm
libtermcap-2.0.8-28.src.rpm
libtiff-3.5.7-2.src.rpm
libtool-1.4.2-7.src.rpm
libtool-libs13-1.3.5-2.src.rpm
libungif-4.1.0-10.src.rpm
libunicode-0.4-6.src.rpm
libusb-0.1.5-3.src.rpm
libuser-0.50.2-1.src.rpm
libvorbis-1.0rc3-1.src.rpm
libxml-1.8.17-3.src.rpm
libxml10-1.0.0-8.src.rpm
libxml2-2.4.19-4.src.rpm
libxslt-1.0.15-1.src.rpm
licq-1.1.0-0.cvs20020416.1.src.rpm
lilo-21.4.4-14.src.rpm
linuxdoc-tools-0.9.16-4.src.rpm
lm_sensors-2.6.1-1.src.rpm
locale_config-0.3.4-2.src.rpm
lockdev-1.0.0-16.src.rpm
logrotate-3.6.4-1.src.rpm
logwatch-2.6-2.src.rpm
lrzsz-0.12.20-12.src.rpm
lslk-1.29-3.src.rpm
lsof-4.51-2.src.rpm
ltrace-0.3.10-7.src.rpm
lv-4.49.4-3.src.rpm
lvm-1.0.3-4.src.rpm
lynx-2.8.4-18.src.rpm
m2crypto-0.05_snap4-2.src.rpm
m4-1.4.1-7.src.rpm
macutils-2.0b3-19.src.rpm
magicdev-0.3.6-6.src.rpm
mailcap-2.1.9-2.src.rpm
mailman-2.0.9-1.src.rpm
mailx-8.1.1-22.src.rpm
make-3.79.1-8.src.rpm
man-1.5j-6.src.rpm
man-pages-1.48-2.src.rpm
man-pages-cs-0.14-4.src.rpm
man-pages-da-0.1.1-4.src.rpm
man-pages-de-0.4-1.src.rpm
man-pages-es-1.28-1.src.rpm
man-pages-fr-0.9-5.src.rpm
man-pages-it-0.3.0-7.src.rpm
man-pages-ja-0.5-4.src.rpm
man-pages-ko-20010321-2.src.rpm
man-pages-pl-0.22-7.src.rpm
man-pages-ru-0.7-1.src.rpm
mars-nwe-0.99pl20-6.src.rpm
mc-4.5.55-5.src.rpm
memprof-0.4.1-5.src.rpm
metamail-2.7-28.src.rpm
mew-2.2-2.src.rpm
mgetty-1.1.28-3.src.rpm
micq-0.4.6.p1-2.src.rpm
mikmod-3.1.6-12.src.rpm
mingetty-1.00-1.src.rpm
miniChinput-0.0.3-18.src.rpm
minicom-2.00.0-3.src.rpm
mkbootdisk-1.4.3-1.src.rpm
mkinitrd-3.3.10-1.src.rpm
mktemp-1.5-14.src.rpm
mkxauth-1.7-18.src.rpm
mm-1.1.3-4.src.rpm
mod_auth_any-1.0.2-1.src.rpm
mod_auth_mysql-1.11-1.src.rpm
mod_auth_pgsql-0.9.12-2.src.rpm
mod_bandwidth-2.0.3-3.src.rpm
mod_dav-1.0.3-5.src.rpm
mod_perl-1.26-5.src.rpm
mod_put-1.3-4.src.rpm
mod_python-2.7.6-5.src.rpm
mod_roaming-1.0.2-4.src.rpm
mod_ssl-2.8.7-4.src.rpm
mod_throttle-3.1.2-5.src.rpm
modutils-2.4.14-3.src.rpm
mouseconfig-4.25-1.src.rpm
mozilla-0.9.9-7.src.rpm
mpage-2.5.1-9.src.rpm
mpg321-0.2.9-3.src.rpm
mrproject-0.5.1-8.src.rpm
mrtg-2.9.17-3.src.rpm
mt-st-0.7-3.src.rpm
mtools-3.9.8-2.src.rpm
mtr-0.49-1.src.rpm
mtx-1.2.16-2.src.rpm
mutt-1.2.5.1-1.src.rpm
mx-2.0.3-1.src.rpm
mysql-3.23.49-3.src.rpm
mysqlclient9-3.23.22-6.src.rpm
namazu-2.0.10-4.src.rpm
nasm-0.98.22-2.src.rpm
nautilus-1.0.6-15.src.rpm
nc-1.10-11.src.rpm
ncftp-3.1.3-3.src.rpm
ncompress-4.2.4-28.src.rpm
ncpfs-2.2.0.18-6.src.rpm
ncurses-5.2-26.src.rpm
ncurses4-5.0-5.src.rpm
nedit-5.2-2.src.rpm
net-tools-1.60-4.src.rpm
netatalk-1.5.2-3.src.rpm
netdump-0.6.4-1.src.rpm
netpbm-9.24-3.src.rpm
netscape-4.79-1.src.rpm
newt-0.50.35-1.src.rpm
nfs-utils-0.3.3-5.src.rpm
nhpf-1.42-2.src.rpm
njamd-0.9.2-3.src.rpm
nkf-1.92-6.src.rpm
nmap-2.54BETA31-1.src.rpm
nmh-1.0.4-9.src.rpm
nss_db-2.2-14.src.rpm
nss_ldap-185-1.src.rpm
ntp-4.1.1-1.src.rpm
nut-0.45.4-1.src.rpm
nvi-m17n-1.79-20011024.2.src.rpm
oaf-0.6.8-3.src.rpm
octave-2.1.35-4.src.rpm
open-1.4-14.src.rpm
openh323-1.8.0-3.src.rpm
openjade-1.3.1-4.src.rpm
openldap-2.0.23-4.src.rpm
openldap12-1.2.13-3.src.rpm
openmotif-2.2.2-5.src.rpm
openmotif21-2.1.30-1.src.rpm
openssh-3.1p1-3.src.rpm
openssl-0.9.6b-18.src.rpm
openssl095a-0.9.5a-11.src.rpm
openssl096-0.9.6-6.src.rpm
pam-0.75-32.src.rpm
pam_krb5-1.55-1.src.rpm
pam_smb-1.1.6-2.src.rpm
pan-0.11.2-2.src.rpm
pango-1.0.1-1.src.rpm
parted-1.4.24-3.src.rpm
passivetex-1.12-3.src.rpm
passwd-0.67-1.src.rpm
patch-2.5.4-12.src.rpm
patchutils-0.2.11-2.src.rpm
pax-3.0-1.src.rpm
pccts-1.33mr31-2.src.rpm
pciutils-2.1.9-2.src.rpm
pcre-3.9-2.src.rpm
pdksh-5.2.14-16.src.rpm
perl-5.6.1-34.99.6.src.rpm
perl-Archive-Tar-0.22-15.src.rpm
perl-BSD-Resource-1.14-11.src.rpm
perl-Bit-Vector-6.1-12.src.rpm
perl-Crypt-SSLeay-0.35-15.src.rpm
perl-DBD-MySQL-1.2219-6.src.rpm
perl-DBD-Pg-1.01-8.src.rpm
perl-DBI-1.21-1.src.rpm
perl-Date-Calc-5.0-15.src.rpm
perl-DateManip-5.40-15.src.rpm
perl-Devel-Symdump-2.01-15.src.rpm
perl-Digest-MD5-2.16-15.src.rpm
perl-File-MMagic-1.13-14.src.rpm
perl-Frontier-RPC-0.06-14.src.rpm
perl-HTML-Parser-3.26-2.src.rpm
perl-HTML-Tagset-3.03-14.src.rpm
perl-MIME-Base64-2.12-14.src.rpm
perl-NKF-1.71-2.src.rpm
perl-Parse-Yapp-1.05-15.src.rpm
perl-SGMLSpm-1.03ii-4.src.rpm
perl-Storable-1.0.14-15.src.rpm
perl-TermReadKey-2.17-14.src.rpm
perl-Text-Kakasi-1.04-4.src.rpm
perl-Time-HiRes-1.20-14.src.rpm
perl-TimeDate-1.10-14.src.rpm
perl-URI-1.17-16.src.rpm
perl-XML-Dumper-0.4-12.src.rpm
perl-XML-Encoding-1.01-9.src.rpm
perl-XML-Grove-0.46alpha-11.src.rpm
perl-XML-Parser-2.30-15.src.rpm
perl-XML-Twig-2.02-9.src.rpm
perl-libnet-1.0901-17.src.rpm
perl-libwww-perl-5.63-9.src.rpm
perl-libxml-enno-1.02-15.src.rpm
perl-libxml-perl-0.07-14.src.rpm
php-4.1.2-7.src.rpm
pidentd-3.0.14-5.src.rpm
pilot-link-0.9.5-13.src.rpm
pine-4.44-7.src.rpm
pinfo-0.6.4-4.src.rpm
pkgconfig-0.12.0-1.src.rpm
playmidi-2.4-16.src.rpm
plugger-4.0-6.src.rpm
pmake-1.45-4.src.rpm
pnm2ppa-1.04-2.src.rpm
portmap-4.0-41.src.rpm
postfix-1.1.7-2.src.rpm
postgresql-7.2.1-5.src.rpm
ppp-2.4.1-3.src.rpm
printconf-0.3.77-1.src.rpm
procinfo-18-2.src.rpm
procmail-3.22-5.src.rpm
procps-2.0.7-12.src.rpm
psacct-6.3.2-19.src.rpm
psgml-1.2.3-3.src.rpm
psmisc-20.2-2.src.rpm
pspell-0.12.2-8.src.rpm
pstack-1.1-1.src.rpm
psutils-1.17-13.src.rpm
pump-0.8.11-7.src.rpm
pvm-3.4.4-2.src.rpm
pwdb-0.61.2-2.src.rpm
pwlib-1.2.12-3.src.rpm
pxe-0.1-24.src.rpm
pychecker-0.8.10-1.src.rpm
pydict-0.2.5.1-8.src.rpm
pygtk2-1.99.8-7.src.rpm
python-1.5.2-38.src.rpm
python-clap-1.0.0-3.src.rpm
python-popt-0.8.8-7.x.2.src.rpm
python-xmlrpc-1.5.1-7.x.3.src.rpm
python2-2.2-16.src.rpm
qt-3.0.3-11.src.rpm
qt1x-1.45-16.src.rpm
qt2-2.3.1-3.src.rpm
qtcups-2.0-7.src.rpm
quanta-2.1-0.cvs20020404.2.src.rpm
quota-3.03-1.src.rpm
radvd-0.7.1-1.src.rpm
raidtools-1.00.2-1.3.src.rpm
rarpd-ss981107-9.src.rpm
rcs-5.7-15.src.rpm
rdate-1.2-1.src.rpm
rdist-6.1.5-16.src.rpm
readline-4.2a-4.src.rpm
readline2.2.1-2.2.1-4.src.rpm
readline41-4.1-10.src.rpm
recode-3.6-4.src.rpm
redhat-config-network-1.0.0-1.src.rpm
redhat-config-users-1.0.1-5.src.rpm
redhat-logos-1.1.3-1.src.rpm
redhat-lsb-1.1.0-0.5.src.rpm
redhat-release-7.3-1.src.rpm
redhat-switch-printer-0.5.1-2.src.rpm
redhat-switchmail-0.5.1-1.src.rpm
reiserfs-utils-3.x.0j-3.src.rpm
rep-gtk-0.15-7.src.rpm
rhmask-1.0-10.src.rpm
rhn-applet-1.0.6-11.src.rpm
rhn_register-2.7.21-7.x.3.src.rpm
rootfiles-7.2-1.src.rpm
routed-0.17-8.src.rpm
rp-pppoe-3.3-7.src.rpm
rpm-4.0.4-7x.18.src.rpm
rpm2html-1.7-6.src.rpm
rpmdb-redhat-7.3-0.20020613.src.rpm
rpmfind-1.7-7.src.rpm
rpmlint-0.38-5.src.rpm
rsh-0.17-5.src.rpm
rsync-2.5.4-2.src.rpm
ruby-1.6.7-2.src.rpm
rusers-0.17-12.src.rpm
rwall-0.17-10.src.rpm
rwho-0.17-11.src.rpm
rxvt-2.7.8-3.src.rpm
samba-2.2.3a-6.src.rpm
sane-backends-1.0.7-6.src.rpm
sane-frontends-1.0.7-2.src.rpm
sash-3.4-11.src.rpm
sawfish-1.0.1-9.src.rpm
screen-3.9.11-3.src.rpm
scrollkeeper-0.3.4-4.src.rpm
sed-3.02-11.src.rpm
semi-1.14.3-11.src.rpm
sendmail-8.11.6-15.src.rpm
serviceconf-0.7.0-3.src.rpm
setserial-2.17-5.src.rpm
setup-2.5.12-1.src.rpm
setuptool-1.8-2.src.rpm
sgml-common-0.6.3-9.src.rpm
sh-utils-2.0.11-14.src.rpm
shadow-utils-20000902-7.src.rpm
shapecfg-2.2.12-8.src.rpm
sharutils-4.2.1-9.src.rpm
sip-3.1-2.src.rpm
skkdic-20020220-2.src.rpm
skkinput-2.03-9.src.rpm
slang-1.4.5-2.src.rpm
sliplogin-2.1.1-12.src.rpm
slocate-2.6-1.src.rpm
slrn-0.9.7.4-1.src.rpm
smpeg-0.4.4-9.src.rpm
smpeg-xmms-0.3.4-6.src.rpm
snavigator-5.0-7.src.rpm
sndconfig-0.68-1.src.rpm
sox-12.17.3-4.src.rpm
specspo-7.3-4.src.rpm
splint-3.0.1.6-2.src.rpm
squid-2.4.STABLE6-1.7.2.src.rpm
stardict-1.31-7.src.rpm
stat-2.5-5.src.rpm
statserial-1.1-27.src.rpm
strace-4.4-4.src.rpm
stunnel-3.22-1.src.rpm
sudo-1.6.5p2-2.src.rpm
swig-1.1p5-12.src.rpm
switchdesk-3.9.8-2.src.rpm
sylpheed-0.7.3-1.src.rpm
symlinks-1.2-13.src.rpm
sysctlconfig-0.15-1.src.rpm
sysklogd-1.4.1-8.src.rpm
syslinux-1.52-2.src.rpm
sysreport-1.3-2.src.rpm
sysstat-4.0.3-2.src.rpm
taipeifonts-1.2-16.src.rpm
talk-0.17-12.src.rpm
tamago-4.0.6-5.src.rpm
taper-6.9b-4.src.rpm
tar-1.13.25-4.src.rpm
tcltk-8.3.3-67.src.rpm
tcp_wrappers-7.6-19.src.rpm
tcpdump-3.6.2-12.src.rpm
tcsh-6.10-6.src.rpm
telnet-0.17-20.src.rpm
termcap-11.0.1-10.src.rpm
);

# start timing
die unless system ("date") == 0;
my $all_start_time = `date +'%s'`;
chomp $all_start_time;

# build each rpm
for my $rpm_file (@rpm_files) {
  # check if we should stop
  if (-f "BUILD_STOP") {
    print "stopping due to existence of BUILD_STOP\n";
    last;
  }

  # get the fully qualified name
  my $fq_rpm_file = "/usr/src/redhat/SRPMS/$rpm_file";
  die unless -f "$fq_rpm_file";

  # get the package name
  my $package = $rpm_file;
  $package =~ s/\.src\.rpm$//;
  print "**** package: $package\n";

  # time this package
  die unless system ("date") == 0;
  my $start_time = `date +'%s'`;
  chomp $start_time;

  # make the subdirectory names
  my $package_build_dir="$build_dir/$package";
  die if -d $package_build_dir;
  die if system("mkdir $package_build_dir");
  die if system("mkdir $package_build_dir/BUILD");
  # use the same dir for now as we generate no metadata
  #my $rpm_dir="$package_build_dir/RPM";
  my $rpm_dir="$package_build_dir";

  # extract the package
  my $extractCmd="rpm --define \"_topdir $rpm_dir\" -i $fq_rpm_file";
  print "$extractCmd\n";
  if (system($extractCmd)) {
    print "failed: $extractCmd\n";
    next;
  }

  # build each 'spec'(?) in the package
  my @specs = (split /\n/, `ls $rpm_dir/SPECS/*.spec`);
  for my $spec (@specs) {
    # use -bp instead of -bc if you want to just unpack and not
    # actually build the package
    my $mode = "-bc";           # unpack and build
#    my $mode = "-bp";           # unpack only
    my $buildCmd="rpmbuild --define \"_topdir $rpm_dir\" --nodeps $mode $spec";
    print "$buildCmd\n";
    if (system($buildCmd)) {
      print "****FAILED package:$package, spec:$spec, cmd:$buildCmd\n";
      last;
    }
  }

  # stop timing this package
  my $stop_time = `date +'%s'`;
  chomp $stop_time;
  my $total_time = $stop_time - $start_time;
  my $total_str = "done $package, time=$total_time";
}

# stop timing
die unless system ("date") == 0;
my $all_stop_time = `date +'%s'`;
chomp $all_stop_time;
my $all_total_time = $all_stop_time - $all_start_time;
print "all total time: $all_total_time\n";
