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
IOS_INSTALL_DIR=$INTERMEDIATE/ios-install
MAC_INSTALL_DIR=$INTERMEDIATE/mac-install
PATCHED_SRC_DIR=$INTERMEDIATE/ios-sources-patched
IOS_BUILD_DIR=$INTERMEDIATE/ios-build
MAC_BUILD_DIR=$INTERMEDIATE/mac-build

echo "OpenCV source   :" $SRC
echo "Build directory :" $BUILD
echo "Intermediate dir:" $INTERMEDIATE
echo "Patched source  :" $PATCHED_SRC_DIR

OPENCV_MODULES_TO_BUILD=(zlib libjpeg libpng libtiff libjasper opencv_calib3d opencv_core opencv_features2d opencv_flann opencv_imgproc opencv_legacy opencv_contrib opencv_ml opencv_objdetect opencv_video)

################################################################################
# Clear the old build and recompile the new one.
echo "WARNING: The bulid directory will be removed and re-created again."
echo "WARNING: Is your last chance to check is it correct and you do not have anything valuable in it."
read -p "Press any key to continue..."

rm -rf $BUILD

################################################################################
# Now we build OpenCV with macosx sdk.
# This will build opencv INSTALL target, which will 
# copy headers to the $BUILD/include directory.
echo "Installing OpenCV headers"
mkdir -p $MAC_BUILD_DIR
cd $MAC_BUILD_DIR
cmake -DCMAKE_INSTALL_PREFIX=$MAC_INSTALL_DIR \
-DENABLE_SSE=NO \
-DENABLE_SSE2=NO \
-DBUILD_TESTS=OFF \
-DBUILD_EXAMPLES=NO \
-DBUILD_NEW_PYTHON_SUPPORT=NO \
-DWITH_EIGEN2=NO \
-DWITH_PVAPI=NO \
-DWITH_OPENEXR=NO \
-DWITH_QT=NO \
-DWITH_QUICKTIME=NO \
-DOPENCV_BUILD_3RDPARTY_LIBS=YES \
-G Xcode $SRC > /dev/null

mkdir $BUILD/include
xcodebuild -sdk macosx -configuration Release -parallelizeTargets -target install > /dev/null
mv $MAC_INSTALL_DIR/include/* $BUILD/include

################################################################################
# We have to patch OpenCV source to exclude several modules form build
# because they prevent building other libs.
echo "Patching OpenCV sources"
mkdir -p $PATCHED_SRC_DIR
cp -R $SRC/ $PATCHED_SRC_DIR
sed '/add_subdirectory(ts)/d' $PATCHED_SRC_DIR/modules/CMakeLists.txt      > $PATCHED_SRC_DIR/modules/CMakeLists.txt.patched
mv $PATCHED_SRC_DIR/modules/CMakeLists.txt.patched                           $PATCHED_SRC_DIR/modules/CMakeLists.txt
sed '/add_subdirectory(highgui)/d' $PATCHED_SRC_DIR/modules/CMakeLists.txt > $PATCHED_SRC_DIR/modules/CMakeLists.txt.patched
mv $PATCHED_SRC_DIR/modules/CMakeLists.txt.patched                           $PATCHED_SRC_DIR/modules/CMakeLists.txt

################################################################################
# Configure OpenCV for iOS SDK
mkdir -p $IOS_BUILD_DIR
cd $IOS_BUILD_DIR

cmake -DCMAKE_INSTALL_PREFIX=$IOS_INSTALL_DIR \
-DENABLE_SSE=NO \
-DENABLE_SSE2=NO \
-DBUILD_TESTS=OFF \
-DBUILD_SHARED_LIBS=NO \
-DBUILD_NEW_PYTHON_SUPPORT=NO \
-DBUILD_EXAMPLES=NO \
-DUSE_O3=YES \
-DCMAKE_C_FLAGS_DEBUG:STRING="-fvisibility=hidden -mno-thumb" \
-DCMAKE_CXX_FLAGS_DEBUG:STRING="-fvisibility=hidden -mno-thumb" \
-DCMAKE_C_FLAGS_RELEASE:STRING="-fvisibility=hidden -mno-thumb" \
-DCMAKE_CXX_FLAGS_RELEASE:STRING="-fvisibility=hidden -mno-thumb" \
-DUSE_PRECOMPILED_HEADERS=NO \
-DWITH_EIGEN2=NO \
-DWITH_PVAPI=NO \
-DWITH_OPENEXR=NO \
-DWITH_QT=NO \
-DWITH_QUICKTIME=NO \
-DOPENCV_BUILD_3RDPARTY_LIBS=YES \
-G Xcode $PATCHED_SRC_DIR > /dev/null

################################################################################
# Build for device armv6 architecture :
echo "Building iphone release armv6 configuration"
for target in ${OPENCV_MODULES_TO_BUILD[*]}
do
echo "\tbuilding " $target
xcodebuild -sdk iphoneos -configuration Release -parallelizeTargets ARCHS="armv6" -target $target > /dev/null
done

mkdir -p $BUILD/lib/release-iphoneos-armv6
mv $IOS_BUILD_DIR/lib/Release/*.a          $BUILD/lib/release-iphoneos-armv6 > /dev/null
mv $IOS_BUILD_DIR/3rdparty/lib/Release/*.a $BUILD/lib/release-iphoneos-armv6 > /dev/null

echo "Building iphone debug armv6 configuration"
for target in ${OPENCV_MODULES_TO_BUILD[*]}
do
echo "\tbuilding " $target
xcodebuild -sdk iphoneos -configuration Debug -parallelizeTargets   ARCHS="armv6" -target $target > /dev/null
done

mkdir -p $BUILD/lib/debug-iphoneos-armv6
mv $IOS_BUILD_DIR/lib/Debug/*.a            $BUILD/lib/debug-iphoneos-armv6 > /dev/null
mv $IOS_BUILD_DIR/3rdparty/lib/Debug/*.a   $BUILD/lib/debug-iphoneos-armv6 > /dev/null

################################################################################
echo "Building iphone simulator release configuration"
for target in ${OPENCV_MODULES_TO_BUILD[*]}
do
echo "\tbuilding " $target
xcodebuild -sdk iphonesimulator -configuration Release -parallelizeTargets ARCHS="i386" -target $target > /dev/null
done

mkdir -p $BUILD/lib/release-iphonesimulator
mv $IOS_BUILD_DIR/lib/Release/*.a          $BUILD/lib/release-iphonesimulator > /dev/null
mv $IOS_BUILD_DIR/3rdparty/lib/Release/*.a $BUILD/lib/release-iphonesimulator > /dev/null

echo "Building iphone simulator debug configuration"
for target in ${OPENCV_MODULES_TO_BUILD[*]}
do
echo "\tbuilding " $target
xcodebuild -sdk iphonesimulator -configuration Debug -parallelizeTargets   ARCHS="i386" -target $target > /dev/null
done

mkdir -p $BUILD/lib/debug-iphonesimulator
mv $IOS_BUILD_DIR/lib/Debug/*.a          $BUILD/lib/debug-iphonesimulator > /dev/null
mv $IOS_BUILD_DIR/3rdparty/lib/Debug/*.a $BUILD/lib/debug-iphonesimulator > /dev/null

################################################################################
# Build for device armv7 debug architecture :
echo "Building iphone debug armv7 configuration"
for target in ${OPENCV_MODULES_TO_BUILD[*]}
do
echo "\tbuilding " $target
xcodebuild -sdk iphoneos -configuration Debug -parallelizeTargets   ARCHS="armv7" -target $target > /dev/null
done

mkdir -p $BUILD/lib/debug-iphoneos-armv7
mv $IOS_BUILD_DIR/lib/Debug/*.a            $BUILD/lib/debug-iphoneos-armv7 > /dev/null
mv $IOS_BUILD_DIR/3rdparty/lib/Debug/*.a   $BUILD/lib/debug-iphoneos-armv7 > /dev/null

################################################################################
# Build for device armv7 release architecture :
# Armv7 Release will be built with optimized flags.
# Therefore we have to reconfigure project:

# Theoreticaly, with these flags OpenCV should runs faster in release mode. But i did tests and didn't get any signs of improvements.
#-DCMAKE_C_FLAGS_RELEASE:STRING="-fvisibility=hidden -mthumb -mfpu=neon -funsafe-math-optimizations -mvectorize-with-neon-quad -mtune=cortex-a8 -fsee -funroll-loops -ftree-vectorize -mfloat-abi=softfp -fstrict-aliasing -fgcse-las -funsafe-loop-optimizations" \
#-DCMAKE_CXX_FLAGS_RELEASE:STRING="-fvisibility=hidden -mthumb -mfpu=neon -funsafe-math-optimizations -mvectorize-with-neon-quad -mtune=cortex-a8 -fsee -funroll-loops -ftree-vectorize -mfloat-abi=softfp -fstrict-aliasing -fgcse-las -funsafe-loop-optimizations" \

cmake -DCMAKE_INSTALL_PREFIX=$IOS_INSTALL_DIR \
-DENABLE_SSE=NO \
-DENABLE_SSE2=NO \
-DBUILD_TESTS=OFF \
-DBUILD_SHARED_LIBS=NO \
-DBUILD_NEW_PYTHON_SUPPORT=NO \
-DBUILD_EXAMPLES=NO \
-DCMAKE_C_FLAGS_RELEASE:STRING="-fvisibility=hidden -O3" \
-DCMAKE_CXX_FLAGS_RELEASE:STRING="-fvisibility=hidden -O3" \
-DUSE_PRECOMPILED_HEADERS=NO \
-DWITH_EIGEN2=NO \
-DWITH_PVAPI=NO \
-DWITH_OPENEXR=NO \
-DWITH_QT=NO \
-DWITH_QUICKTIME=NO \
-DOPENCV_BUILD_3RDPARTY_LIBS=YES \
-G Xcode $PATCHED_SRC_DIR > /dev/null

echo "Building iphone release armv7 configuration"
for target in ${OPENCV_MODULES_TO_BUILD[*]}
do
echo "\tbuilding " $target
xcodebuild -sdk iphoneos -configuration Release -parallelizeTargets ARCHS="armv7" -target $target > /dev/null
done

mkdir -p $BUILD/lib/release-iphoneos-armv7
mv $IOS_BUILD_DIR/lib/Release/*.a          $BUILD/lib/release-iphoneos-armv7 > /dev/null
mv $IOS_BUILD_DIR/3rdparty/lib/Release/*.a $BUILD/lib/release-iphoneos-armv7 > /dev/null

################################################################################
# Make universal binaries for release configuration:
mkdir -p $BUILD/lib/release-universal

for FILE in `ls $BUILD/lib/release-iphoneos-armv7`
do
  lipo $BUILD/lib/release-iphoneos-armv7/$FILE \
       $BUILD/lib/release-iphoneos-armv6/$FILE \
       $BUILD/lib/release-iphonesimulator/$FILE \
       -create -output $BUILD/lib/release-universal/$FILE
done

################################################################################
# Make universal binaries for debug configuration:
mkdir -p $BUILD/lib/debug-universal

for FILE in `ls $BUILD/lib/debug-iphoneos-armv7`
do
  lipo $BUILD/lib/debug-iphoneos-armv7/$FILE \
       $BUILD/lib/debug-iphoneos-armv6/$FILE \
       $BUILD/lib/debug-iphonesimulator/$FILE \
       -create -output $BUILD/lib/debug-universal/$FILE
done


################################################################################
# Final cleanup
#rm -rf $INTERMEDIATE
echo "All is done"