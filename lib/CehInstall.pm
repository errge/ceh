package CehInstall;

use strict;
use warnings;
use File::Basename qw(dirname);
use File::Path qw(make_path rmtree);
use Carp;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT = qw(AUTOINIT ceh_nixpkgs_checkout ceh_nixpkgs_install ceh_nixpkgs_install_bin ceh_nixpkgs_install_for_ghc ceh_nixpkgs_install_tools ceh_nixpkgs_install_ghctools $ceh_nix_install_root);

use CehBase;
use Cache;
use Replacer;

# So we don't accidentally use git from ceh and go into an infinite loop
our $git='/usr/bin/git';

# Return variables
our $ceh_nix_install_root = '';

sub AUTOINIT() {
    return autoinit => "1";
}

# Creates a bare http://github.com/nixos/nixpkgs clone at
# $CEH_NIXPKGS_GIT/git.
sub ceh_nixpkgs_clone() {
    if (not done("$CEH_NIXPKGS_GIT/git")) {
	debug "Cloning the nixpkgs repository from github...";
	rmtree("$CEH_NIXPKGS_GIT/git");
	not -e "$CEH_NIXPKGS_GIT/git" or croak;
	make_path("$CEH_NIXPKGS_GIT/git") or croak;
	systemdie($git, qw(clone --bare), $CEH_NIXPKGS_GITURL, "$CEH_NIXPKGS_GIT/git");
	touch "$CEH_NIXPKGS_GIT/git.done";
    }
    debug "Updating the nixpkgs repository from github...";
    systemdie("cd $CEH_NIXPKGS_GIT/git && $git fetch origin master:master");
}

# Downloads and initializes a specific nixpkgs version into the
# $CEH_NIXPKGS_GIT/1, so it can be used for builds later.
#
# This is needed instead of simply using channels and the newest
# version only, because we want to reproduce specific blessed versions
# of binaries and not the newest version in nixpkgs.
#
# $1: the nixpkgs commit from https://github.com/NixOS/nixpkgs/commit
#
# It sets NIX_PATH up, so '<ceh_nixpkgs>' points to the initialized version.
sub ceh_nixpkgs_checkout($) {
    my $commit = shift;

    if (not done("$CEH_NIXPKGS_GIT/$commit")) {
	ceh_nixpkgs_clone();
	rmtree("$CEH_NIXPKGS_GIT/$commit");
	not -e "$CEH_NIXPKGS_GIT/$commit" or die;
	systemdie("$git", qw(clone -s -n), "$CEH_NIXPKGS_GIT/git", "$CEH_NIXPKGS_GIT/$commit");
	systemdie("cd $CEH_NIXPKGS_GIT/$commit && $git reset --hard $commit");
	touch("$CEH_NIXPKGS_GIT/$commit.done");
    }

    $ENV{NIX_PATH}="ceh_nixpkgs=$CEH_NIXPKGS_GIT/$commit";
}

# Used in wrapper scripts in bin/*.
#
# If $1 is an already installed package, returns immediately.
# Otherwise builds and installs it.  In case of success, sets
# ceh_nix_install_root to /nix/store/outhash, so it's easy to refer to
# the binaries in the wrapper scripts.
#
# Nix internally uses a binary cache, so may not necessarily build.
#
# There are three ways to call this function:
#  - without AUTOINIT and providing all four package properties:
#    - pkgattr (the name of the package from ceh_nixpkgs_avail),
#    - the nixpkgs_version,
#    - the derivation hash,
#    - the out path hash;
#  - with AUTOINIT and specifying two properties:
#    - specifying the pkgattr,
#    - specifying the nixpkgs_version,
#    - the derivation hash will be autoguessed,
#    - the out path hash will be autoguessed;
#  - with AUTOINIT and specifying one property:
#    - specifying the pkgattr,
#    - the nixpkgs_version will be the baseline,
#    - the derivation hash will be autoguessed,
#    - the out path hash will be autoguessed.
#
# In the latter two cases the autoguess results will be written back
# to the calling script by some Perl magic.  So on the second run, no
# autoguessing will be needed, because the call will be already
# rewritten to be in the first form.
#
# If the CEH_AUTO_UPGRADE envvar is set to 1, and all of the four
# arguments are specified, but the nixpkgs_version is outdated, then
# the package will be upgraded and the new nixpkgs_version, derivation
# hash and out path hash will be written to the calling script.
#
# $1: package name (attribute path),
# $2: target profile (e.g. /nix/var/nix/profiles/ceh/bin),
# %autoinit: autocomplete the function invocation with default values,
#    Example: ceh_nixpkgs_install_bin('git', AUTOINIT);
#      AUTOINIT will be replaced with correct values for
#      nixpkgs_version, derivation and out.
#    Example: ceh_nixpkgs_install_bin('git', nixpkgs_version => '3abc135', AUTOINIT);
#      AUTOINIT will be replaced with correct values for derivation
#      and out using the specified nixpkgs git commit.
# %nixpkgs_version: nixpkgs version to use
# %derivation: resulting derivation in /nix/store, excludes AUTOINIT
# %out: output path in /nix/store, excludes AUTOINIT
sub ceh_nixpkgs_install($$%) {
    my ($pkgattr, $profile, %opts) = @_;
    my $autoinit = $opts{autoinit};
    my $autoupgrade = 0;
    my $nixpkgs_version = $opts{nixpkgs_version};
    my $derivation = $opts{derivation};
    my $out = $opts{out};
    my $old_nixpkgs_version = $opts{nixpkgs_version};
    my $old_derivation = $opts{derivation};
    my $old_out = $opts{out};
    my $autoinit_nixpkgs_version = 0;
    my $autoinit_derivation = 0;
    my $autoinit_out = 0;

    # some sanity checks
    if ($nixpkgs_version) {
	if ($autoinit) {
	    croak "derivation supplied while AUTOINIT was enabled" if $derivation;
	    croak "out supplied while AUTOINIT was enabled" if $out;
	    $autoinit_derivation = $autoinit_out = 1;
	    debug "Ceh auto init mode!\n";
	} else {
	    croak "derivation is required, maybe wanted to use AUTOINIT?" if not $derivation;
	    croak "out is required, maybe wanted to use AUTOINIT?" if not $out;
	}
    } else {
	croak "no nixpkgs_version supplied, maybe you wanted to use AUTOINIT?" unless $autoinit;
	croak "derivation was provided while nixpkgs_version was not" if $derivation;
	croak "out was provided while nixpkgs_version was not" if $out;
	$autoinit_nixpkgs_version = $autoinit_derivation = $autoinit_out = 1;
    }

    ceh_nix_update_cache($profile);

    if ($ENV{CEH_AUTO_UPGRADE} and not $autoinit) {
	# if the baseline is so new that it's not currently fetched, fetch it
	`cd $CEH_NIXPKGS_GIT/git && $git rev-list --max-count=1 $CEH_BASELINE_NIXPKGS 2>/dev/null`;
	$? and ceh_nixpkgs_clone();
	my @revs = `cd $CEH_NIXPKGS_GIT/git && $git rev-list --max-count=1 $nixpkgs_version..$CEH_BASELINE_NIXPKGS`;
	$? and croak;
        if (@revs) {
	    debug "Ceh auto upgrade mode!";
            $autoupgrade = 1;
	    $out = "";
	    $derivation = "";
	    $nixpkgs_version = "";
	}
    }

    # debug "pkgattr: $pkgattr";
    # debug "profile: $profile";
    # debug "autoinit: $autoinit" if $autoinit;
    # debug "autoupgrade: $autoupgrade";
    # debug "nixpkgs_version: $nixpkgs_version" if $nixpkgs_version;
    # debug "derivation: $derivation" if $derivation;
    # debug "out: $out" if $out;

    # quick return if the package is already installed in the profile
    if ($out and -e "$profile/installed_derivations/$out") {
	$ceh_nix_install_root = "/nix/store/$out";
	return $ceh_nix_install_root;
    }

    if (not $nixpkgs_version) {
	$nixpkgs_version = $CEH_BASELINE_NIXPKGS;
	debug "*** Autoguessed nixpkgs version: $nixpkgs_version";
    }

    ceh_nixpkgs_checkout $nixpkgs_version;

    $_ = `$CEH_NIX/bin/nix-instantiate '<ceh_nixpkgs>' -A $pkgattr`;
    $? and croak;
    chomp;
    /^\/nix\/store\// or croak($_ . " not starting with /nix/store");
    s,/nix/store/,,;
    my $current_derivation = $_;
    if (not $derivation) {
	$derivation = $current_derivation;
	debug "*** Autoguessed derivation: $derivation";
    }
    ($derivation eq $current_derivation) or croak("derivation mismatch.  expected: $derivation, deducted: $current_derivation");

    # this hack is used by /opt/ceh/scripts/predict-binary-cache.sh
    if ($ENV{CEH_GATHER_DERIVATIONS_ONLY}) {
	debug "CEH_GATHER_DERIVATIONS_ONLY: /nix/store/$current_derivation\n";
	exit 0;
    }
    my @outs = `$CEH_NIX/bin/nix-store -q /nix/store/$current_derivation`;
    $? and croak;
    ($#outs == 0) or croak("nix-store -q didn't reply with exactly one out path");
    $_ = $outs[0];
    chomp;
    s,/nix/store/,,;
    my $current_out = $_;
    if (not $out) {
	$out = $current_out;
	debug "*** Autoguessed out: $out";
    }
    ($out eq $current_out) or croak("out mismatch.  expected: $out, deducted: $current_out");

    systemdie("$CEH_NIX/bin/nix-store --cores 0 -r /nix/store/$current_derivation >&2");
    if (not -d dirname($profile)) {
	make_path(dirname($profile)) or confess;
    }
    systemdie("$CEH_NIX/bin/nix-env -p $profile --cores 0 -i /nix/store/$out >&2");
    ceh_nix_update_cache($profile);

    if ($autoinit) {
	not $autoupgrade or croak("autoupgrade and autoinit at once?");
	debug "Doing autoinit!\n";
	replace_in_backtrace("AUTOINIT", qq{nixpkgs_version => '$nixpkgs_version', AUTOINIT}) if $autoinit_nixpkgs_version;
	replace_in_backtrace("AUTOINIT", qq{derivation => '$derivation', AUTOINIT}) if $autoinit_derivation;
	replace_in_backtrace("AUTOINIT", qq{out => '$out'}) if $autoinit_out;
    }

    if ($autoupgrade) {
	not $autoinit or croak("autoupgrade and autoinit at once?");
	debug "Doing autoupgrade!\n";

	replace_in_backtrace("'$old_nixpkgs_version'", "'$nixpkgs_version'");
	replace_in_backtrace(qq{"$old_nixpkgs_version"}, qq{"$nixpkgs_version"});

	replace_in_backtrace("'$old_derivation'", "'$derivation'");
	replace_in_backtrace(qq{"$old_derivation"}, qq{"$derivation"});

	replace_in_backtrace("'$old_out'", "'$out'");
	replace_in_backtrace(qq{"$old_out"}, qq{"$out"});
    }

    $ceh_nix_install_root = "/nix/store/$out";
    return $ceh_nix_install_root;
}

# This is the main profile for ceh executables (wrappers in /opt/ceh/bin).
sub ceh_nixpkgs_install_bin {
    my ($pkgattr, %opts) = @_;
    return ceh_nixpkgs_install($pkgattr, "/nix/var/nix/profiles/ceh/bin", %opts);
}

# Profile for libraries for GHC FFI packages.
sub ceh_nixpkgs_install_for_ghc {
    my ($pkgattr, %opts) = @_;
    return ceh_nixpkgs_install($pkgattr, "/nix/var/nix/profiles/ceh/ghc-libs", %opts);
}

# Use this profile when you're installing packages used only by the
# functions in these files.  E.g. the which package for ceh_exclude.
sub ceh_nixpkgs_install_tools {
    my ($pkgattr, %opts) = @_;
    return ceh_nixpkgs_install($pkgattr, "/nix/var/nix/profiles/ceh/tools", %opts);
}

# Profile for stuff needed to properly wrap GHC, used by ceh internally.
sub ceh_nixpkgs_install_ghctools {
    my ($pkgattr, %opts) = @_;
    return ceh_nixpkgs_install($pkgattr, "/nix/var/nix/profiles/ceh/ghc-tools", %opts);
}

1;
