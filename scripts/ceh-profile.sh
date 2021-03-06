# Don't source anything complicated from this file, because that
# pollutes the user's environment with shell functions.  Also, since
# we're not sure that the user's shell is bash, they may not even work.
#
# Let's try to keep this file compatible with shells that are used on
# power-user desktops.  Since the user is supposed to source this in
# her .bashrc, this also should run fast (and not fork).  Currently
# tested with bash, but we aim to support zsh and dash, feel free to
# help us.

. /opt/ceh/lib/base.sh

if ! ceh_check_initialization; then
    return
fi

ceh_path_prepend /opt/ceh/bin
ceh_path_prepend /opt/ceh/bin-user
ceh_path_prepend /opt/ceh/man MANPATH

if ! [ -e /run/current-system ]; then
    # non NixOS
    export NIX_CONF_DIR=/opt/ceh/lib
fi
