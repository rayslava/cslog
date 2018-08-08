cmake_minimum_required(VERSION 3.5)
project(cslog)

enable_language(C CXX)
include (CheckCSourceCompiles)
include (CheckCXXSourceCompiles)
include (CMakeDependentOption)

set(CMAKE_MODULE_PATH
  ${CMAKE_MODULE_PATH}
  ${CMAKE_CURRENT_SOURCE_DIR}/cmake
  )

find_package (Threads REQUIRED)

set(COMMON_SOURCE_FILES
  src/logging.cpp
  )

find_package(GTest)
if (DEFINED GTEST_INCLUDE_DIRS)
  include_directories(${GTEST_INCLUDE_DIRS})
endif()

if (TRAVIS_BUILD)
  add_definitions(-DTRAVIS_BUILD)
endif()

# Enable thread-safe POSIX implementations of C library
add_definitions(-D_POSIX_C_SOURCE)

set(STANDARD "-std=c++17")

set(CMAKE_CXX_FLAGS         "${CMAKE_CXX_FLAGS} -Wall -Wno-unknown-pragmas -Wno-sign-compare -Woverloaded-virtual -Wwrite-strings -Wno-unused ${STANDARD} -Wextra -pedantic -Werror -pthread")
set(CMAKE_CXX_FLAGS_PROFILED "${CMAKE_CXX_FLAGS} -pg")

if (STATIC)
  add_definitions(-DSTATIC)
  set(BUILD_SHARED_LIBS OFF)
  set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
  set(CMAKE_CXX_FLAGS         "${CMAKE_CXX_FLAGS} -static -Wl,--whole-archive -lpthread -Wl,--no-whole-archive -fPIC -fPIE")
  if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
    set(CMAKE_CXX_FLAGS         "${CMAKE_CXX_FLAGS} -static-libgcc -static-libstdc++")
  endif()
endif()

if (SANITIZED)
  set(CMAKE_CXX_FLAGS         "${CMAKE_CXX_FLAGS} -fsanitize=address")
endif()

set(CMAKE_CXX_FLAGS_DEBUG   "-O0 -g3 ${STANDARD}")
set(CMAKE_CXX_FLAGS_RELEASE "-Ofast ${STANDARD}")

if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "GNU")
  set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -flto -fvisibility=hidden")
endif()

if ("${CMAKE_CXX_COMPILER_ID}" STREQUAL "Clang")
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-error=unknown-warning-option -Wno-error=braced-scalar-init -stdlib=libc++")
  set(LIBCXX_LIBRARY "-lc++abi")
endif()

if ((COVERALLS OR COVERAGE) AND CMAKE_BUILD_TYPE STREQUAL "Debug")
  message(STATUS "will generate coverage data")
  include(CodeCoverage)
  include(Coveralls)
  set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -ggdb -O0 -Wall -W -fprofile-arcs -ftest-coverage --coverage")
  set(CMAKE_SHARED_LINKER_FLAGS="${CMAKE_SHARED_LINKER_FLAGS} -fprofile-arcs -ftest-coverage -lgcov")
  set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fprofile-arcs -ftest-coverage -lgcov")
endif()

if (STATIC)
  add_library(cslog STATIC src/logging.cpp ${SOURCE_FILES})
  SET (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -static")
  SET (STATIC_LIBRT "-lrt")
  set_target_properties(cslog PROPERTIES LINK_SEARCH_START_STATIC 1)
  set_target_properties(cslog PROPERTIES LINK_SEARCH_END_STATIC 1)
else()
  add_library(cslog SHARED src/logging.cpp ${SOURCE_FILES})
endif()

include_directories(
  ${PROJECT_SOURCE_DIR}/include
  )

target_link_libraries(
  cslog
  ${CMAKE_THREAD_LIBS_INIT}
  ${LIBCXX_LIBRARY}
  ${STATIC_LIBRT}
  )

if(CMAKE_SOURCE_DIR STREQUAL PROJECT_SOURCE_DIR)
  include(CTest)
  enable_testing()

  add_executable(logging_tests ${COMMON_SOURCE_FILES} test/main.cpp test/logging.cpp)
  target_link_libraries(logging_tests ${LIBCXX_LIBRARY} ${GTEST_BOTH_LIBRARIES} ${CMAKE_THREAD_LIBS_INIT} ${STATIC_LIBRT})
  set_target_properties(logging_tests PROPERTIES COMPILE_DEFINITIONS _UNIT_TEST_BUILD)
  add_test(unit logging_tests)

  if (COVERAGE)
    setup_target_for_coverage(coverage logging_tests CMakeFiles/logging_tests.dir/src coverage)
  endif()

  if (COVERALLS)
    setup_target_for_coveralls(coveralls logging_tests src)
  endif()
endif()
