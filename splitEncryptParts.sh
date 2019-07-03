#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "USAGE: $0 filename"
    exit 1
fi


filename=$1

if [ -z "$chunkSize" ]; then
   chunkSize=1024
fi
byteSize=$(expr $chunkSize \* 1024 \* 1024)


#Configura as variaveis usadads
. /opt/gradus/conf/grs-variables

SISTEMA=`cut -d - -f1 /etc/hostname`
CLIENTE=`cut -d - -f2 /etc/hostname`
AMBIENTE=`cut -d - -f3 /etc/hostname`

#Nome do arquivo que vai ser subido
DUMP_FILENAME=${filename}
DUMP_FILENAME_PART="${DUMP_FILENAME}-part-"

FOLDER_TAR="${DUMP_FILENAME}.tar"
FOLDER_TAR_PART="${DUMP_FILENAME}.tar-part-"

CERT1_FILE="${GRS_CONF_CRYPTO_DIR}/gradus-masterkey-publiccert.pem"
CERT2_FILE="${GRS_CONF_CRYPTO_DIR}/${SISTEMA}-backups-${CLIENTE}-${AMBIENTE}-publiccert.pem"

CERT2_FILENAME="$(basename $(readlink -f ${CERT2_FILE}))"

GRS_DATABASE_CONF_FILE="${GRS_CONF_DATABASE_DIR}/database.cnf"

VAULT_NAME=${SISTEMA}-${CLIENTE}-backups-001


#divide em pegados de 1gb****
split -b ${byteSize} ${DUMP_FILENAME} ${DUMP_FILENAME_PART}


# Encrypta o DUMP_FILE's usando as chaves gradus-masterkey e a chave especifica do container****
for f in ${DUMP_FILENAME_PART}* ; do [ -f $f ] && openssl  smime -encrypt -stream -aes256 -in $f -binary -outform DEM ${CERT1_FILE} ${CERT2_FILE}  >  $f.crypt; done

tar -cvf ${FOLDER_TAR} *.crypt
rm *-part-*
