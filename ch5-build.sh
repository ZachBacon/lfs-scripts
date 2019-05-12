#!/bin/bash
#
# PiLFS Build Script SVN-20190503-aarch64 v1.0
# Builds chapters 5.4 - Binutils to 5.34 - Xz
# http://www.intestinate.com/pilfs
#
# Optional parameteres below:

PARALLEL_JOBS=4             # Number of parallel make jobs, 1 for RPi1 and 4 for RPi2 and RPi3 recommended.
STRIP_AND_DELETE_DOCS=1     # Strip binaries and delete manpages to save space at the end of chapter 5?

# End of optional parameters

set -o nounset
set -o errexit

function prebuild_sanity_check {
    if [[ $(whoami) != "lfs" ]] ; then
        echo "Not running as user lfs, you should be!"
        exit 1
    fi

    if ! [[ -v LFS ]] ; then
        echo "You forgot to set your LFS environment variable!"
        exit 1
    fi

    if ! [[ -v LFS_TGT ]] || [[ $LFS_TGT != "aarch64-lfs-linux-gnu" ]] ; then
        echo "Your LFS_TGT variable should be set to aarch64-lfs-linux-gnu"
        exit 1
    fi

    if ! [[ -d $LFS ]] ; then
        echo "Your LFS directory doesn't exist!"
        exit 1
    fi

    if ! [[ -d $LFS/sources ]] ; then
        echo "Can't find your sources directory!"
        exit 1
    fi

    if [[ $(stat -c %U $LFS/sources) != "lfs" ]] ; then
        echo "The sources directory should be owned by user lfs!"
        exit 1
    fi

    if ! [[ -d $LFS/tools ]] ; then
        echo "Can't find your tools directory!"
        exit 1
    fi

    if [[ $(stat -c %U $LFS/tools) != "lfs" ]] ; then
        echo "The tools directory should be owned by user lfs!"
        exit 1
    fi
}

function check_tarballs {
LIST_OF_TARBALLS="
binutils-2.32.tar.xz
gcc-9.1.0.tar.xz
mpfr-4.0.2.tar.xz
gmp-6.1.2.tar.xz
mpc-1.1.0.tar.gz
rpi-4.19.y.tar.gz
glibc-2.29.tar.xz
tcl8.6.9-src.tar.gz
expect5.45.4.tar.gz
expect5.45-aarch64-fix.patch
dejagnu-1.6.2.tar.gz
ncurses-6.1.tar.gz
bash-5.0.tar.gz
bison-3.3.2.tar.xz
bzip2-1.0.6.tar.gz
coreutils-8.31.tar.xz
diffutils-3.7.tar.xz
file-5.36.tar.gz
findutils-4.6.0.tar.gz
gawk-5.0.0.tar.xz
gettext-0.19.8.1.tar.xz
grep-3.3.tar.xz
gzip-1.10.tar.xz
m4-1.4.18.tar.xz
make-4.2.1.tar.bz2
patch-2.7.6.tar.xz
perl-5.28.2.tar.xz
Python-3.7.3.tar.xz
sed-4.7.tar.xz
tar-1.32.tar.xz
texinfo-6.6.tar.xz
xz-5.2.4.tar.xz
"

for tarball in $LIST_OF_TARBALLS ; do
    if ! [[ -f $LFS/sources/$tarball ]] ; then
        echo "Can't find $LFS/sources/$tarball!"
        exit 1
    fi
done
}

function do_strip {
    set +o errexit
    if [[ $STRIP_AND_DELETE_DOCS = 1 ]] ; then
        strip --strip-debug /tools/lib/*
        /usr/bin/strip --strip-unneeded /tools/{,s}bin/*
        rm -rf /tools/{,share}/{info,man,doc}
        find /tools/{lib,libexec} -name \*.la -delete
    fi
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

if [[ $(free | grep 'Swap:' | tr -d ' ' | cut -d ':' -f2) == "000" ]] ; then
    echo -e "\nYou are almost certainly going to want to add some swap space before building!"
    echo -e "(See http://www.intestinate.com/pilfs/beyond.html#addswap for instructions)"
    echo -e "Continue without swap?"
    select yn in "Yes" "No"; do
        case $yn in
            Yes ) break;;
            No ) exit;;
        esac
    done
fi

echo -e "\nThis is your last chance to quit before we start building... continue?"
echo "(Note that if anything goes wrong during the build, the script will abort mission)"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done

total_time=$(timer)
sbu_time=$(timer)

echo "# 5.4. Binutils-2.32 - Pass 1"
cd $LFS/sources
tar -Jxf binutils-2.32.tar.xz
cd binutils-2.32
mkdir -v build
cd build
../configure --prefix=/tools            \
             --with-sysroot=$LFS        \
             --with-lib-path=/tools/lib \
             --target=$LFS_TGT          \
             --disable-nls              \
             --disable-werror
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf binutils-2.32

echo -e "\n=========================="
printf 'Your SBU time is: %s\n' $(timer $sbu_time)
echo -e "==========================\n"

echo "# 5.5. gcc-9.1.0 - Pass 1"
tar -Jxf gcc-9.1.0.tar.xz
cd gcc-9.1.0
tar -Jxf ../mpfr-4.0.2.tar.xz
mv -v mpfr-4.0.2 mpfr
tar -Jxf ../gmp-6.1.2.tar.xz
mv -v gmp-6.1.2 gmp
tar -zxf ../mpc-1.1.0.tar.gz
mv -v mpc-1.1.0 mpc
for file in \
 $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h -o -name linux-eabi.h -o -name linux-elf.h -o -name aarch64-linux.h)
do
  cp -uv $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
      -e 's@/usr@/tools@g' $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done
sed -e '/mabi.lp64=/s/lib64/lib/' -i.orig gcc/config/aarch64/t-aarch64-linux
mkdir -v build
cd build
../configure                                       \
    --target=$LFS_TGT                              \
    --prefix=/tools                                \
    --with-glibc-version=2.11                      \
    --with-sysroot=$LFS                            \
    --with-newlib                                  \
    --without-headers                              \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-threads                              \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libmpx                               \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++
make
make install
cd $LFS/sources
rm -rf gcc-9.1.0

echo "# 5.6. Raspberry Pi Linux API Headers"
tar -zxf rpi-4.19.y.tar.gz
cd linux-rpi-4.19.y
make mrproper
make INSTALL_HDR_PATH=dest headers_install
cp -rv dest/include/* /tools/include
cd $LFS/sources

echo "# 5.7. Glibc-2.29"
tar -Jxf glibc-2.29.tar.xz
cd glibc-2.29
mkdir -v build
cd build
../configure                             \
      --prefix=/tools                    \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --enable-kernel=3.2                \
      --with-headers=/tools/include
make -j $PARALLEL_JOBS
make install
# Compatibility symlink for non ld-linux-armhf awareness
ln -sv ld-2.29.so $LFS/tools/lib/ld-linux.so.3
cd $LFS/sources
rm -rf glibc-2.29

echo "# 5.8. Libstdc++ from GCC-9.1.0"
tar -Jxf gcc-9.1.0.tar.xz
cd gcc-9.1.0
mkdir -v build
cd build
../libstdc++-v3/configure           \
    --host=$LFS_TGT                 \
    --prefix=/tools                 \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-threads     \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/9.1.0
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf gcc-9.1.0

echo "# 5.9. Binutils-2.32 - Pass 2"
tar -Jxf binutils-2.32.tar.xz
cd binutils-2.32
mkdir -v build
cd build
CC=$LFS_TGT-gcc                \
AR=$LFS_TGT-ar                 \
RANLIB=$LFS_TGT-ranlib         \
../configure                   \
    --prefix=/tools            \
    --disable-nls              \
    --disable-werror           \
    --with-lib-path=/tools/lib \
    --with-sysroot
make -j $PARALLEL_JOBS
make install
make -C ld clean
make -C ld LIB_PATH=/usr/lib:/lib
cp -v ld/ld-new /tools/bin
cd $LFS/sources
rm -rf binutils-2.32

echo "# 5.10. gcc-9.1.0 - Pass 2"
tar -Jxf gcc-9.1.0.tar.xz
cd gcc-9.1.0
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h
for file in \
 $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h -o -name linux-eabi.h -o -name linux-elf.h -o -name aarch64-linux.h)
do
  cp -uv $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
      -e 's@/usr@/tools@g' $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done
sed -e '/mabi.lp64=/s/lib64/lib/' -i.orig gcc/config/aarch64/t-aarch64-linux
tar -Jxf ../mpfr-4.0.2.tar.xz
mv -v mpfr-4.0.2 mpfr
tar -Jxf ../gmp-6.1.2.tar.xz
mv -v gmp-6.1.2 gmp
tar -zxf ../mpc-1.1.0.tar.gz
mv -v mpc-1.1.0 mpc
mkdir -v build
cd build
CC=$LFS_TGT-gcc                                    \
CXX=$LFS_TGT-g++                                   \
AR=$LFS_TGT-ar                                     \
RANLIB=$LFS_TGT-ranlib                             \
../configure                                       \
    --prefix=/tools                                \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --enable-languages=c,c++                       \
    --disable-libstdcxx-pch                        \
    --disable-multilib                             \
    --disable-bootstrap                            \
    --disable-libgomp
make
make install
ln -sv gcc /tools/bin/cc
cd $LFS/sources
rm -rf gcc-9.1.0

echo "# 5.11. Tcl-8.6.9"
tar -zxf tcl8.6.9-src.tar.gz
cd tcl8.6.9
cd unix
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
chmod -v u+w /tools/lib/libtcl8.6.so
make install-private-headers
ln -sv tclsh8.6 /tools/bin/tclsh
cd $LFS/sources
rm -rf tcl8.6.9

echo "# 5.12. Expect-5.45.4"
tar -zxf expect5.45.4.tar.gz
cd expect5.45.4
patch -Np1 -i ../expect5.45-aarch64-fix.patch
cp -v configure{,.orig}
sed 's:/usr/local/bin:/bin:' configure.orig > configure
./configure --prefix=/tools       \
            --with-tcl=/tools/lib \
            --with-tclinclude=/tools/include
make -j $PARALLEL_JOBS
make SCRIPTS="" install
cd $LFS/sources
rm -rf expect5.45.4

echo "# 5.13. DejaGNU-1.6.2"
tar -zxf dejagnu-1.6.2.tar.gz
cd dejagnu-1.6.2
./configure --prefix=/tools
make install
cd $LFS/sources
rm -rf dejagnu-1.6.2

echo "# 5.14. M4-1.4.18"
tar -Jxf m4-1.4.18.tar.xz
cd m4-1.4.18
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' lib/*.c
echo "#define _IO_IN_BACKUP 0x100" >> lib/stdio-impl.h
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf m4-1.4.18

echo "# 5.15. Ncurses-6.1"
tar -zxf ncurses-6.1.tar.gz
cd ncurses-6.1
sed -i s/mawk// configure
./configure --prefix=/tools \
            --with-shared   \
            --without-debug \
            --without-ada   \
            --enable-widec  \
            --enable-overwrite
make -j $PARALLEL_JOBS
make install
ln -s libncursesw.so /tools/lib/libncurses.so
cd $LFS/sources
rm -rf ncurses-6.1

echo "# 5.16. Bash-5.0"
tar -zxf bash-5.0.tar.gz
cd bash-5.0
./configure --prefix=/tools --without-bash-malloc
make -j $PARALLEL_JOBS
make install
ln -sv bash /tools/bin/sh
cd $LFS/sources
rm -rf bash-5.0

echo "# 5.17. Bison-3.3.2"
tar -Jxf bison-3.3.2.tar.xz
cd bison-3.3.2
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf bison-3.3.2

echo "# 5.18. Bzip2-1.0.6"
tar -zxf bzip2-1.0.6.tar.gz
cd bzip2-1.0.6
make -j $PARALLEL_JOBS
make PREFIX=/tools install
cd $LFS/sources
rm -rf bzip2-1.0.6

echo "# 5.19. Coreutils-8.31"
tar -Jxf coreutils-8.31.tar.xz
cd coreutils-8.31
./configure --prefix=/tools --enable-install-program=hostname
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf coreutils-8.31

echo "# 5.20. Diffutils-3.7"
tar -Jxf diffutils-3.7.tar.xz
cd diffutils-3.7
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf diffutils-3.7

echo "# 5.21. File-5.36"
tar -zxf file-5.36.tar.gz
cd file-5.36
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf file-5.36

echo "# 5.22. Findutils-4.6.0"
tar -zxf findutils-4.6.0.tar.gz
cd findutils-4.6.0
sed -i 's/IO_ftrylockfile/IO_EOF_SEEN/' gl/lib/*.c
sed -i '/unistd/a #include <sys/sysmacros.h>' gl/lib/mountlist.c
echo "#define _IO_IN_BACKUP 0x100" >> gl/lib/stdio-impl.h
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf findutils-4.6.0

echo "# 5.23. Gawk-5.0.0"
tar -Jxf gawk-5.0.0.tar.xz
cd gawk-5.0.0
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf gawk-5.0.0

echo "# 5.24. Gettext-0.19.8.1"
tar -Jxf gettext-0.19.8.1.tar.xz
cd gettext-0.19.8.1
cd gettext-tools
EMACS="no" ./configure --prefix=/tools --disable-shared
make -C gnulib-lib
make -C intl pluralx.c
make -C src msgfmt
make -C src msgmerge
make -C src xgettext
cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin
cd $LFS/sources
rm -rf gettext-0.19.8.1

echo "# 5.25. Grep-3.3"
tar -Jxf grep-3.3.tar.xz
cd grep-3.3
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf grep-3.3

echo "# 5.26. Gzip-1.10"
tar -Jxf gzip-1.10.tar.xz
cd gzip-1.10
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf gzip-1.10

echo "# 5.27. Make-4.2.1"
tar -jxf make-4.2.1.tar.bz2
cd make-4.2.1
sed -i '211,217 d; 219,229 d; 232 d' glob/glob.c
./configure --prefix=/tools --without-guile
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf make-4.2.1

echo "# 5.28. Patch-2.7.6"
tar -Jxf patch-2.7.6.tar.xz
cd patch-2.7.6
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf patch-2.7.6

echo "# 5.29. Perl-5.28.2"
tar -Jxf perl-5.28.2.tar.xz
cd perl-5.28.2
sh Configure -des -Dprefix=/tools -Dlibs=-lm -Uloclibpth -Ulocincpth
make -j $PARALLEL_JOBS
cp -v perl cpan/podlators/scripts/pod2man /tools/bin
mkdir -pv /tools/lib/perl5/5.28.2
cp -Rv lib/* /tools/lib/perl5/5.28.2
cd $LFS/sources
rm -rf perl-5.28.2

echo "# 5.30. Python-3.7.3"
tar -Jxf Python-3.7.3.tar.xz
cd Python-3.7.3
sed -i '/def add_multiarch_paths/a \        return' setup.py
./configure --prefix=/tools --without-ensurepip
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf Python-3.7.3

echo "# 5.31. Sed-4.7"
tar -Jxf sed-4.7.tar.xz
cd sed-4.7
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf sed-4.7

echo "# 5.32. Tar-1.32"
tar -Jxf tar-1.32.tar.xz
cd tar-1.32
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf tar-1.32

echo "# 5.33. Texinfo-6.6"
tar -Jxf texinfo-6.6.tar.xz
cd texinfo-6.6
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf texinfo-6.6

echo "# 5.34. Xz-5.2.4"
tar -Jxf xz-5.2.4.tar.xz
cd xz-5.2.4
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf xz-5.2.4

do_strip

echo -e "----------------------------------------------------"
echo -e "\nYou made it! This is the end of chapter 5!"
printf 'Total script time: %s\n' $(timer $total_time)
echo -e "Now continue reading from \"5.36. Changing Ownership\""
