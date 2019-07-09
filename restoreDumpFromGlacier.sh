#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "USAGE: $0 filename jobId masterKey"
    exit 1
fi


filename=$1
jobId=$2
masterKey=$3

#Configura as variaveis usadads
. /opt/gradus/conf/grs-variables

SISTEMA=`cut -d - -f1 /etc/hostname`
CLIENTE=`cut -d - -f2 /etc/hostname`
AMBIENTE=`cut -d - -f3 /etc/hostname`
VAULT_NAME=${SISTEMA}-${CLIENTE}-backups-001

# recuperação glacier
aws glacier get-job-output --account-id - --vault-name ${VAULT_NAME} --job-id $jobId $filename

# descompatar o tar os com arquivos encryptados individualmente
tar -xvf $filename

# descriptar arquivo cada uma das partes
for f in *.crypt ; do [ -f $f ] && openssl smime -decrypt -inform DER -in $f -inkey $masterKey > $f-part && rm $f ; done

#juntar todas as partes
cat *'-part-'* > $filename
rm *'-part'*

#descompactar arquivo
bzip2 -d $filename