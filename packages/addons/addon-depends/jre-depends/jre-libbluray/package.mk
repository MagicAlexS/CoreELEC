# SPDX-License-Identifier: GPL-2.0
# Copyright (C) 2019-present Team LibreELEC (https://libreelec.tv)

# The main libbluray build now provides both matching BD-J jars.
PKG_NAME="jre-libbluray"
PKG_VERSION="1.5.0"
PKG_LICENSE="LGPL"
PKG_DEPENDS_TARGET="libbluray"
PKG_LONGDESC="Matching libbluray Java implementation for the JRE addon"
PKG_TOOLCHAIN="manual"

makeinstall_target() {
  mkdir -p "${INSTALL}/usr/share/java"
  cp "$(get_install_dir libbluray)"/usr/share/java/*.jar "${INSTALL}/usr/share/java/"
}
