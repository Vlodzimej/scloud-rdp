#!/bin/bash
# Needs an application password that can be generated at https://appleid.apple.com/

set -xe

DATE=$(date +%Y-%m-%d)
PROJ_FILE=../bVNC.xcodeproj
EXPORT_OPTS_FILE=./export-app-store.plist
BASE_EXPORT_PATH=./export/$DATE
buildconfig="Release"

APPS="${APPS:-bVNC aRDP aSPICE}"
BUILD=false
ARCHIVE=false
UPLOAD=false

while getopts ":bauf:" o
do
    case "${o}" in
        b)
            BUILD=true
            ;;
        a)
            ARCHIVE=true
            ;;
        u)
            UPLOAD=true
            ;;
        f)
            APPS="${OPTARG}"
            [[ ! $APPS =~ aRDP|bVNC|aSPICE ]] && {
                echo "Provide one or more app to build, archive, or upload"
                exit 1
            }
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

function usage() {
    echo "Usage: $0 [-bau] [-f <quoted list of apps>]" 1>&2
    exit 1
}

function check_credentials() {
    if [ -z "$AUSERNAME" ] || [ -z "$APASSWORD" ]
    then
    echo "Export AUSERNAME and APASSWORD environment variables or"
    echo "Enter AUSERNAME and press enter"
    read -s AUSERNAME
    echo "Enter APASSWORD and press enter"
    read -s APASSWORD
    fi
}

function increment_project_version() {
    CURRENT_PROJECT_VERSION="$(grep CURRENT_PROJECT_VERSION ${PROJ_FILE}/project.pbxproj | head -n 1 | sed 's/CURRENT_PROJECT_VERSION = \(.*\);/\1/' | xargs)"
    NEXT_PROJECT_VERSION=$((${CURRENT_PROJECT_VERSION} + 1))

    if [ -z "${CURRENT_PROJECT_VERSION}" -o -z "${NEXT_PROJECT_VERSION}" ]
    then
        echo "Error: Could not determine next build number"
        exit 2
    fi

    echo "Changing CURRENT_PROJECT_VERSION from ${CURRENT_PROJECT_VERSION} to ${NEXT_PROJECT_VERSION}"

    sed -i.bak "s/CURRENT_PROJECT_VERSION = ${CURRENT_PROJECT_VERSION}/CURRENT_PROJECT_VERSION = ${NEXT_PROJECT_VERSION}/" ${PROJ_FILE}/project.pbxproj
}

function get_project_version() {
    NUMBER_OF_VERSIONS="$(grep CURRENT_PROJECT_VERSION ${PROJ_FILE}/project.pbxproj | uniq | wc -l | xargs)"
    if [ "${NUMBER_OF_VERSIONS}" -gt "1" ]
    then
        echo "Error: CURRENT_PROJECT_VERSION is not the same across all the apps, exiting"
        exit 3
    fi
    CURRENT_PROJECT_VERSION="$(grep CURRENT_PROJECT_VERSION ${PROJ_FILE}/project.pbxproj | head -n 1 | sed 's/CURRENT_PROJECT_VERSION = \(.*\);/\1/' | xargs)"
    echo ${CURRENT_PROJECT_VERSION}
}

function get_marketing_version() {
    NUMBER_OF_VERSIONS="$(grep MARKETING_VERSION ${PROJ_FILE}/project.pbxproj | uniq | wc -l | xargs)"
    if [ "${NUMBER_OF_VERSIONS}" -gt "1" ]
    then
        echo "Error: MARKETING_VERSION is not the same across all the apps, exiting"
        exit 3
    fi
    MARKETING_VERSION="$(grep MARKETING_VERSION ${PROJ_FILE}/project.pbxproj | head -n 1 | sed 's/MARKETING_VERSION = \(.*\);/\1/' | xargs)"
    echo $MARKETING_VERSION
}

function build_export_archive_apps() {
    echo "Building apps: $APPS"
    for app in $APPS
    do
        SCHEME="$app"
        for destination in 'generic/platform=iOS' 'platform=macOS,variant=Mac Catalyst'
        do
            DESTINATION="${destination}"
            ARCHIVE_FLAGS=""
            if [ "$destination" == 'platform=macOS,variant=Mac Catalyst' ]
            then
                SCHEME="$SCHEME-macos"
                EXPORT_EXTENSION=pkg
                UPLOAD_TYPE=macos
            elif [ "$destination" == 'generic/platform=iOS' ]
            then
                EXPORT_EXTENSION=ipa
                UPLOAD_TYPE=ios
                ARCHIVE_FLAGS="EXCLUDED_ARCHS=x86_64"
            fi
            EXPORT_PATH=$BASE_EXPORT_PATH/$UPLOAD_TYPE
            mkdir -p $EXPORT_PATH
            
            if [ -n "$BUILD" ]
            then
                xcodebuild clean -project $PROJ_FILE -scheme "$SCHEME" -destination "$DESTINATION"
                xcodebuild build -project $PROJ_FILE -scheme "$SCHEME" -configuration "$buildconfig" -destination "$DESTINATION"
            fi

            if [ -n "$ARCHIVE" ]
            then
                xcodebuild archive -project $PROJ_FILE -scheme "$SCHEME" -configuration "$buildconfig" -destination "$DESTINATION" $ARCHIVE_FLAGS
                ARCHIVE_PATH=$(ls -datr $HOME/Library/Developer/Xcode/Archives/$DATE/$app* | tail -1)
                while ! xcodebuild -exportArchive -exportOptionsPlist $EXPORT_OPTS_FILE -allowProvisioningUpdates -archivePath "$ARCHIVE_PATH" -exportPath $EXPORT_PATH
                do
                echo Retrying exportArchive
                sleep 5
                done
            fi

            if [ -n "$UPLOAD" ]
            then
                UPLOAD_FILE=$(ls -1 $EXPORT_PATH/$app*.$EXPORT_EXTENSION)
                echo "Uploading $UPLOAD_FILE to App Store"
                xcrun altool --upload-app -t $UPLOAD_TYPE -f "$UPLOAD_FILE" -u $AUSERNAME -p $APASSWORD || true
            fi
        done
    done
}

function output_changelog() {
    for a in $APPS ; do echo $a ; head -n15 ../CHANGELOG-$a ; echo ; echo ; done
}


mkdir -p $BASE_EXPORT_PATH

check_credentials

NEXT_PROJECT_VERSION=$(get_project_version)
MARKETING_VERSION=$(get_marketing_version)

increment_project_version

git add -u ${PROJ_FILE}/project.pbxproj
git commit -m "Version v${MARKETING_VERSION}, Build ${NEXT_PROJECT_VERSION}"

build_export_archive_apps

output_changelog
