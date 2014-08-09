package Packages::TWS;

use strict;
use warnings;
use CehBase;
use CehInstall;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw($ceh_nix_install_root);

$ENV{NIXPKGS_CONFIG}='/opt/ceh/lib/Packages/TWS.nix';
ceh_nixpkgs_install("tws", nixpkgs_version => 'f666bf4ddf3f5f50cad6e17907dae53d545444d0', out => 'zjf974731db77z8rbvgbnx832v68a53b-tws-20130809');

1;
