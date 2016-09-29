#!/bin/bash -e
#set -xv

BASHRC='/etc/bashrc'
USER="user"
export BROWSEINSTALL=1

VERSION="9.3.6"
PACKAGE="browse"
TARBALL="${PACKAGE}_src-linux.tgz"

TMPDIR="/tmp/browse"

INSTALLDIR="/usr/local/browse"
BUILDDIR="${INSTALLDIR}/BUILD_DIR"

DBASE="/dbase"

function download() {
  return 1
}

function unpack() {
  [ -z "$1" ] && return 1 || PKG="$1"
  tar -xzf "$PKG" --strip-components=1
}

function fix_liblinks() {
  [ -z "$HEADAS" ] && return 1
  cd "${HEADAS}/lib"
  ln -sf libtcl8.*.so libtcl.so && \
  ln -sf libtk8.*.so libtk.so && \
  ln -sf libwcs-*.so libwcs.so && \
  ln -sf libxanlib_*.so libxanlib.so && \
  ln -sf libhdio_*.so libhdio.so && \
  ln -sf libcfitsio.*.so libcfitsio.so && \
  ln -sf libape_*.so libape.so && \
  ln -sf libhdutils_*.so libhdutils.so && \
  ln -sf libhdinit_*.so libhdinit.so && \
  ln -sf libcaltools_*.so libcaltools.so && \
  ln -sf libcftools_*.so libcftools.so && \
  ln -sf libftools_*.so libftools.so && \
  ln -sf libpgplot5.*.so libpgplot.so
  sts="$?"
  cd -
  return $sts
}

function install_dependencies() {
  echo "Browse step: installing dependencies.."
  (. ${TMPDIR}/install_heasoft.sh && install_dependencies)
  yum -y install compat-gcc-34-g77 which
  yum clean all
  echo "..dependencies installed."
}

function build() {
  echo "Browse step: building browse.."
  ./configure > ${TMPDIR}/config.out  && \
      hmake > ${TMPDIR}/build.out  && \
      hmake install > ${TMPDIR}/install.out 
  [ "$?" != "0" ] && return 1
  BROWSEINIT="${PWD}/browse-init.sh"
  sed -i "/XUSER_0/c\export $USER=XUSER_0" $BROWSEINIT
  sed -i '/XUSER_1/c\export root=XUSER_1' $BROWSEINIT
  sed -i '/youruser3/c\ ' $BROWSEINIT
  LIBC=$(ldd --version | head -n1 | awk '{print $NF}')
  echo "export BROWSE=${INSTALLDIR}/x86_64-unknown-linux-gnu-libc${LIBC}" >> $BASHRC
  echo "source ${BROWSEINIT}" >> $BASHRC
  echo "..browse built."
}

function dbase() {
  echo "Browse step: setting up caldb.."
  [ ! -d "$DBASE" ] && mkdir -p "$DBASE"
  echo "export DBASE=$DBASE" >> $BASHRC
  tar xzf ${TMPDIR}/browse-dbase_empty.tar.gz -C $DBASE
  echo "..dbase is setup."
}

function main() {
  source $BASHRC

  echo "Browse: configuring browse.."
  install_dependencies
 
  CC=$(which gcc)
  CXX=$(which g++)
  FC=$(which g77)
  PERL=$(which perl)
  PYTHON=$(which python)
  export CC CXX FC PERL PYTHON

  if [ ! `which fhelp` ]
  then
      (. ${TMPDIR}/install_heasoft.sh && main)
      source $BASHRC
  fi
  [ `which fhelp` ] || { echo "HEASoft is not installed. Solve that." ; exit 1 ; }
  fix_liblinks

  INITDIR=$PWD
  [ ! -d "$TMPDIR" ] && mkdir $TMPDIR
  cd $TMPDIR && echo "Entering in $TMPDIR"
  [ -f "$TARBALL" ] && echo "$TARBALL found" || download
  [ "$?" = "0" ] || exit 1

  [ ! -d "$INSTALLDIR" ] && mkdir $INSTALLDIR
  cd $INSTALLDIR && echo "Entering in $INSTALLDIR"
  unpack ${TMPDIR}/${TARBALL}
  [ "$?" = "0" ] || exit 1

  cd $BUILDDIR && echo "Entering in $BUILDDIR"
  env > ${TMPDIR}/build_environment.out
  build && dbase

  echo "Looks like browse setup worked like a charm ;)"
  echo "Finished."
  cd $INITDIR
}
