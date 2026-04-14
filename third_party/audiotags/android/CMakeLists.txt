cmake_minimum_required(VERSION 3.10)

set(Version "1.4.5")
set(LibPath "${CMAKE_CURRENT_SOURCE_DIR}/src/main/jniLibs")

if(NOT EXISTS "${LibPath}/arm64-v8a/libaudiotags.so")
  message(FATAL_ERROR
    "Missing vendored audiotags Android JNI libraries under ${LibPath}. "
    "Commit the prebuilt libaudiotags.so files before building."
  )
endif()
