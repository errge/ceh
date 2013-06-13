# Used by bin/tws-*

{
  packageOverrides = pkgs:
    {
      tws = pkgs.callPackage (
      	{stdenv, fetchurl, unzip, jre}: stdenv.mkDerivation rec {
	name = "tws-937";

	jts = fetchurl {
	  url = "http://download2.interactivebrokers.com/java/classes/jts.937.jar";
	  sha256 = "1w0ln9micg1vg0p22fhnmb8yknqdi1nqxd5sz7pm1g69aag42k9x";
	};

	total = fetchurl {
	  url = "http://download2.interactivebrokers.com/java/classes/total.2012.jar";
	  sha256 = "0a862rzjzdakyv9jvmb1rnmmagbzim57g7361sy2rnqpywpyg9ls";
	};

	jre = pkgs.jre;
	buildInputs = [ unzip jre ];

	unpackPhase = ''
	  ensureDir $out/share/tws-jars
	  cp $jts $out/share/tws-jars/jts.jar
	  cp $total $out/share/tws-jars/total.jar
	'';

	installPhase = ''
	  ensureDir $out/bin
	  cat >$out/bin/tws-ui <<EOF
#!/bin/sh

TZ=America/New_York \
exec $jre/bin/java -cp $out/share/tws-jars/total.jar:$out/share/tws-jars/jts.jar -Xmx2000m -XX:MaxPermSize=512m jclient.LoginFrame /opt/ceh/home/Jts
EOF
	  chmod a+x $out/bin/tws-ui
	'';

	}) { };
    };
}
