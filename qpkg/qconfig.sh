#! /bin/sh

_exit()
{
    /bin/echo -e "Error: $*"
    /bin/echo
    exit 1
}

QPKG_DIR="$(/usr/bin/dirname "$0")"
source $QPKG_DIR/environ.sh

case "$1" in
  start)
        if [ -f $QPKG_DIR/snmpd.conf.orig ]; then
	    _exit  "${QPKG_NAME} is already enabled."
        fi

	$CMD_ECHO "Enable SNMPD"

	$CMD_IPKG install net-snmp

	$CMD_CP $SYS_OPT_DIR/etc/snmpd.conf $QPKG_DIR/snmpd.conf.orig
	$QPKG_DIR/gensnmpd.conf.sh > $SYS_OPT_DIR/etc/snmpd.conf < $QPKG_DIR/snmpd.conf.orig

	$CMD_LN -s $SYS_OPT_INIT_DIR/S70net-snmp $SYS_rcS_DIR/S70net-snmp
	$SYS_rcS_DIR/S70net-snmp
	;;
  stop)
        if ! [ -f $QPKG_DIR/snmpd.conf.orig ]; then
	    _exit  "${QPKG_NAME} is not enabled."
        fi

	$CMD_ECHO "Disable SNMPD"

	$CMD_KILLALL snmpd 2>/dev/null
	$CMD_RM $SYS_rcS_DIR/S70net-snmp	
	$CMD_RM $SYS_OPT_DIR/etc/snmpd.conf
	
	$CMD_RM $QPKG_DIR/snmpd.conf.orig

	$CMD_IPKG remove net-snmp
		
	;;
esac
