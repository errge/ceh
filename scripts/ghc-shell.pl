#!/opt/ceh/lib/perl
# -*- mode: perl; -*-

use strict;
use warnings;
use lib "/opt/ceh/lib";
use Packages::GHC;

exec "/bin/bash", @ARGV;
