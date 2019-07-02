#!/bin/bash

# dependencies, jq and parallel:
# sudo dnf install jq
# sudo dnf install parallel
# sudo pip install awscli

if [ "$#" -le 1 ]; then
    echo "USAGE: $0 filename vaultName resultFile chunkSize"
    exit 1
fi

if [ ! -f "TreeHashExample.class" ]; then
    javac TreeHashExample.java
fi

filename=$1
vaultName=$2
description=$1
chunkSize=$4
resultFile=$3

if [ -z "$chunkSize" ]; then
   chunkSize=1024
fi

if [ -z "$result_file" ]; then
   result_file=result.json
fi


byteSize=$(expr $chunkSize \* 1024 \* 1024)

prefix="__glacier_upload"

# Part file out
if [[ $OSTYPE == linux* ]]; then
        split --bytes=$byteSize --verbose "$filename" $prefix
elif [[ $OSTYPE == darwin* ]]; then
        split -b ${chunkSize}m "$filename" $prefix  # Mac OSX
fi

# count the number of files that begin with "$prefix"
fileCount=$(ls -1 | grep "^$prefix" | wc -l)
echo "Total parts to upload: " $fileCount

# get the list of part files to upload.  Edit this if you chose a different prefix in the split command
files=$(ls | grep "^$prefix")

# initiate multipart upload connection to glacier
init=$(aws glacier initiate-multipart-upload --account-id - --part-size $byteSize --vault-name $vaultName --archive-description "$description")

echo "---------------------------------------"
# xargs trims off the quotes
# jq pulls out the json element titled uploadId
uploadId=$(echo $init | jq '.uploadId' | xargs)

# create temp file to store commands
touch commands.txt

#get total size in bytes of the archive
archivesize=`wc -c < "$filename"`

# create upload commands to be run in parallel and store in commands.txt
byteStart=0
for f in $files 
  do
     fileSize=`wc -c < $f`
     byteEnd=$((byteStart+fileSize-1))
     echo aws glacier upload-multipart-part --body $f --range "'"'bytes '"$byteStart"'-'"$byteEnd"'/*'"'" --account-id - --vault-name "$vaultName" --upload-id $uploadId >> commands.txt
     byteStart=$(($byteEnd+1))
  done

# run upload commands in parallel
#   --load 100% option only gives new jobs out if the core is than 100% active
#   -a commands.txt runs every line of that file in parallel, in potentially random order
#   --notice supresses citation output to the console
#   --bar provides a command line progress bar
parallel --load 100% -a commands.txt --no-notice --bar

echo "List Active Multipart Uploads:"
echo "Verify that a connection is open:"
aws glacier list-multipart-uploads --account-id - --vault-name $vaultName

#compute the tree hash
checksum=`java TreeHashExample "$filename" | cut -d ' ' -f 5`

# end the multipart upload
result=`aws glacier complete-multipart-upload --account-id - --vault-name $vaultName --upload-id $uploadId --archive-size $archivesize --checksum $checksum`

#store the json response from amazon for record keeping
touch result.json
DATE=$(TZ=America/Sao_Paulo date +"%Y%m%d_%Hh%Mm%Ss%Z")

echo $DATE $filename $result
echo $DATE $filename $result >> result.json

# list open multipart connections
echo "------------------------------"
echo "List Active Multipart Uploads:"
echo "Verify that the connection is closed:"
aws glacier list-multipart-uploads --account-id - --vault-name $vaultName

echo "--------------"
echo "Deleting temporary commands.txt file"
rm ${prefix}* commands.txt
