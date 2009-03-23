#! /bin/sh

_exit()
{
    /bin/echo -e "Error: $*"
    /bin/echo
    exit 1
}


QPKG_DIR="$(/usr/bin/dirname "$0")"
source $QPKG_DIR/environ.sh

$CMD_CAT
$CMD_CAT <<EOF

###########################################################################
# SECTION: Network setup

agentaddress tcp:
agentaddress udp:
EOF
