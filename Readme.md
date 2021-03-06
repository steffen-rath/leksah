# Leksah, an Integrated Development Environment for Haskell

[![Build Status](https://secure.travis-ci.org/leksah/leksah.png)](http://travis-ci.org/leksah/leksah)
[![Hackage](https://img.shields.io/hackage/v/leksah.svg)](#installing-from-hackage)

[Leksah](http://leksah.org/) aims to integrate various Haskell development
tools to provide a practical and pleasant development environment.
The user interface is a mix of GTK+ and WebKit based components.

Documentation can be found on [leksah.org](http://leksah.org/).

## Getting Leksah
Leksah requires you have **ghc >= 7.10.3** and **cabal-install >= 1.24** installed

* **Windows** and **OS X**: [official binaries](https://github.com/leksah/leksah/wiki/download).
* **Linux**: [Install from Hackage](https://github.com/leksah/leksah#installing-from-hackage)

## Installing from Hackage

These instructions require GHC 7.10 (or older).  If you have GHC 8.0 please the current hackage version of leksah will not build.  For GHC 8.0 please build leksah [from github source](https://github.com/leksah/leksah#building-from-source). 

### Building on Linux



Install the GtkSourceView and WebKitGtk development packages for your distribution:

    sudo apt-get install libgtksourceview-3.0-dev libwebkitgtk-3.0-dev

Arch Linux
    sudo pacman -S webkitgtk gtksourceview3

Make sure `$HOME/.cabal/bin` is in your `PATH` then:
    
    cabal update
    cabal install Cabal cabal-install
    cabal install alex happy
    cabal install gtk2hs-buildtools
    cabal install leksah
    leksah

### Building on OS X

[Install MacPorts](https://www.macports.org/install.php).

Make sure `/opt/local/bin` and `$HOME/Libraries/Haskell/bin` are in your `PATH`.

To avoid a dependency on X11 add the following to `/opt/local/etc/macports/variants.conf`:

    -x11 +no_x11 +quartz +gtk3

Use MacPorts to install `python27` and `rsync` (sometimes it stops to ask for these to be
activated so if you do them first it might help):

    sudo port install python27 rsync

Use MacPorts to install GHC and the C libraries needed by Leksah (this will take a long time):
     
    sudo port install ghc gtk3 webkit-gtk3 gtksourceview3 gtk-osx-application-gtk3 adwaita-icon-theme

Update Cabal and cabal-install

	cabal update
	cabal install Cabal cabal-install

Make sure the right `cabal` made it into your `PATH`.

    cabal --version

Check that the versions match the ones you just installed (if not check the symbolic links in
`$HOME/Libraries/Haskell/bin`).

Install `gtk2hs-buildtools` and `leksah`:

    cabal install regex-tdfa-text --ghc-options=-XFlexibleContexts
    cabal install alex happy
    cabal install gtk2hs-buildtools
    cabal install leksah
    leksah

### Building on Windows

Install [GHC](https://www.haskell.org/downloads/windows).

Update MinGW if necessary.  The GHC installers currently come with old versions of
MinGW and you will probably need to replace it with one that comes with gcc 4.8.1.
The current 64bit GHC installer seems to be happy to work with newer MinGW.
It may not be possible to use the current 32bit GHC installers at all.
Make sure you replace MinGW so that GHC will find the new one (just adding
it to the `PATH` will not work). The MinGW used by GHC is typically in a location
like `C:\Program Files\MinGHC-7.10.1\ghc-7.10.1\mingw`.  Move it out of the way
and put a newer one in its place.

[MinGW version used to build the Leksah binaries](http://sourceforge.net/projects/mingw-w64/files/Toolchains%20targetting%20Win64/Personal%20Builds/mingw-builds/4.9.2/threads-posix/seh/x86_64-4.9.2-release-posix-seh-rt_v4-rev2.7z)

Install the C libraries needed by Leksah.  The easiest way to do this is to install
Leksah using the MSI files.  They include pkg-config and all the C libraries needed.

Make sure `C:\Leksah\bin` and `%APPDATA%\cabal\bin` are in your `PATH` and build:

    cabal update
    cabal install Cabal
    cabal install alex happy
    cabal install gtk2hs-buildtools
    cabal install leksah
    leksah
   
## Building from source

Requirements: ghc >= **7.10.3**, cabal-install >= **1.24**

We have just completed a port of Leksah from Gtk2Hs to haskell-gi.  Not all
of the code is in Hackage yet so to build it you can either use [Xobl](xobl/Readme.md)
or follow the instructions below.

**Step 1**. Install the following C libraries (for Windows and OS X, see the Hackage build instructions)

###### Fedora
`sudo dnf install gobject-introspection-devel webkitgtk3-devel gtksourceview3-devel`

###### Ubuntu
`sudo apt-get install libgirepository1.0-dev libwebkitgtk-3.0-dev libgtksourceview-3.0-dev`

###### Arch Linux
`sudo pacman -S gobject-introspection gobject-introspection-runtime gtksourceview3 webkitgtk`

###### OS X MacPorts
`sudo port install gobject-introspection webkit-gtk3-devel gtksourceview3`

You will also need to build a MacPorts compatible of GHC.  First install GHC some other way then unpack the source for the GHC version you want to use and run:

    sudo port install libxslt gmp ncurses libiconv llvm-3.5 libffi
    ./configure --prefix=$HOME/ghc-8.0.1 --with-iconv-includes=/opt/local/include --with-iconv-libraries=/opt/local/lib --with-gmp-includes=/opt/local/include --with-gmp-libraries=/opt/local/lib --with-system-libffi --with-ffi-includes=/opt/local/lib/libffi-3.2.1/include --with-ffi-libraries=/opt/local/lib --with-nm=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/nm-classic
    make
    make install

Then make sure the $HOME/ghc-8.0.1 is in your $PATH.

###### OS X Homebrew
Homebrew Does not have WebKitGTK 2.4.x (newer versions of WebKitGTK only have WebKit 2 interface)

###### Windows MSYS2
Install [MSYS2](https://msys2.github.io/) and [Chocolatey](https://chocolatey.org/).  Then in a shell with administrator privileges:

    choco install ghc
    pacman -S mingw64/mingw-w64-x86_64-pkg-config mingw64/mingw-w64-x86_64-gobject-introspection mingw64/mingw-w64-x86_64-gtksourceview3 mingw64/mingw-w64-x86_64-webkitgtk3


**Step 2**: Install tools

    cabal update
    cabal install alex happy
    cabal install haskell-gi

(make sure `~/.cabal/bin` is in PATH)

**Step 3**: Clone the repo

    git clone --recursive https://github.com/leksah/leksah.git
    cd leksah

**Step 4**: Build and Run Leksah

    ./leksah.sh
    
(the Cabal library has to be installed seperately because of a [cabal bug](https://github.com/haskell/cabal/issues/3436))

On OS X using MacPorts you may need to set `XDG_DATA_DIRS` like this:

    XDG_DATA_DIRS=/opt/local/share cabal new-build exe:leksah-server exe:leksah

#### Using `stack build` instead of `cabal new-build`

** NOTE : This is currently not working.  If you can make it work let us know. **

Do **Step 1** and **Step 2** as above, then

**Step 4**: Install Leksah

    cabal install gtk2hs-buildtools
    cabal install ./vendor/haskell-gi ./vendor/haskell-gi-base
    stack build

**Step 5**: Run leksah

    **TODO add path to path to leksah executable**

### Building Leksah for Windows using Docker

It may seem crazy, but this is currently the best way to bootstrap Leksah for
Windows from source.  This is mostly because Fedora and SUSE have a much
more complete set of MinGW packages than any thing else (including Windows).

Get the leksah source:

    git clone https://github.com/leksah/leksah
    cd leksah
    git submodule update --init

Get the Fedora 23 docker image and load it:

    wget https://download.fedoraproject.org/pub/fedora/linux/releases/23/Docker/x86_64/Fedora-Docker-Base-23-20151030.x86_64.tar.xz
    sudo docker load -i Fedora-Docker-Base-23-20151030.x86_64.tar.xz

Build Leksah using the Dockerfile:

    sudo docker build -t leksah/build .

Copy the resulting msi file out of the container (version number in the file name will match the one in the leksah.cabal file):

    sudo docker run --rm --volume $HOME/output:/output leksah/build cp /leksah/win32/leksah-0.16.0.0-ghc-7.10.3.msi /output
