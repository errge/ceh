package Packages::Emacs;

use strict;
use warnings;
use CehBase;
use CehInstall;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw($ceh_nix_install_root);

ceh_nixpkgs_install_bin("emacs", nixpkgs_version => 'db12d783ffd753145119c22a34ca5945e9a7a4ce', derivation => 'zbqn8fy2lc6gnq99vgjq2q198x1plfb0-emacs-24.3.drv', out => 'imz1mpv7yzi7b21ap862zajfq6z5hv5l-emacs-24.3');

1;
