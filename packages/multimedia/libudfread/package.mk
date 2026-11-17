# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2020-present Team LibreELEC (https://libreelec.tv)

PKG_NAME="libudfread"
PKG_VERSION="1.2.0"
PKG_SHA256="bb477cbd4cfbfc7787d9d05b71ee5e70430f5cfebf1297497f7e83547958050f"
PKG_LICENSE="LGPLv2.1"
PKG_SITE="https://code.videolan.org/videolan/libudfread"
PKG_URL="https://download.videolan.org/pub/videolan/libudfread/${PKG_NAME}-${PKG_VERSION}.tar.xz"
PKG_DEPENDS_TARGET="toolchain"
PKG_LONGDESC="UDF reader"
PKG_TOOLCHAIN="meson"
PKG_BUILD_FLAGS="+pic"
PKG_MESON_OPTS_TARGET="-Ddefault_library=static -Denable_examples=false"
