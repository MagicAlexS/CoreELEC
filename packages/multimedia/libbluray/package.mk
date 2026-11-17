# SPDX-License-Identifier: GPL-2.0-or-later
# Copyright (C) 2009-2016 Stephan Raue (stephan@openelec.tv)
# Copyright (C) 2018-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="libbluray"
PKG_VERSION="1.5.0"
PKG_SHA256="f676408e91a5d321abf8b8d4dfdae36205c297dab5c54c3ec519639025f474a2"
PKG_LICENSE="LGPL"
PKG_SITE="https://www.videolan.org/developers/libbluray.html"
PKG_URL="https://download.videolan.org/pub/videolan/libbluray/${PKG_VERSION}/${PKG_NAME}-${PKG_VERSION}.tar.xz"
PKG_DEPENDS_TARGET="toolchain fontconfig freetype libxml2 libudfread apache-ant:host"
PKG_DEPENDS_UNPACK="jdk-${MACHINE_HARDWARE_NAME}-zulu"
PKG_LONGDESC="Blu-ray navigation and BD-J support, with matching Java implementation."
PKG_TOOLCHAIN="meson"

if [ "${BLURAY_AACS_SUPPORT}" = "yes" ]; then
  PKG_DEPENDS_TARGET+=" libaacs"
fi
if [ "${BLURAY_BDPLUS_SUPPORT}" = "yes" ]; then
  PKG_DEPENDS_TARGET+=" libbdplus"
fi

PKG_MESON_OPTS_TARGET="-Denable_docs=false
                       -Denable_tools=false
                       -Denable_examples=false
                       -Dbdj_jar=enabled
                       -Dfontconfig=enabled
                       -Dfreetype=enabled
                       -Dlibxml2=enabled"

pre_configure_target() {
  export JAVA_HOME="$(get_build_dir jdk-${MACHINE_HARDWARE_NAME}-zulu)"
  export PATH="${JAVA_HOME}/bin:${PATH}"
}
