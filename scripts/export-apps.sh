#!/bin/bash
# Needs an application password that can be generated at https://appleid.apple.com/

set -xe

APPS="${@:-bVNC aRDP aSPICE}"

if [ -z "$USERNAME" ] || [ -z "$PASSWORD" ]
then
  echo "Export USERNAME and PASSWORD environment variables or"
  echo "Enter USERNAME and press enter"
  read -s USERNAME
  echo "Enter PASSWORD and press enter"
  read -s PASSWORD
fi

DATE=$(date +%Y-%m-%d)
PROJ_FILE=../bVNC.xcodeproj
EXPORT_OPTS_FILE=./export-app-store.plist
BASE_EXPORT_PATH=./export/$DATE
buildconfig="Release"

mkdir -p $BASE_EXPORT_PATH

for scheme in $APPS
do
    for destination in 'generic/platform=iOS' 'platform=macOS,variant=Mac Catalyst,arch=x86_64'
    do
        if [ "$destination" == 'platform=macOS,variant=Mac Catalyst,arch=x86_64' ]
        then
            EXPORT_EXTENSION=pkg
            UPLOAD_TYPE=macos
            ARCHIVE_FLAGS="EXCLUDED_ARCHS=arm64"
        elif [ "$destination" == 'generic/platform=iOS' ]
        then
            EXPORT_EXTENSION=ipa
            UPLOAD_TYPE=ios
            ARCHIVE_FLAGS="EXCLUDED_ARCHS=x86_64"
        fi
        EXPORT_PATH=$BASE_EXPORT_PATH/$UPLOAD_TYPE
        mkdir -p $EXPORT_PATH
        
        xcodebuild clean -project $PROJ_FILE -scheme "$scheme" -destination "$destination"
        xcodebuild build -project $PROJ_FILE -scheme "$scheme" -configuration "$buildconfig" -destination "$destination"
        xcodebuild archive -project $PROJ_FILE -scheme "$scheme" -configuration "$buildconfig" -destination "$destination" $ARCHIVE_FLAGS
        ARCHIVE_PATH=$(ls -datr $HOME/Library/Developer/Xcode/Archives/$DATE/$scheme* | tail -1)
        while ! xcodebuild -exportArchive -exportOptionsPlist $EXPORT_OPTS_FILE -allowProvisioningUpdates -archivePath "$ARCHIVE_PATH" -exportPath $EXPORT_PATH
        do
          echo Retrying exportArchive
          sleep 5
        done
        
        UPLOAD_FILE=$EXPORT_PATH/$scheme.$EXPORT_EXTENSION
        echo "Uploading $UPLOAD_FILE to App Store"
        xcrun altool --upload-app -t $UPLOAD_TYPE -f "$UPLOAD_FILE" -u $USERNAME -p $PASSWORD || true
    done
done


