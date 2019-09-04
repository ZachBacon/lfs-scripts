#!/bin/bash
#
# PiLFS Build Script SVN-20190902 v1.0
# Performs post-build installs starting from chapter 6.80. Cleaning Up
# https://intestinate.com/pilfs
#
# Optional parameteres below:

PARALLEL_JOBS=4                 # Number of parallel make jobs, 1 for RPi1 and 4 for RPi2 and up recommended.

# End of optional parameters

set -o nounset
set -o errexit

function prebuild_sanity_check {
    if [[ $(whoami) != "root" ]] ; then
        echo "You should be running as root for the post build!"
        exit 1
    fi

    if ! [[ -d /usr/src ]] ; then
        echo "Can't find your /usr/src directory! Did you forget to chroot?"
        exit 1
    fi
}

function check_tarballs {
LIST_OF_TARBALLS="
which-2.21.tar.gz
rng-tools_2-unofficial-mt.14.orig.tar.bz2
pcre-8.43.tar.bz2
wget-1.20.3.tar.gz
make-ca-0.8.tar.gz
libevent-2.1.11-stable.tar.gz
tmux-2.9a.tar.gz
openssh-8.0p1.tar.gz
joe-4.6.tar.gz
master.tar.gz
Mozilla-CA-20180117.tar.gz
Net-SSLeay-1.88.tar.gz
IO-Socket-SSL-2.066.tar.gz
ntp-4.2.8p13.tar.gz
blfs-bootscripts-20190902.tar.xz
dhcpcd-8.0.3.tar.xz
unzip60.tar.gz
sqlite-autoconf-3290000.tar.gz
curl-7.65.3.tar.xz
Python-2.7.16.tar.xz
git-2.23.0.tar.xz
git-manpages-2.23.0.tar.xz
libnl-3.4.0.tar.gz
wpa_supplicant-2.9.tar.gz
iw-5.3.tar.xz
swig-4.0.1.tar.gz
wireless-regdb-2019.06.03.tar.xz
libgpg-error-1.36.tar.bz2
libgcrypt-1.8.5.tar.bz2
crda-3.18.tar.xz
alsa-lib-1.1.9.tar.bz2
alsa-utils-1.1.9.tar.bz2
1BOfJ
"

for tarball in $LIST_OF_TARBALLS ; do
    if ! [[ -f /usr/src/$tarball ]] ; then
        echo "Can't find /usr/src/$tarball!"
        exit 1
    fi
done
}

function timer {
    if [[ $# -eq 0 ]]; then
        echo $(date '+%s')
    else
        local stime=$1
        etime=$(date '+%s')
        if [[ -z "$stime" ]]; then stime=$etime; fi
        dt=$((etime - stime))
        ds=$((dt % 60))
        dm=$(((dt / 60) % 60))
        dh=$((dt / 3600))
        printf '%02d:%02d:%02d' $dh $dm $ds
    fi
}

prebuild_sanity_check
check_tarballs

echo -e "\nThis is your last chance to quit before we start building... continue?"
echo "(Note that if anything goes wrong during the build, the script will abort mission)"
select yn in "Yes" "No"; do
    case $yn in
        Yes) break;;
        No) exit;;
    esac
done

total_time=$(timer)

echo "# 6.80. Cleaning Up"
cd /sources
rm -f /usr/lib/lib{bfd,opcodes}.a
rm -f /usr/lib/libbz2.a
rm -f /usr/lib/lib{com_err,e2p,ext2fs,ss}.a
rm -f /usr/lib/libltdl.a
rm -f /usr/lib/libfl.a
rm -f /usr/lib/libz.a
find /usr/lib /usr/libexec -name \*.la -delete

echo "# 7.2. LFS-Bootscripts-20190902"
tar -Jxf lfs-bootscripts-20190902.tar.xz
cd lfs-bootscripts-20190902
make install
cd /sources
rm -rf lfs-bootscripts-20190902

echo "# 7.2.X PiLFS-bootscripts-20190902"
tar -Jxf pilfs-bootscripts-20190902.tar.xz
cd pilfs-bootscripts-20190902
make install-everything
cat > /etc/fake-hwclock.data << "EOF"
2019-09-02 00:00:00
EOF
cd /sources
rm -rf pilfs-bootscripts-20190902

echo "# 7.5.1. Creating Network Interface Configuration Files"
cat > /etc/sysconfig/static.eth0 << "EOF"
ONBOOT=yes
IFACE=eth0
SERVICE=ipv4-static
IP=192.168.1.10
GATEWAY=192.168.1.1
PREFIX=24
BROADCAST=192.168.1.255
EOF

echo "# 7.5.2. Creating the /etc/resolv.conf File"
cat > /etc/resolv.conf << "EOF"
# Begin /etc/resolv.conf

nameserver 8.8.8.8
nameserver 8.8.4.4

# End /etc/resolv.conf
EOF

echo "# 7.5.3. Configuring the system hostname"
echo "pilfs" > /etc/hostname

echo "# 7.5.4. Customizing the /etc/hosts File"
cat > /etc/hosts << "EOF"
# Begin /etc/hosts

127.0.0.1 localhost
127.0.1.1 pilfs
::1       localhost ip6-localhost ip6-loopback
ff02::1   ip6-allnodes
ff02::2   ip6-allrouters

# End /etc/hosts
EOF

echo "# 7.6.2. Configuring Sysvinit"
cat > /etc/inittab << "EOF"
# Begin /etc/inittab

id:3:initdefault:

si::sysinit:/etc/rc.d/init.d/rc S

l0:0:wait:/etc/rc.d/init.d/rc 0
l1:S1:wait:/etc/rc.d/init.d/rc 1
l2:2:wait:/etc/rc.d/init.d/rc 2
l3:3:wait:/etc/rc.d/init.d/rc 3
l4:4:wait:/etc/rc.d/init.d/rc 4
l5:5:wait:/etc/rc.d/init.d/rc 5
l6:6:wait:/etc/rc.d/init.d/rc 6

ca:12345:ctrlaltdel:/sbin/shutdown -t1 -a -r now

su:S016:once:/sbin/sulogin

1:2345:respawn:/sbin/agetty --noclear tty1 9600
2:2345:respawn:/sbin/agetty tty2 9600
3:2345:respawn:/sbin/agetty tty3 9600
4:2345:respawn:/sbin/agetty tty4 9600
5:2345:respawn:/sbin/agetty tty5 9600
6:2345:respawn:/sbin/agetty tty6 9600

# End /etc/inittab
EOF

echo "# 7.6.4. Configuring the System Clock"
cat > /etc/sysconfig/clock << "EOF"
# Begin /etc/sysconfig/clock

UTC=1

# Set this to any options you might need to give to hwclock,
# such as machine hardware clock type for Alphas.
CLOCKPARAMS=

# End /etc/sysconfig/clock
EOF

echo "# 7.6.8. The rc.site File"
cat > /etc/sysconfig/rc.site << "EOF"
# rc.site
# Optional parameters for boot scripts.

# Distro Information
# These values, if specified here, override the defaults
DISTRO="Linux From Scratch on the Raspberry Pi" # The distro name
DISTRO_CONTACT="lfs4pi@gmail.com" # Bug report address
DISTRO_MINI="PiLFS" # Short name used in filenames for distro config

# Define custom colors used in messages printed to the screen

# Please consult `man console_codes` for more information
# under the "ECMA-48 Set Graphics Rendition" section
#
# Warning: when switching from a 8bit to a 9bit font,
# the linux console will reinterpret the bold (1;) to
# the top 256 glyphs of the 9bit font.  This does
# not affect framebuffer consoles

# These values, if specified here, override the defaults
#BRACKET="\\033[1;34m" # Blue
#FAILURE="\\033[1;31m" # Red
#INFO="\\033[1;36m"    # Cyan
#NORMAL="\\033[0;39m"  # Grey
#SUCCESS="\\033[1;32m" # Green
#WARNING="\\033[1;33m" # Yellow

# Use a colored prefix
# These values, if specified here, override the defaults
#BMPREFIX="     "
#SUCCESS_PREFIX="${SUCCESS}  *  ${NORMAL}"
#FAILURE_PREFIX="${FAILURE}*****${NORMAL}"
#WARNING_PREFIX="${WARNING} *** ${NORMAL}"

# Manually seet the right edge of message output (characters)
# Useful when resetting console font during boot to override
# automatic screen width detection
#COLUMNS=120

# Interactive startup
#IPROMPT="yes" # Whether to display the interactive boot prompt
#itime="3"    # The amount of time (in seconds) to display the prompt

# The total length of the distro welcome string, without escape codes
#wlen=$(echo "Welcome to ${DISTRO}" | wc -c )
#welcome_message="Welcome to ${INFO}${DISTRO}${NORMAL}"

# The total length of the interactive string, without escape codes
#ilen=$(echo "Press 'I' to enter interactive startup" | wc -c )
#i_message="Press '${FAILURE}I${NORMAL}' to enter interactive startup"

# Set scripts to skip the file system check on reboot
#FASTBOOT=yes

# Skip reading from the console
HEADLESS=yes

# Write out fsck progress if yes
VERBOSE_FSCK=yes

# Speed up boot without waiting for settle in udev
#OMIT_UDEV_SETTLE=yes

# Speed up boot without waiting for settle in udev_retry
#OMIT_UDEV_RETRY_SETTLE=yes

# Skip cleaning /tmp if yes
#SKIPTMPCLEAN=no

# For setclock
#UTC=1
#CLOCKPARAMS=

# For consolelog (Note that the default, 7=debug, is noisy)
#LOGLEVEL=7

# For network
#HOSTNAME=pilfs

# Delay between TERM and KILL signals at shutdown
#KILLDELAY=3

# Optional sysklogd parameters
#SYSKLOGD_PARMS="-m 0"

# Console parameters
#UNICODE=1
#KEYMAP="de-latin1"
#KEYMAP_CORRECTIONS="euro2"
#FONT="lat0-16 -m 8859-15"
#LEGACY_CHARSET=
EOF

echo "# 7.8. Creating the /etc/inputrc File"
cat > /etc/inputrc << "EOF"
# Begin /etc/inputrc
# Modified by Chris Lynn <roryo@roryo.dynup.net>

# Allow the command prompt to wrap to the next line
set horizontal-scroll-mode Off

# Enable 8bit input
set meta-flag On
set input-meta On

# Turns off 8th bit stripping
set convert-meta Off

# Keep the 8th bit for display
set output-meta On

# none, visible or audible
set bell-style none

# All of the following map the escape sequence of the value
# contained in the 1st argument to the readline specific functions
"\eOd": backward-word
"\eOc": forward-word

# for linux console
"\e[1~": beginning-of-line
"\e[4~": end-of-line
"\e[5~": beginning-of-history
"\e[6~": end-of-history
"\e[3~": delete-char
"\e[2~": quoted-insert

# for xterm
"\eOH": beginning-of-line
"\eOF": end-of-line

# for Konsole
"\e[H": beginning-of-line
"\e[F": end-of-line

# End /etc/inputrc
EOF

echo "# 7.9. Creating the /etc/shells File"
cat > /etc/shells << "EOF"
# Begin /etc/shells

/bin/sh
/bin/bash

# End /etc/shells
EOF

echo "# 8.2. Creating the /etc/fstab File"
cat > /etc/fstab << "EOF"
# Begin /etc/fstab

# file system  mount-point  type     options                     dump  fsck
#                                                                      order

/dev/mmcblk0p1 /boot        vfat     defaults                    0     1
/dev/mmcblk0p2 /            ext4     defaults,noatime,nodiratime 0     2
#/swapfile     swap         swap     pri=1                       0     0
proc           /proc        proc     nosuid,noexec,nodev         0     0
sysfs          /sys         sysfs    nosuid,noexec,nodev         0     0
devpts         /dev/pts     devpts   gid=5,mode=620              0     0
tmpfs          /run         tmpfs    defaults                    0     0
devtmpfs       /dev         devtmpfs mode=0755,nosuid            0     0

# End /etc/fstab
EOF

echo "# 9.1. The End"
echo SVN-20190902 > /etc/lfs-release
cat > /etc/lsb-release << "EOF"
DISTRIB_ID="PiLFS"
DISTRIB_RELEASE="SVN-20190902"
DISTRIB_CODENAME="Mogwai"
DISTRIB_DESCRIPTION="https://intestinate.com/pilfs"
EOF

echo "# Moving on to /usr/src"
cd /usr/src

echo "# Which-2.21"
tar -zxf which-2.21.tar.gz
cd which-2.21
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf which-2.21

echo "# rng-tools_2-unofficial-mt.14"
tar -jxf rng-tools_2-unofficial-mt.14.orig.tar.bz2
cd rng-tools-2-unofficial-mt.14
./autogen.sh
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf rng-tools-2-unofficial-mt.14

echo "# PCRE-8.43"
tar -jxf pcre-8.43.tar.bz2
cd pcre-8.43
./configure --prefix=/usr                     \
            --docdir=/usr/share/doc/pcre-8.43 \
            --enable-unicode-properties       \
            --enable-pcre16                   \
            --enable-pcre32                   \
            --enable-pcregrep-libz            \
            --enable-pcregrep-libbz2          \
            --enable-pcretest-libreadline     \
            --disable-static                  \
            --enable-jit
make -j $PARALLEL_JOBS
make install
mv -v /usr/lib/libpcre.so.* /lib
ln -sfv ../../lib/$(readlink /usr/lib/libpcre.so) /usr/lib/libpcre.so
cd /usr/src
rm -rf pcre-8.43

echo "# Wget-1.20.3"
tar -zxf wget-1.20.3.tar.gz
cd wget-1.20.3
./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --with-ssl=openssl
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf wget-1.20.3

echo "# make-ca-0.8"
tar -zxf make-ca-0.8.tar.gz
cd make-ca-0.8
make install
/usr/sbin/make-ca -g
cd /usr/src
rm -rf make-ca-0.8

echo "# libevent-2.1.11"
tar -zxf libevent-2.1.11-stable.tar.gz
cd libevent-2.1.11-stable
./configure --prefix=/usr --disable-static
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf libevent-2.1.11-stable

echo "# tmux-2.9a"
tar -zxf tmux-2.9a.tar.gz
cd tmux-2.9a
./configure --prefix=/usr --sysconfdir=/etc --disable-static
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf tmux-2.9a

echo "# OpenSSH-8.0p1"
tar -zxf openssh-8.0p1.tar.gz
cd openssh-8.0p1
install  -v -m700 -d /var/lib/sshd
chown    -v root:sys /var/lib/sshd
groupadd -g 50 sshd
useradd  -c 'sshd PrivSep' \
         -d /var/lib/sshd  \
         -g sshd           \
         -s /bin/false     \
         -u 50 sshd
./configure --prefix=/usr                     \
            --sysconfdir=/etc/ssh             \
            --with-md5-passwords              \
            --with-privsep-path=/var/lib/sshd
make -j $PARALLEL_JOBS
make install
install -v -m755 contrib/ssh-copy-id /usr/bin
install -v -m644 contrib/ssh-copy-id.1 /usr/share/man/man1
rm -vf /etc/ssh/ssh_host*
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
cd /usr/src
rm -rf openssh-8.0p1

echo "# JOE-4.6"
tar -zxf joe-4.6.tar.gz
cd joe-4.6
./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/joe-4.6
make -j $PARALLEL_JOBS
make install
install -vm 755 joe/util/{stringify,termidx,uniproc} /usr/bin
cd /usr/src
rm -rf joe-4.6

echo "# arm-mem"
mv master.tar.gz arm-mem.tar.gz
tar -zxf arm-mem.tar.gz
cd arm-mem-master
make -j $PARALLEL_JOBS
cp -v libarmmem-v7l.so /usr/lib
echo "/usr/lib/libarmmem-v7l.so" >> /etc/ld.so.preload
cd /usr/src
rm -rf arm-mem-master

echo "# Mozilla-CA-20180117"
tar -zxf Mozilla-CA-20180117.tar.gz
cd Mozilla-CA-20180117
perl Makefile.PL
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf Mozilla-CA-20180117

echo "# Net-SSLeay-1.88"
tar -zxf Net-SSLeay-1.88.tar.gz
cd Net-SSLeay-1.88
echo n | perl Makefile.PL
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf Net-SSLeay-1.88

echo "# IO-Socket-SSL-2.066"
tar -zxf IO-Socket-SSL-2.066.tar.gz
cd IO-Socket-SSL-2.066
echo n | perl Makefile.PL
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf IO-Socket-SSL-2.066

echo "# ntp-4.2.8p13"
tar -zxf ntp-4.2.8p13.tar.gz
cd ntp-4.2.8p13
groupadd -g 87 ntp
useradd -c "Network Time Protocol" -d /var/lib/ntp -u 87 -g ntp -s /bin/false ntp
sed -e 's/"(\\S+)"/"?([^\\s"]+)"?/' -i scripts/update-leap/update-leap.in
./configure CFLAGS="-O2 -g -fPIC" \
            --prefix=/usr         \
            --bindir=/usr/sbin    \
            --sysconfdir=/etc     \
            --enable-linuxcaps    \
            --disable-static      \
            --with-lineeditlibs=readline \
            --docdir=/usr/share/doc/ntp-4.2.8p13
make -j $PARALLEL_JOBS
make install
install -v -o ntp -g ntp -d /var/lib/ntp
cat > /etc/ntp.conf << "EOF"
# Europe
server 0.europe.pool.ntp.org

# North America
server 0.north-america.pool.ntp.org

# Australia
server 0.oceania.pool.ntp.org

# Asia
server 0.asia.pool.ntp.org

# South America
server 2.south-america.pool.ntp.org

driftfile /var/lib/ntp/ntp.drift
pidfile   /var/run/ntpd.pid
leapfile  /etc/ntp.leapseconds

# Security session
restrict    default limited kod nomodify notrap nopeer noquery
restrict -6 default limited kod nomodify notrap nopeer noquery

restrict 127.0.0.1
restrict ::1
EOF
/usr/sbin/update-leap
cd /usr/src
rm -rf ntp-4.2.8p13

echo "# dhcpcd-8.0.3"
tar -Jxf dhcpcd-8.0.3.tar.xz
cd dhcpcd-8.0.3
./configure --libexecdir=/lib/dhcpcd \
            --dbdir=/var/lib/dhcpcd
make -j $PARALLEL_JOBS
make install
cat > /etc/sysconfig/ifconfig.eth0 << "EOF"
ONBOOT="yes"
IFACE="eth0"
SERVICE="dhcpcd"
DHCP_START="-b -q"
DHCP_STOP="-k"
EOF
cp -v /etc/sysconfig/ifconfig.eth0 /etc/sysconfig/dhcp.eth0
cd /usr/src
rm -rf dhcpcd-8.0.3

echo "# UnZip-6.0"
tar -zxf unzip60.tar.gz
cd unzip60
make -j $PARALLEL_JOBS -f unix/Makefile generic
make prefix=/usr MANDIR=/usr/share/man/man1 -f unix/Makefile install
cd /usr/src
rm -rf unzip60

echo "# SQLite-3.29.0"
tar -zxf sqlite-autoconf-3290000.tar.gz
cd sqlite-autoconf-3290000
./configure --prefix=/usr     \
            --disable-static  \
            --enable-fts5     \
            CFLAGS="-g -O2                    \
            -DSQLITE_ENABLE_FTS3=1            \
            -DSQLITE_ENABLE_FTS4=1            \
            -DSQLITE_ENABLE_COLUMN_METADATA=1 \
            -DSQLITE_ENABLE_UNLOCK_NOTIFY=1   \
            -DSQLITE_ENABLE_DBSTAT_VTAB=1     \
            -DSQLITE_SECURE_DELETE=1          \
            -DSQLITE_ENABLE_FTS3_TOKENIZER=1"
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf sqlite-autoconf-3290000

echo "# cURL-7.65.3"
tar -Jxf curl-7.65.3.tar.xz
cd curl-7.65.3
./configure --prefix=/usr                           \
            --disable-static                        \
            --enable-threaded-resolver              \
            --with-ca-path=/etc/ssl/certs
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf curl-7.65.3

echo "# Python-2.7.16"
tar -Jxf Python-2.7.16.tar.xz
cd Python-2.7.16
./configure --prefix=/usr       \
            --enable-shared     \
            --with-system-expat \
            --with-system-ffi   \
            --with-ensurepip=yes \
            --enable-unicode=ucs4
make -j $PARALLEL_JOBS
make install
chmod -v 755 /usr/lib/libpython2.7.so.1.0
cd /usr/src
rm -rf Python-2.7.16

echo "# Git-2.23.0"
tar -Jxf git-2.23.0.tar.xz
cd git-2.23.0
./configure --prefix=/usr --with-gitconfig=/etc/gitconfig --sysconfdir=/etc --with-libpcre
make -j $PARALLEL_JOBS
make install
tar -xf ../git-manpages-2.23.0.tar.xz -C /usr/share/man --no-same-owner --no-overwrite-dir
cd /usr/src
rm -rf git-2.23.0

echo "# libnl-3.4.0"
tar -zxf libnl-3.4.0.tar.gz
cd libnl-3.4.0
./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --disable-static
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf libnl-3.4.0

echo "# wpa_supplicant-2.9"
tar -zxf wpa_supplicant-2.9.tar.gz
cd wpa_supplicant-2.9
cat > wpa_supplicant/.config << "EOF"
CONFIG_BACKEND=file
CONFIG_CTRL_IFACE=y
CONFIG_DEBUG_FILE=y
CONFIG_DEBUG_SYSLOG=y
CONFIG_DEBUG_SYSLOG_FACILITY=LOG_DAEMON
CONFIG_DRIVER_NL80211=y
CONFIG_DRIVER_WEXT=y
CONFIG_DRIVER_WIRED=y
CONFIG_EAP_GTC=y
CONFIG_EAP_LEAP=y
CONFIG_EAP_MD5=y
CONFIG_EAP_MSCHAPV2=y
CONFIG_EAP_OTP=y
CONFIG_EAP_PEAP=y
CONFIG_EAP_TLS=y
CONFIG_EAP_TTLS=y
CONFIG_IEEE8021X_EAPOL=y
CONFIG_IPV6=y
CONFIG_LIBNL32=y
CONFIG_PEERKEY=y
CONFIG_PKCS12=y
CONFIG_READLINE=y
CONFIG_SMARTCARD=y
CONFIG_WPS=y
CFLAGS += -I/usr/include/libnl3
EOF
cd wpa_supplicant
make -j $PARALLEL_JOBS BINDIR=/sbin LIBDIR=/lib
install -v -m755 wpa_{cli,passphrase,supplicant} /sbin/
install -v -m644 doc/docbook/wpa_supplicant.conf.5 /usr/share/man/man5/
install -v -m644 doc/docbook/wpa_{cli,passphrase,supplicant}.8 /usr/share/man/man8/
cat > /etc/sysconfig/ifconfig.wlan0 << "EOF"
ONBOOT="yes"
IFACE="wlan0"
SERVICE="wpa"

# Additional arguments to wpa_supplicant
WPA_ARGS=""

WPA_SERVICE="dhcpcd"
DHCP_START="-b -q"
DHCP_STOP="-k"
EOF
cd /usr/src
rm -rf wpa_supplicant-2.9

echo "# iw-5.3"
tar -Jxf iw-5.3.tar.xz
cd iw-5.3
sed -i "/INSTALL.*gz/s/.gz//" Makefile
make -j $PARALLEL_JOBS
make SBINDIR=/sbin install
cd /usr/src
rm -rf iw-5.3

echo "# setuptools"
/usr/bin/pip install -U pip setuptools

echo "# SWIG-4.0.1"
tar -zxf swig-4.0.1.tar.gz
cd swig-4.0.1
./configure --prefix=/usr \
            --without-maximum-compile-warnings
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf swig-4.0.1

echo "# M2Crypto"
/usr/bin/pip install M2Crypto

echo "# Restore pip3"
python3 -m pip install --force pip

echo "# wireless-regdb-2019.06.03"
tar -Jxf wireless-regdb-2019.06.03.tar.xz
cd wireless-regdb-2019.06.03
mkdir -vp /usr/lib/crda
cp -v regulatory.bin /usr/lib/crda
cd /usr/src
rm -rf wireless-regdb-2019.06.03

echo "# libgpg-error-1.36"
tar -jxf libgpg-error-1.36.tar.bz2
cd libgpg-error-1.36
sed -i 's/namespace/pkg_&/' src/Makefile.{am,in} src/mkstrtable.awk
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf libgpg-error-1.36

echo "# libgcrypt-1.8.5"
tar -jxf libgcrypt-1.8.5.tar.bz2
cd libgcrypt-1.8.5
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf libgcrypt-1.8.5

echo "# crda-3.18"
tar -Jxf crda-3.18.tar.xz
cd crda-3.18
sed -i 's/-Werror//' Makefile
USE_GCRYPT=1 make -j $PARALLEL_JOBS
USE_GCRYPT=1 make install
cd /usr/src
rm -rf crda-3.18

echo "# alsa-lib-1.1.9"
tar -jxf alsa-lib-1.1.9.tar.bz2
cd alsa-lib-1.1.9
./configure
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf alsa-lib-1.1.9

echo "# alsa-utils-1.1.9"
tar -jxf alsa-utils-1.1.9.tar.bz2
cd alsa-utils-1.1.9
./configure --disable-alsaconf \
            --disable-bat   \
            --disable-xmlto \
            --with-curses=ncursesw
make -j $PARALLEL_JOBS
make install
/usr/bin/amixer sset 'PCM' 0dB
/usr/sbin/alsactl -L store
cd /usr/src
rm -rf alsa-utils-1.1.9

echo "# rpi-update"
mv 1BOfJ rpi-update
install -v -m755 rpi-update /usr/sbin

echo "# BLFS Boot Scripts"
tar -Jxf blfs-bootscripts-20190902.tar.xz
cd blfs-bootscripts-20190902
make install-ntpd install-service-dhcpcd install-service-wpa
cd /usr/src
rm -rf blfs-bootscripts-20190902

echo "# Cleaning up"
ls -1 > /tmp/installed_tarballs.txt
mv -v /tmp/installed_tarballs.txt /usr/src
ldconfig

echo -e "--------------------------------------------------------------------"
printf 'Total script time: %s\n' $(timer $total_time)