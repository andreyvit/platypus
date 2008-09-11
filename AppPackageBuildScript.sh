#!/bin/sh
#
# Generate Platypus.zip

# Get version
VERSION=`perl -e 'use Shell;@lines=cat("CommonDefs.h");foreach(@lines){if($_=~m/Platypus-(\d\.\d)/){print $1;}}'`

# Folder name
FOLDER=Platypus-$VERSION

# Create the folder
mkdir /tmp/$FOLDER
cp -r build/Deployment/Platypus.app /tmp/$FOLDER/
cp License.txt /tmp/$FOLDER/
cp Readme.html /tmp/$FOLDER/
cp -r 'Sample Scripts' /tmp/$FOLDER/

# Remove any svn files
/usr/bin/find /tmp/$FOLDER -type d -name .svn -exec rm -rf '{}' +

# Trim binaries, compress tiffs, remove .DS_Store, resource forks, etc.
./trim-app -d -n -s -t -r -p -- /tmp/$FOLDER/

cd /tmp/

/usr/bin/zip -r platypus$VERSION.zip $FOLDER

mv /tmp/platypus$VERSION.zip ~/Desktop/

rm -R /tmp/$FOLDER
