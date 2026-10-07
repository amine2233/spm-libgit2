#!/usr/bin/env bash

swift_checksum() {
    swift package compute-checksum $1
}

LIB_PATH=lib

LIBS=(libssl libcrypto libssh2 libgit2)

for lib in ${LIBS[@]}; do
    echo "checksum $lib"
    swift_checksum $LIB_PATH/$lib.zip
done
