#!/bin/sh
#================================================================
# Copyright (C) 2009 Egil Moeller, FreeCode AS <egil.moller@freecode.no>
# Copyright (C) 2008 QNAP Systems, Inc.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#----------------------------------------------------------------
#
# install.sh
#
#	Abstract: 
#		A program of QPKG installation on QNAP TS-509
#		SNMPD installation
#
#	HISTORY:
#		2008/07/01	-	Created	- AndyChuo 
# 
#================================================================

##### Util #####
CMD_CHMOD="/bin/chmod"
CMD_CHOWN="/bin/chown"
CMD_CHROOT="/usr/sbin/chroot"
CMD_CP="/bin/cp"
CMD_CUT="/bin/cut"
CMD_ECHO="/bin/echo"
CMD_GETCFG="/sbin/getcfg"
CMD_GREP="/bin/grep"
CMD_IFCONFIG="/sbin/ifconfig"
CMD_LN="/bin/ln"
CMD_MKDIR="/bin/mkdir"
CMD_MV="/bin/mv"
CMD_READLINK="/usr/bin/readlink"
CMD_RM="/bin/rm"
CMD_SED="/bin/sed"
CMD_SETCFG="/sbin/setcfg"
CMD_SLEEP="/bin/sleep"
CMD_SYNC="/bin/sync"
CMD_TAR="/bin/tar"
CMD_TOUCH="/bin/touch"
CMD_WLOG="/sbin/write_log"
CMD_IPKG="/opt/bin/ipkg"
CMD_CAT="/bin/cat"
CMD_KILLALL="/usr/bin/killall"
##### System #####
UPDATE_PROCESS="/tmp/update_process"
UPDATE_PB=0
UPDATE_P1=1
UPDATE_P2=2
UPDATE_PE=3
SYS_HOSTNAME=`/bin/hostname`
SYS_IP=`$CMD_IFCONFIG eth0 | $CMD_GREP "inet addr" | $CMD_CUT -f 2 -d ':' | $CMD_CUT -f 1 -d ' '`
#SYS_IP=`$CMD_GREP "${SYS_HOSTNAME}" /etc/hosts | $CMD_CUT -f 1`
SYS_CONFIG_DIR="/etc/config" #put the configuration files here
SYS_INIT_DIR="/etc/init.d"
SYS_rcS_DIR="/etc/rcS.d/"
SYS_rcK_DIR="/etc/rcK.d/"
SYS_QPKG_CONFIG_FILE="/etc/config/qpkg.conf" #qpkg infomation file
SYS_QPKG_CONF_FIELD_QPKGFILE="QPKG_File"
SYS_QPKG_CONF_FIELD_NAME="Name"
SYS_QPKG_CONF_FIELD_VERSION="Version"
SYS_QPKG_CONF_FIELD_ENABLE="Enable"
SYS_QPKG_CONF_FIELD_DATE="Date"
SYS_QPKG_CONF_FIELD_SHELL="Shell"
SYS_QPKG_CONF_FIELD_INSTALL_PATH="Install_Path"
SYS_QPKG_CONF_FIELD_CONFIG_PATH="Config_Path"
SYS_QPKG_CONF_FIELD_WEBUI="WebUI"
SYS_QPKG_CONF_FIELD_WEBPORT="Web_Port"
SYS_QPKG_CONF_FIELD_SERVICEPORT="Service_Port"
SYS_QPKG_CONF_FIELD_SERVICE_PIDFILE="Pid_File"
SYS_QPKG_CONF_FIELD_AUTHOR="Author"
SYS_OPT_DIR="/opt"
SYS_OPT_INIT_DIR="$SYS_OPT_DIR/etc/init.d"

##### QPKG #####
# please modify or fill up the following items
QPKG_AUTHOR="Egil Moeller"
QPKG_SOURCE_DIR="."
QPKG_QPKG_FILE="SNMPD.qpkg"
QPKG_SOURCE_FILE=
QPKG_NAME="SNMPD"
QPKG_VER="0.1"
QPKG_RC_NUM="101" #for rcS and rcK
QPKG_WEB_PORT=""
QPKG_SERVICE_PORT=""
QPKG_WEBUI="" #Relative path URL of your QPKG web interface 
QPKG_INSTALL_PATH=""
QPKG_CONFIG_PATH=""
QPKG_DIR=""
QPKG_DIR_LINK_NAME=""
QPKG_SERVICE_PROGRAM="qconfig.sh"
QPKG_SERVICE_PROGRAM_CHROOT=""
QPKG_SERVICE_PIDFILE=""
QPKG_CONFIG_DIR=$QPKG_CONFIG_PATH # will be removed
QPKG_ROOTFS="/mnt/HDA_ROOT/rootfs_2_3_6"
QPKG_INSTALL_MSG=""
QPKG_BASE=""
#
#####	Func ######

find_base(){
# Determine BASE installation location according to smb.conf

publicdir=`/sbin/getcfg Public path -f /etc/config/smb.conf`
if [ ! -z $publicdir ] && [ -d $publicdir ];then
	publicdirp1=`/bin/echo $publicdir | /bin/cut -d "/" -f 2`
	publicdirp2=`/bin/echo $publicdir | /bin/cut -d "/" -f 3`
	publicdirp3=`/bin/echo $publicdir | /bin/cut -d "/" -f 4`
	if [ ! -z $publicdirp1 ] && [ ! -z $publicdirp2 ] && [ ! -z $publicdirp3 ]; then
		[ -d "/${publicdirp1}/${publicdirp2}/Public" ] && QPKG_BASE="/${publicdirp1}/${publicdirp2}"
	fi
fi

# Determine BASE installation location by checking where the Public folder is.
if [ -z $QPKG_BASE ]; then
	for datadirtest in /share/HDA_DATA /share/HDB_DATA /share/HDC_DATA /share/HDD_DATA /share/MD0_DATA; do
		[ -d $datadirtest/Public ] && QPKG_BASE="/${publicdirp1}/${publicdirp2}"
	done
fi
if [ -z $QPKG_BASE ] ; then
	echo "The Public share not found."
	_exit 1
fi

#echo ${QPKG_BASE}
#$CMD_MKDIR -p ${QPKG_BASE}/.qpkg
}


_exit(){
	local ret=0

	case $1 in
		0)#normal exit
			ret=0
			if [ "x$QPKG_INSTALL_MSG" != "x" ]; then
				$CMD_WLOG "${QPKG_INSTALL_MSG}" 4
			else
				$CMD_WLOG "${QPKG_NAME} ${QPKG_VER} installation succeeded." 4
			fi
			$CMD_ECHO "$UPDATE_PE" > ${UPDATE_PROCESS}
			;;
		*)
			ret=1
			if [ "x$QPKG_INSTALL_MSG" != "x" ];then
				$CMD_WLOG "${QPKG_INSTALL_MSG}" 1
			else
				$CMD_WLOG "${QPKG_NAME} ${QPKG_VER} installation failed" 1
			fi
			$CMD_ECHO -1 > ${UPDATE_PROCESS}
			;;
	esac

	exit $ret
}

install()
{
	find_base
	QPKG_INSTALL_PATH="${QPKG_BASE}/.qpkg"
	QPKG_DIR="${QPKG_INSTALL_PATH}/${QPKG_NAME}"
	
        if [ -f "$CMD_IPKG" ]; then
		if [ -d ${QPKG_DIR} ]; then
			QPKG_INSTALL_MSG="${QPKG_NAME} ${QPKG_VER} installation failed. ${QPKG_DIR} or ${QPKG_CONFIG_DIR} existed. Please remove it first."
			$CMD_ECHO "$QPKG_INSTALL_MSG"
			_exit 1					
		fi

		$CMD_MKDIR -p ${QPKG_DIR}
		set |
		 grep -e "^SYS_" -e "^QPKG_" -e "^CMD_" > "${QPKG_DIR}/environ.sh" 
		$CMD_CP "${QPKG_SOURCE_DIR}/${QPKG_SERVICE_PROGRAM}" ${QPKG_DIR}
		$CMD_CP "${QPKG_SOURCE_DIR}/gensnmpd.conf.sh" ${QPKG_DIR}
		
	        ${QPKG_DIR}/qconfig.sh start

#set QPKG information to $SYS_QPKG_CONFIG_FILE
		$CMD_ECHO "Set QPKG information to $SYS_QPKG_CONFIG_FILE"
		[ -f ${SYS_QPKG_CONFIG_FILE} ] || $CMD_TOUCH ${SYS_QPKG_CONFIG_FILE}
		$CMD_SETCFG ${QPKG_NAME} ${SYS_QPKG_CONF_FIELD_NAME} "${QPKG_NAME}" -f ${SYS_QPKG_CONFIG_FILE}
		$CMD_SETCFG ${QPKG_NAME} ${SYS_QPKG_CONF_FIELD_VERSION} "${QPKG_VER}" -f ${SYS_QPKG_CONFIG_FILE}
		
		#default value to activate(or not) your QPKG if it was a service/daemon
		$CMD_SETCFG ${QPKG_NAME} ${SYS_QPKG_CONF_FIELD_ENABLE} "TRUE" -f ${SYS_QPKG_CONFIG_FILE}

		#set the qpkg file name
		[ "x${SYS_QPKG_CONF_FIELD_QPKGFILE}" = "x" ] && $CMD_ECHO "Warning: ${SYS_QPKG_CONF_FIELD_QPKGFILE} is not specified!!"
		[ "x${SYS_QPKG_CONF_FIELD_QPKGFILE}" = "x" ] || $CMD_SETCFG ${QPKG_NAME} ${SYS_QPKG_CONF_FIELD_QPKGFILE} "${QPKG_QPKG_FILE}" -f ${SYS_QPKG_CONFIG_FILE}
		
		#set the date of installation
		$CMD_SETCFG ${QPKG_NAME} ${SYS_QPKG_CONF_FIELD_DATE} `date +%F` -f ${SYS_QPKG_CONFIG_FILE}
		
		#set the path of start/stop shell script
		[ "x${QPKG_SERVICE_PROGRAM}" = "x" ] || $CMD_SETCFG ${QPKG_NAME} ${SYS_QPKG_CONF_FIELD_SHELL} "${QPKG_DIR}/${QPKG_SERVICE_PROGRAM}" -f ${SYS_QPKG_CONFIG_FILE}
		
		#set path where the QPKG installed, should be a directory
		$CMD_SETCFG ${QPKG_NAME} ${SYS_QPKG_CONF_FIELD_INSTALL_PATH} "${QPKG_DIR}" -f ${SYS_QPKG_CONFIG_FILE}

		#set path where the QPKG configure directory/file is
		[ "x${QPKG_CONFIG_PATH}" = "x" ] || $CMD_SETCFG ${QPKG_NAME} ${SYS_QPKG_CONF_FIELD_CONFIG_PATH} "${QPKG_CONFIG_PATH}" -f ${SYS_QPKG_CONFIG_FILE}
		
		#set the port number if your QPKG was a service/daemon and needed a port to run.
		[ "x${QPKG_SERVICE_PORT}" = "x" ] || $CMD_SETCFG ${QPKG_NAME} ${SYS_QPKG_CONF_FIELD_SERVICEPORT} "${QPKG_SERVICE_PORT}" -f ${SYS_QPKG_CONFIG_FILE}

		#set the port number if your QPKG was a service/daemon and needed a port to run.
		[ "x${QPKG_WEB_PORT}" = "x" ] || $CMD_SETCFG ${QPKG_NAME} ${SYS_QPKG_CONF_FIELD_WEBPORT} "${QPKG_WEB_PORT}" -f ${SYS_QPKG_CONFIG_FILE}

		#set the URL of your QPKG Web UI if existed.
		[ "x${QPKG_WEBUI}" = "x" ] || $CMD_SETCFG ${QPKG_NAME} ${SYS_QPKG_CONF_FIELD_WEBUI} "${QPKG_WEBUI}" -f ${SYS_QPKG_CONFIG_FILE}

		#set the pid file path if your QPKG was a service/daemon and automatically created a pidfile while running.
		[ "x${QPKG_SERVICE_PIDFILE}" = "x" ] || $CMD_SETCFG ${QPKG_NAME} ${SYS_QPKG_CONF_FIELD_SERVICE_PIDFILE} "${QPKG_SERVICE_PIDFILE}" -f ${SYS_QPKG_CONFIG_FILE}

		#Sign up
		[ "x${QPKG_AUTHOR}" = "x" ] && $CMD_ECHO "Warning: ${SYS_QPKG_CONF_FIELD_AUTHOR} is not specified!!"
		[ "x${QPKG_AUTHOR}" = "x" ] || $CMD_SETCFG ${QPKG_NAME} ${SYS_QPKG_CONF_FIELD_AUTHOR} "${QPKG_AUTHOR}" -f ${SYS_QPKG_CONFIG_FILE}
		
		$CMD_SYNC
		QPKG_INSTALL_MSG="${QPKG_NAME} ${QPKG_VER} has been installed in $QPKG_DIR."
		$CMD_ECHO "$QPKG_INSTALL_MSG"
		_exit 0
	else
		QPKG_INSTALL_MSG="${QPKG_NAME} ${QPKG_VER} installation failed. ipkg not installed. Please install ipkg first."
		$CMD_ECHO "$QPKG_INSTALL_MSG"
		_exit 1		
	fi
}

##### Main #####

$CMD_ECHO "$UPDATE_PB" > ${UPDATE_PROCESS}
install

