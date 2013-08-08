# Used by bin/firefox.

{
  packageOverrides = pkgs:
    {
      firefoxCeh = pkgs.callPackage (
        { stdenv, fetchurl, gtk, pango, perl, python, zip
        , libjpeg, libpng, zlib, dbus, dbus_glib, xlibs
        , freetype, fontconfig, alsaLib, alsaPlugins, nspr
        , nss, libnotify, mesa, sqlite
        , hunspell, libevent, libstartup_notification, libvpx
        , cairo, glib, atk, gdk_pixbuf, linuxPackages, mesa_drivers
        , flashplayer, google_talk_plugin, jrePlugin }: stdenv.mkDerivation rec {
        name = "firefox-ceh";

        builder = ./firefox-builder.sh;

        src = fetchurl {
          url = "https://download.mozilla.org/?product=firefox-23.0&os=linux&lang=en-US";
          name = "firefox.tar.bz2";
          sha256 = "11an1ymqyahjpsgmnywsxxlq3w8i89lmiz92kw1kvbf0m3sihcss";
        };

        flashplayer_path = flashplayer;
        google_talk_plugin_path = google_talk_plugin;
        jre_path = jrePlugin;
        alsa_path = alsaPlugins;
        nvidia_path = linuxPackages.nvidia_x11;
        mesa_path = mesa_drivers;

        libPath = stdenv.lib.makeLibraryPath
          [ stdenv.gcc.gcc libpng gtk libjpeg zlib
            dbus dbus_glib pango freetype fontconfig xlibs.libXi
            xlibs.libX11 xlibs.libXrender xlibs.libXft xlibs.libXt
            alsaLib alsaPlugins nspr nss libnotify xlibs.pixman mesa
            xlibs.libXScrnSaver xlibs.scrnsaverproto stdenv.glibc
            xlibs.libXext xlibs.xextproto sqlite
            hunspell libevent libstartup_notification libvpx
            cairo glib atk gdk_pixbuf linuxPackages.nvidia_x11
            mesa_drivers
            ];
        }) { };
    };
}
