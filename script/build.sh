#! /bin/bash


PKG_NAME="$(grep "QPKG_QPKG_FILE=" qpkg/qinstall.sh | sed -e "s+^.*=\"\(.*\)\"$+\1+g" -e "s+\.qpkg$++g")"

find . -name "*~" | while read name; do rm "$name"; done

(
 cd qpkg
 tar -cvf ../qpkg.tar .
)

echo "BUILD"
script/qpkg_build_QNAP.sh $PKG_NAME qpkg.tar script/built-in.sh

rm qpkg.tar
