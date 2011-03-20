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
PATCHED_SRC_DIR=$BUILD/src-tmp
INSTALL_DIR=$INTERMEDIATE/install

echo "OpenCV source   :" $SRC
echo "Build directory :" $BUILD
echo "Intermediate dir:" $INTERMEDIATE
echo "Patched source  :" $PATCHED_SRC_DIR

OPENCV_MODULES_TO_BUILD=(zlib libjpeg libpng libtiff libjasper opencv_lapack opencv_calib3d opencv_core opencv_features2d opencv_flann opencv_imgproc opencv_legacy opencv_contrib opencv_ml opencv_objdetect opencv_video)

echo "Will build following modules:"
for target in ${OPENCV_MODULES_TO_BUILD[*]}
do
echo $target
done

################################################################################
# Clear the old build and recompile the new one.
rm -rf $BUILD

################################################################################
# We have to patch OpenCV source to exclude several modules form build
# because they prevent building other libs.
echo "Patching OpenCV sources"
mkdir -p $PATCHED_SRC_DIR
cp -R $SRC $PATCHED_SRC_DIR
sed '/add_subdirectory(ts)/d' $PATCHED_SRC_DIR/opencv/modules/CMakeLists.txt      > $PATCHED_SRC_DIR/opencv/modules/CMakeLists.txt.patched
mv $PATCHED_SRC_DIR/opencv/modules/CMakeLists.txt.patched                           $PATCHED_SRC_DIR/opencv/modules/CMakeLists.txt
sed '/add_subdirectory(highgui)/d' $PATCHED_SRC_DIR/opencv/modules/CMakeLists.txt > $PATCHED_SRC_DIR/opencv/modules/CMakeLists.txt.patched
mv $PATCHED_SRC_DIR/opencv/modules/CMakeLists.txt.patched                           $PATCHED_SRC_DIR/opencv/modules/CMakeLists.txt

################################################################################
# Configure OpenCV
mkdir -p $INTERMEDIATE
cd $INTERMEDIATE

cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
-DENABLE_SSE=NO \
-DENABLE_SSE2=NO \
-DBUILD_TESTS=OFF \
-DBUILD_SHARED_LIBS=NO \
-DBUILD_EXAMPLES=NO \
-DWITH_EIGEN2=NO \
-DWITH_PVAPI=NO \
-DWITH_OPENEXR=NO \
-DWITH_QT=NO \
-DWITH_QUICKTIME=NO \
-DOPENCV_BUILD_3RDPARTY_LIBS=YES \
-G Xcode $PATCHED_SRC_DIR/opencv

################################################################################
# Let's b everything:
cd $INTERMEDIATE

################################################################################
echo "Building iphone configuration"
for target in ${OPENCV_MODULES_TO_BUILD[*]}
do
echo "\tbuilding " $target
xcodebuild -sdk iphoneos -configuration Release ARCHS="armv7" -target $target > /dev/null
xcodebuild -sdk iphoneos -configuration Debug   ARCHS="armv7" -target $target > /dev/null
done

mkdir -p $BUILD/lib/release-iphoneos
mv $INTERMEDIATE/lib/Release/*.a          $BUILD/lib/release-iphoneos
mv $INTERMEDIATE/3rdparty/lib/Release/*.a $BUILD/lib/release-iphoneos

mkdir -p $BUILD/lib/debug-iphoneos
mv $INTERMEDIATE/lib/Debug/*.a            $BUILD/lib/debug-iphoneos
mv $INTERMEDIATE/3rdparty/lib/Debug/*.a   $BUILD/lib/debug-iphoneos

################################################################################
echo "Building iphone simulator configuration"
for target in ${OPENCV_MODULES_TO_BUILD[*]}
do
xcodebuild -sdk iphonesimulator -configuration Release ARCHS="i386" -target $target > /dev/null
xcodebuild -sdk iphonesimulator -configuration Debug   ARCHS="i386" -target $target > /dev/null
done

mkdir -p $BUILD/lib/Release-iphonesimulator
mv $INTERMEDIATE/lib/Release/*.a          $BUILD/lib/release-iphonesimulator
mv $INTERMEDIATE/3rdparty/lib/Release/*.a $BUILD/lib/release-iphonesimulator

mkdir -p $BUILD/lib/debug-iphonesimulator
mv $INTERMEDIATE/lib/Debug/*.a          $BUILD/lib/debug-iphonesimulator
mv $INTERMEDIATE/3rdparty/lib/Debug/*.a $BUILD/lib/debug-iphonesimulator

################################################################################
# Make universal binaries for release INTERMEDIATE:
mkdir -p $BUILD/lib/release-universal

for FILE in `ls $BUILD/lib/release-iphoneos`
do
  lipo $BUILD/lib/release-iphoneos/$FILE \
    -arch i386 $BUILD/lib/release-iphonesimulator/$FILE \
    -create -output $BUILD/lib/release-universal/$FILE
done

################################################################################
# Make universal binaries for debug INTERMEDIATE:
mkdir -p $BUILD/lib/debug-universal

for FILE in `ls $BUILD/lib/debug-iphoneos`
do
  lipo $BUILD/lib/debug-iphoneos/$FILE \
    -arch i386 $BUILD/lib/debug-iphonesimulator/$FILE \
    -create -output $BUILD/lib/debug-universal/$FILE
done

################################################################################
# Now we build OpenCV with macosx sdk.
# This will build opencv INSTALL target, which will 
# copy headers to the $BUILD/include directory.
echo "Getting OpenCV headers"

cd $INTERMEDIATE
cmake -DCMAKE_INSTALL_PREFIX=$INSTALL_DIR \
-DENABLE_SSE=NO \
-DENABLE_SSE2=NO \
-DBUILD_TESTS=OFF \
-DBUILD_SHARED_LIBS=NO \
-DBUILD_EXAMPLES=NO \
-DWITH_EIGEN2=NO \
-DWITH_PVAPI=NO \
-DWITH_OPENEXR=NO \
-DWITH_QT=NO \
-DWITH_QUICKTIME=NO \
-DOPENCV_BUILD_3RDPARTY_LIBS=YES \
-G Xcode $SRC

mkdir $BUILD/include
xcodebuild -sdk macosx -configuration Release -target install > /dev/null
mv $INSTALL_DIR/include/* $BUILD/include

#rm -rf $INTERMEDIATE
echo "All is done"