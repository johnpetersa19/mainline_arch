# Maintainer: john peter sa <johnppetersa@gmail.com>

pkgname=mainline-arch
pkgver=1.5.1
pkgrel=1
pkgdesc="Tool to install and manage mainline kernels from the Arch Linux Archive"
arch=('x86_64')
url="https://github.com/johnpetersa19/mainline_arch"
license=('GPL3')

depends=('gtk4' 'libadwaita' 'vte3' 'json-glib' 'libgee' 'aria2' 'libsoup3' 'libx11')
makedepends=('meson' 'ninja' 'vala')

conflicts=('mainline')

source=("${pkgname}-${pkgver}.tar.gz::${url}/archive/refs/tags/${pkgver}.tar.gz")
sha256sums=('ba838194e99e75d6ac05fd62a1632712ee548bba6607b71ebd20fd1d4429f4fa')

build() {
  cd "${srcdir}/mainline_arch-${pkgver}"

  meson setup build --prefix=/usr --buildtype=release
  meson compile -C build
}

package() {
  cd "${srcdir}/mainline_arch-${pkgver}"

  DESTDIR="${pkgdir}" meson install -C build
}