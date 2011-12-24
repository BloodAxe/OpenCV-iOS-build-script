#!/bin/bash
################################################################################
# This script will create universal binaries for OpenCV library for
# iOS-based devices (iPhone, iPad, iPod, etc).
# As output you obtain debug/release static libraries and include headers.
# 
# This script was written by Eugene Khvedchenya
# And distributed under GPL license
# Support site: http://computer-vision-talks.com
################################################################################

if [ $# -ne 2 ]
then
    echo "Error in $0 - Invalid Argument Count"
    echo "Syntax: $0 [OpenCV source directory] [Build destination directory]"
    echo "If the destination directory already exists, it will be overwritten!"
    exit
fi

# Absolute path to the source code directory.
D=`dirname "$1"`
B=`basename "$1"`
SRC="`cd \"$D\" 2>/dev/null && pwd || echo \"$D\"`/$B"

# Absolute path to the build directory.
D=`dirname "$2"`
B=`basename "$2"`
BUILD="`cd \"$D\" 2>/dev/null && pwd || echo \"$D\"`/$B"

INTERMEDIATE=$BUILD/tmp
IOS_DEV_BUILD_DIR=$INTERMEDIATE/ios-dev-build
IOS_SIM_BUILD_DIR=$INTERMEDIATE/ios-sim-build

################################################################################
# Clear the old build and recompile the new one.
echo $SRC
echo $BUILD
echo "WARNING: The bulid directory will be removed and re-created again."
echo "WARNING: It's your last chance to check is it correct and you do not have anything valuable in it."
read -p "Press any key to continue..."

#rm -rf $BUILD

################################################################################
# Build release and debug configurations for iOS device
mkdir -p $IOS_DEV_BUILD_DIR
pushd $IOS_DEV_BUILD_DIR
cmake -GXcode -DCMAKE_TOOLCHAIN_FILE=$SRC/ios/cmake/Toolchains/Toolchain-iPhoneOS_Xcode.cmake \
-DCMAKE_INSTALL_PREFIX=$INTERMEDIATE/install \
-DOPENCV_BUILD_3RDPARTY_LIBS=YES \
-DBUILD_EXAMPLES=NO \
-DBUILD_TESTS=NO \
-DBUILD_NEW_PYTHON_SUPPORT=NO \
-DBUILD_PERF_TESTS=NO \
-DCMAKE_XCODE_ATTRIBUTE_GCC_VERSION="com.apple.compilers.llvmgcc42" $SRC

xcodebuild -sdk iphoneos -configuration Release -target ALL_BUILD
xcodebuild -sdk iphoneos -configuration Release -target install install
xcodebuild -sdk iphoneos -configuration Debug -target ALL_BUILD
popd

################################################################################
# Build release and debug configurations for iOS simulator
mkdir -p $IOS_SIM_BUILD_DIR
pushd $IOS_SIM_BUILD_DIR
cmake -GXcode -DCMAKE_TOOLCHAIN_FILE=$SRC/ios/cmake/Toolchains/Toolchain-iPhoneSimulator_Xcode.cmake \
-DCMAKE_INSTALL_PREFIX=$INTERMEDIATE/install \
-DOPENCV_BUILD_3RDPARTY_LIBS=YES \
-DBUILD_EXAMPLES=NO \
-DBUILD_TESTS=NO \
-DBUILD_NEW_PYTHON_SUPPORT=NO \
-DBUILD_PERF_TESTS=NO \
-DCMAKE_XCODE_ATTRIBUTE_GCC_VERSION="com.apple.compilers.llvmgcc42" $SRC
xcodebuild -sdk iphonesimulator -configuration Release -target ALL_BUILD
xcodebuild -sdk iphonesimulator -configuration Debug -target ALL_BUILD
popd

################################################################################
# Copy third party libs to opencv libs lib dir:
cp -f $IOS_DEV_BUILD_DIR/3rdparty/lib/Debug/*.a   $IOS_DEV_BUILD_DIR/lib/Debug/
cp -f $IOS_DEV_BUILD_DIR/3rdparty/lib/Release/*.a $IOS_DEV_BUILD_DIR/lib/Release/

cp -f $IOS_SIM_BUILD_DIR/3rdparty/lib/Debug/*.a   $IOS_SIM_BUILD_DIR/lib/Debug/
cp -f $IOS_SIM_BUILD_DIR/3rdparty/lib/Release/*.a $IOS_SIM_BUILD_DIR/lib/Release/

################################################################################
# Make universal binaries for release configuration:
mkdir -p $BUILD/lib/Release/

for FILE in `ls $IOS_DEV_BUILD_DIR/lib/Release`
do
  lipo $IOS_DEV_BUILD_DIR/lib/Release/$FILE \
       $IOS_SIM_BUILD_DIR/lib/Release/$FILE \
       -create -output $BUILD/lib/Release/$FILE
done

################################################################################
# Make universal binaries for debug configuration:
mkdir -p $BUILD/lib/Debug/

for FILE in `ls $IOS_DEV_BUILD_DIR/lib/Debug`
do
lipo $IOS_DEV_BUILD_DIR/lib/Debug/$FILE \
$IOS_SIM_BUILD_DIR/lib/Debug/$FILE \
-create -output $BUILD/lib/Debug/$FILE
done

################################################################################
# Copy headers:
rm -rf $BUILD/include
mv $INTERMEDIATE/install/include $BUILD/include

################################################################################
# Final cleanup
#rm -rf $INTERMEDIATE
echo "All is done"