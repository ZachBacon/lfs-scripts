#!/bin/bash
#
# PiLFS Build Script SVN-20191205 v1.0
# Builds Weston
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
libpng-1.6.37.tar.xz
libpng-1.6.37-apng.patch.gz
libuv-v1.34.0.tar.gz
libjpeg-turbo-2.0.3.tar.gz
pixman-0.38.4.tar.gz
glib-2.62.3.tar.xz
glib-2.62.3-skip_warnings-1.patch
libxml2-2.9.10.tar.gz
freetype-2.10.1.tar.xz
fontconfig-2.13.1.tar.bz2
libdrm-2.4.100.tar.bz2
wayland-1.17.0.tar.xz
wayland-protocols-1.18.tar.xz
MarkupSafe-1.1.1.tar.gz
Mako-1.1.0.tar.gz
mesa-19.3.0.tar.xz
cairo-1.17.2+f93fc72c03e.tar.xz
mtdev-1.1.5.tar.bz2
xkeyboard-config-2.28.tar.bz2
libxkbcommon-0.9.1.tar.xz
libevdev-1.8.0.tar.xz
libinput-1.14.3.tar.xz
weston-7.0.0.tar.xz
dejavu-fonts-ttf-2.37.tar.bz2
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

echo "# Moving on to /usr/src"
cd /usr/src

echo "# libpng-1.6.37"
tar -Jxf libpng-1.6.37.tar.xz
cd libpng-1.6.37
gzip -cd ../libpng-1.6.37-apng.patch.gz | patch -p1
./configure --prefix=/usr --disable-static
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf libpng-1.6.37

echo "# libuv-1.34.0"
tar -zxf libuv-v1.34.0.tar.gz
cd libuv-v1.34.0
sh autogen.sh
./configure --prefix=/usr --disable-static
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf libuv-v1.34.0

echo "# libarchive-3.4.0"
tar -zxf libarchive-3.4.0.tar.gz
cd libarchive-3.4.0
./configure --prefix=/usr --disable-static
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf libarchive-3.4.0

echo "# CMake-3.16.1"
tar -zxf cmake-3.16.1.tar.gz
cd cmake-3.16.1
sed -i '/"lib64"/s/64//' Modules/GNUInstallDirs.cmake
./bootstrap --prefix=/usr        \
            --system-libs        \
            --mandir=/share/man  \
            --no-system-jsoncpp  \
            --no-system-librhash \
            --docdir=/share/doc/cmake-3.16.1
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf cmake-3.16.1

echo "# libjpeg-turbo-2.0.3"
tar -zxf libjpeg-turbo-2.0.3.tar.gz
cd libjpeg-turbo-2.0.3
mkdir build
cd build
cmake -DCMAKE_INSTALL_PREFIX=/usr \
      -DCMAKE_BUILD_TYPE=RELEASE  \
      -DENABLE_STATIC=FALSE       \
      -DCMAKE_INSTALL_DOCDIR=/usr/share/doc/libjpeg-turbo-2.0.3 \
      -DCMAKE_INSTALL_DEFAULT_LIBDIR=lib  \
      ..
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf libjpeg-turbo-2.0.3

echo "# Pixman-0.38.4"
tar -zxf pixman-0.38.4.tar.gz
cd pixman-0.38.4
mkdir build
cd build
meson --prefix=/usr
ninja
ninja install
cd /usr/src
rm -rf pixman-0.38.4

echo "# GLib-2.62.3"
tar -Jxf glib-2.62.3.tar.xz
cd glib-2.62.3
patch -Np1 -i ../glib-2.62.3-skip_warnings-1.patch
mkdir build
cd build
meson --prefix=/usr      \
      -Dman=false        \
      -Dselinux=disabled \
      ..
ninja
ninja install
cd /usr/src
rm -rf glib-2.62.3

echo "# libxml2-2.9.10"
tar -zxf libxml2-2.9.10.tar.gz
cd libxml2-2.9.10
./configure --prefix=/usr    \
            --disable-static \
            --with-history   \
            --with-python=/usr/bin/python3
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf libxml2-2.9.10

echo "# FreeType-2.10.1"
tar -Jxf freetype-2.10.1.tar.xz
cd freetype-2.10.1
sed -ri "s:.*(AUX_MODULES.*valid):\1:" modules.cfg
sed -r "s:.*(#.*SUBPIXEL_RENDERING) .*:\1:" -i include/freetype/config/ftoption.h
./configure --prefix=/usr --enable-freetype-config --disable-static
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf freetype-2.10.1

echo "# Fontconfig-2.13.1"
tar -jxf fontconfig-2.13.1.tar.bz2
cd fontconfig-2.13.1
rm -f src/fcobjshash.h
./configure --prefix=/usr        \
            --sysconfdir=/etc    \
            --localstatedir=/var \
            --disable-docs       \
            --docdir=/usr/share/doc/fontconfig-2.13.1
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf fontconfig-2.13.1

echo "# libdrm-2.4.100"
tar -jxf libdrm-2.4.100.tar.bz2
cd libdrm-2.4.100
mkdir build
cd build
meson --prefix=/usr -Dudev=true
ninja
ninja install
cd /usr/src
rm -rf libdrm-2.4.100

echo "# Wayland-1.17.0"
tar -Jxf wayland-1.17.0.tar.xz
cd wayland-1.17.0
./configure --prefix=/usr    \
            --disable-static \
            --disable-documentation
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf wayland-1.17.0

echo "# Wayland-Protocols-1.18"
tar -Jxf wayland-protocols-1.18.tar.xz
cd wayland-protocols-1.18
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf wayland-protocols-1.18

echo "# MarkupSafe-1.1.1"
tar -zxf MarkupSafe-1.1.1.tar.gz
cd MarkupSafe-1.1.1
python3 setup.py build
python3 setup.py install --optimize=1
cd /usr/src
rm -rf MarkupSafe-1.1.1

echo "# Mako-1.1.0"
tar -zxf Mako-1.1.0.tar.gz
cd Mako-1.1.0
python3 setup.py install --optimize=1
cd /usr/src
rm -rf Mako-1.1.0

echo "# Mesa-19.3.0"
tar -Jxf mesa-19.3.0.tar.xz
cd mesa-19.3.0
mkdir build
cd build
meson --prefix=/usr                     \
      --sysconfdir=/etc                 \
      -Dbuildtype=release               \
      -Dplatforms="drm,wayland"         \
      -Ddri-drivers=""                  \
      -Dgallium-drivers="vc4,v3d,kmsro" \
      -Dglx=disabled                    \
      ..
ninja
ninja install
cd /usr/src
rm -rf mesa-19.3.0

echo "# Cairo-1.17.2+f93fc72c03e"
tar -jxf cairo-1.17.2+f93fc72c03e.tar.xz
cd cairo-1.17.2+f93fc72c03e
./configure --prefix=/usr    \
            --disable-static \
            --enable-tee     \
            --enable-glesv2  \
            --enable-egl
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf cairo-1.17.2+f93fc72c03e

echo "# mtdev-1.1.5"
tar -jxf mtdev-1.1.5.tar.bz2
cd mtdev-1.1.5
./configure --prefix=/usr --disable-static
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf mtdev-1.1.5

echo "# XKeyboardConfig-2.28"
tar -jxf xkeyboard-config-2.28.tar.bz2
cd xkeyboard-config-2.28
./configure --prefix=/usr --disable-runtime-deps
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf xkeyboard-config-2.28

echo "# libxkbcommon-0.9.1"
tar -Jxf libxkbcommon-0.9.1.tar.xz
cd libxkbcommon-0.9.1
mkdir build
cd build
meson --prefix=/usr -Denable-docs=false -Denable-x11=false ..
ninja
ninja install
cd /usr/src
rm -rf libxkbcommon-0.9.1

echo "# libevdev-1.8.0"
tar -Jxf libevdev-1.8.0.tar.xz
cd libevdev-1.8.0
./configure --prefix=/usr
make -j $PARALLEL_JOBS
make install
cd /usr/src
rm -rf libevdev-1.8.0

echo "# libinput-1.14.3"
tar -Jxf libinput-1.14.3.tar.xz
cd libinput-1.14.3
mkdir build
cd build
meson --prefix=/usr         \
      -Dudev-dir=/lib/udev  \
      -Ddocumentation=false \
      -Dlibwacom=false      \
      -Ddebug-gui=false     \
      -Dtests=false         \
      ..
ninja
ninja install
udevadm hwdb --update
cd /usr/src
rm -rf libinput-1.14.3

echo "# weston-7.0.0"
tar -Jxf weston-7.0.0.tar.xz
cd weston-7.0.0
mkdir build
cd build
meson --prefix=/usr                        \
      -Dbuildtype=release                  \
      -Dxwayland=false                     \
      -Dbackend-x11=false                  \
      -Dweston-launch=false                \
      -Dimage-webp=false                   \
      -Dlauncher-logind=false              \
      -Dbackend-drm-screencast-vaapi=false \
      -Dbackend-rdp=false                  \
      -Dcolor-management-colord=false      \
      -Dcolor-management-lcms=false        \
      -Dsystemd=false                      \
      -Dremoting=false                     \
      -Dsimple-dmabuf-drm=auto             \
      -Ddemo-clients=false                 \
      -Dpipewire=false                     \
      ..
ninja
ninja install
echo "/run/shm/wayland dir 1700 root root" >> /etc/sysconfig/createfiles
echo "export XDG_RUNTIME_DIR=/run/shm/wayland" >> ~/.profile
cd /usr/src
rm -rf weston-7.0.0

echo "# dejavu-fonts-ttf-2.37"
tar -jxf dejavu-fonts-ttf-2.37.tar.bz2
cd dejavu-fonts-ttf-2.37
install -v -d -m755 /usr/share/fonts/dejavu
install -v -m644 ttf/*.ttf /usr/share/fonts/dejavu
fc-cache /usr/share/fonts/dejavu
cd /usr/src
rm -rf dejavu-fonts-ttf-2.37

echo -e "--------------------------------------------------------------------"
printf 'Total script time: %s\n' $(timer $total_time)
