#!/bin/bash

if [ "$#" -lt 1 ]; then
    echo "USAGE: $0 filename jobId masterKey vaultName"
    exit 1
fi



filename=$1
jobId=$2
masterKey=$3
vaultName=$4

if [ -z "$vaultName" ]; then
#Configura as variaveis usadads
    . /opt/gradus/conf/grs-variables
    SISTEMA=`cut -d - -f1 /etc/hostname`
    CLIENTE=`cut -d - -f2 /etc/hostname`
    AMBIENTE=`cut -d - -f3 /etc/hostname`
    vaultName=${SISTEMA}-${CLIENTE}-backups-001
fi

# recuperação glacier
aws glacier get-job-output --account-id - --vault-name $vaultName --job-id $jobId $filename

# descompatar o tar os com arquivos encryptados individualmente
tar -xvf $filename

# descriptar arquivo cada uma das partes
for f in *.crypt ; do [ -f $f ] && openssl smime -decrypt -inform DER -in $f -inkey $masterKey > $f-part && rm $f ; done

#juntar todas as partes
filenameZip=$(echo $filename | sed -e 's/.tar//g')
cat *'-part-'* > $filenameZip
rm *'-part'*

#descompactar arquivo
bzip2 -d $filenameZip
