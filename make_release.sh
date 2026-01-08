#!/bin/bash

# DESCRIPTION
#
# Script to update the files on github for the IMA SDK iOS DAI samples
#
# USAGE
#
# Make sure to update the number in the VERSION file each time you do a release
#
# Run this script without arguments to add a new entry to the github release
# section with an already built bundle:
#
#   ./googlemac/iPhone/InteractiveMediaAds/IMA/ios/samples/DAI/make_release
#
# It will create a zipped up release for ima sdk.
#
# To update the source files and bundled files on GitHub run the following,
# updating the source files is usually done automatically by copybara:
#
#   ./googlemac/iPhone/InteractiveMediaAds/IMA/ios/samples/DAI/make_release --update_mode
#
# To build the sample apps through copybara in a temp directory before pushing to GitHub run:
#
#   ./googlemac/iPhone/InteractiveMediaAds/IMA/ios/samples/DAI/make_release --test_mode
#
# In the rare case you want to pass additional args to copybara, you can use the following:
#
# ./make_release --copybara_args='--init-history' or ./make_release -a='--init-history'
#
# The above example will append the '--init-history' argument when it runs copybara.
#
# NOTES
#
# If you don't run gcert, this thing will throw all kinds of weird piper
# errors.
#

set -e

GITHUB_OWNER='googleads'
GITHUB_REPOSITORY='googleads-ima-ios-dai'

# Figure out where we are, get google3 location
GOOGLE3=$(pwd)
if [[ "$(basename "$(pwd)")" != "google3" ]]; then
  GOOGLE3=$(pwd | grep -o ".*/google3/" | grep -o ".*google3")
fi
if [[ -z "${GOOGLE3}" ]]; then
  echo "Error - no google3 in current working directory"
  exit 1
fi

# Parse command line options
TEST_MODE=false
UPDATE_MODE=false
BUILD_BUNDLE=false
for i in "$@" ; do
  case $i in
    --test_mode|-t)
      TEST_MODE=true
      BUILD_BUNDLE=true
      ;;
    --update_mode|-u)
      UPDATE_MODE=true
      BUILD_BUNDLE=true
      ;;
    --copybara_args=*|-a=*)
      # get the argument value - see http://tldp.org/LDP/abs/html/string-manipulation.html (search substring removal)
      COPYBARA_ARGS_ARRAY=("${i#*=}")
      echo "copybara args: ${COPYBARA_ARGS_ARRAY[*]}"
      ;;
    *)
      echo "Unknown option $i"
      exit 1
      ;;
  esac
done

VERSION=$(cat "${GOOGLE3}/googlemac/iPhone/InteractiveMediaAds/IMA/ios/samples/DAI/VERSION")
COPYBARA="/google/data/ro/teams/copybara/copybara"
CONFIG_PATH="${GOOGLE3}/googlemac/iPhone/InteractiveMediaAds/IMA/ios/samples/DAI/copy.bara.sky"
TEMP_DIR="/tmp/copybara_test_ios_ima_dai"
COMMIT_MSG="Committing latest changes for v${VERSION}"

# Create Copybara change and commit to github (does not commit in test mode)
do_git_push() {
  rm -rf ${TEMP_DIR}

  if [[ $UPDATE_MODE = false ]] ; then
    echo "Creating copybara test change for version ${VERSION}..."
    copybara_cmd_array=(
      "${COPYBARA}"
      "${CONFIG_PATH}"
      postsubmit_piper_to_github
      -v
      "${COPYBARA_ARGS_ARRAY[@]}"  # Correctly expands the additional args
      --git-destination-path
      "${TEMP_DIR}"
      --dry-run
      --force
      --squash
    )
  fi

  if [[ $UPDATE_MODE = true ]] ; then
    echo "Creating Copybara change for version ${VERSION}..."
    copybara_cmd_array=(
      "${COPYBARA}"
      "${CONFIG_PATH}"
      postsubmit_piper_to_github
      -v
      "${COPYBARA_ARGS_ARRAY[@]}"  # Correctly expands the additional args
      --git-destination-path
      "${TEMP_DIR}"
    )
  fi

  # The "${copybara_cmd_array[@]}" expansion ensures each element
  # is treated as a separate argument, preserving spaces within elements.
  # For more info, see go/shell-style#arrays.
  echo "Running command: ${copybara_cmd_array[*]}" # For debugging
  copybara_output="$("${copybara_cmd_array[@]}" 2>&1)"

  if (( $? != 0 )); then
    echo "Copybara command failed!" >&2
    echo "${copybara_output}" >&2
    # exit 1
  else
    echo "Copybara command succeeded."
    echo "${copybara_output}"
  fi
}

do_release_upload() {
  pushd ${TEMP_DIR}
  # Zip up samples and push to GitHub as a release

  # Objective-C
  ## SampleVideoPlayer
  mkdir objc_sample_player
  cp -r Objective-C/SampleVideoPlayer/* objc_sample_player
  zip -r objc_sample_player.zip objc_sample_player

  ## BasicExample
  mkdir objc_basic_example
  cp -r Objective-C/BasicExample/* objc_basic_example
  zip -r objc_basic_example.zip objc_basic_example

  ## AdvancedExample
  mkdir objc_advanced_example
  cp -r Objective-C/AdvancedExample/* objc_advanced_example
  zip -r objc_advanced_example.zip objc_advanced_example

  ## PodServingExample
  mkdir objc_podserving_example
  cp -r Objective-C/PodServingExample/* objc_podserving_example
  zip -r objc_podserving_example.zip objc_podserving_example

  ## VideoStitcherExample
  mkdir objc_video_stitcher_example
  cp -r Objective-C/VideoStitcherExample/* objc_video_stitcher_example
  zip -r objc_video_stitcher_example.zip objc_video_stitcher_example

  # Swift
  ## SampleVideoPlayer
  mkdir swift_sample_player
  cp -r Swift/SampleVideoPlayer/* swift_sample_player
  zip -r swift_sample_player.zip swift_sample_player

  ## AdvancedExample
  mkdir swift_advanced_example
  cp -r Swift/AdvancedExample/* swift_advanced_example
  zip -r swift_advanced_example.zip swift_advanced_example

  ## BasicExample
  mkdir swift_basic_example
  cp -r Swift/BasicExample/* swift_basic_example
  zip -r swift_basic_example.zip swift_basic_example

  ## PodServingExample
  mkdir swift_podserving_example
  cp -r Swift/PodServingExample/* swift_podserving_example
  zip -r swift_podserving_example.zip swift_podserving_example

  ## VideoStitcherExample
  mkdir swift_video_stitcher_example
  cp -r Swift/VideoStitcherExample/* swift_video_stitcher_example
  zip -r swift_video_stitcher_example.zip swift_video_stitcher_example

  ## SGAIClientSideExample
  mkdir swift_sgai_clientside_example
  cp -r Swift/SGAIClientSideExample/* swift_sgai_clientside_example
  zip -r swift_sgai_clientside_example.zip swift_sgai_clientside_example

  RELEASE_NOTES="#### Google Ads IMA SDK for DAI iOS Samples v${VERSION}

|  Project | ObjC Download | Swift Download | Description |
| -------- | ------------- | -------------- | ----------- |
| Sample Player | [ObjC](https://github.com/googleads/googleads-ima-ios-dai/releases/download/${VERSION}/objc_sample_player.zip) | [Swift](https://github.com/googleads/googleads-ima-ios-dai/releases/download/${VERSION}/swift_sample_player.zip) | Sample video player source files - No SDK integration
| Basic Integration | [ObjC](https://github.com/googleads/googleads-ima-ios-dai/releases/download/${VERSION}/objc_basic_example.zip) | [Swift](https://github.com/googleads/googleads-ima-ios-dai/releases/download/${VERSION}/swift_basic_example.zip) | Basic implementation of Full Service DAI with the IMA SDK. |
| Advanced Integration | [ObjC](https://github.com/googleads/googleads-ima-ios-dai/releases/download/${VERSION}/objc_advanced_example.zip) | [Swift](https://github.com/googleads/googleads-ima-ios-dai/releases/download/${VERSION}/swift_advanced_example.zip) | Advanced implementation of Full Service DAI with the IMA SDK. |
| Pod Serving Integration | [ObjC](https://github.com/googleads/googleads-ima-ios-dai/releases/download/${VERSION}/objc_podserving_example.zip) | [Swift](https://github.com/googleads/googleads-ima-ios-dai/releases/download/${VERSION}/swift_podserving_example.zip) | Basic implementation of Pod Serving DAI with the IMA SDK. |
| Video Stitcher Integration | [ObjC](https://github.com/googleads/googleads-ima-ios-dai/releases/download/${VERSION}/objc_video_stitcher_example.zip) | [Swift](https://github.com/googleads/googleads-ima-ios-dai/releases/download/${VERSION}/swift_video_stitcher_example.zip) | A basic implementation of DAI stream playback with the Google Cloud [Video&nbsp;Stitcher&nbsp;API](https://cloud.google.com/video-stitcher/docs/how-to/gam/before-you-begin) and the IMA SDK. |
| Client-side SGAI Integration | --------- | [Swift](https://github.com/googleads/googleads-ima-ios-dai/releases/download/${VERSION}/swift_sgai_clientside_example.zip) | An example of Server Guided Ad Insertion (SGAI) client-side ad insertion. |"

  pushd "${GOOGLE3}"
  echo "Executing the GitHub uploader..."
  # ObjC
  blaze run //devrel/tools/github:github_uploader --  \
      -f "${TEMP_DIR}/objc_sample_player.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -n "Google Ads IMA SDK iOS for DAI Samples v${VERSION}" \
      -b "${RELEASE_NOTES}" \
      -c "${COMMIT_MSG}"

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/objc_basic_example.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/objc_advanced_example.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/objc_podserving_example.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/objc_video_stitcher_example.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  # Swift
  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/swift_sample_player.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/swift_advanced_example.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/swift_basic_example.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/swift_podserving_example.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/swift_video_stitcher_example.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a

  blaze run //devrel/tools/github:github_uploader -- \
      -f "${TEMP_DIR}/swift_sgai_clientside_example.zip" \
      -u "${GITHUB_OWNER}" \
      -r "${GITHUB_REPOSITORY}" \
      -t "${VERSION}" \
      -a
}

if [[ $BUILD_BUNDLE = true ]] ; then
  do_git_push
fi

if [[ $TEST_MODE = false ]] ; then
  do_release_upload
fi

