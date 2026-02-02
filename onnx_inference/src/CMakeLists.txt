# ONNX 推理插件 CMakeLists
cmake_minimum_required(VERSION 3.10)

project(onnx_inference_library VERSION 0.0.1 LANGUAGES CXX)

# 源文件
set(SOURCES
  "onnx_inference.cpp"
  "onnx_inference_utils.cpp"
)

add_library(onnx_inference SHARED ${SOURCES})

set_target_properties(onnx_inference PROPERTIES
  PUBLIC_HEADER onnx_inference.h
  OUTPUT_NAME "onnx_inference"
  CXX_STANDARD 17
  CXX_STANDARD_REQUIRED ON
)

target_compile_definitions(onnx_inference PUBLIC DART_SHARED_LIB)

find_package(Threads REQUIRED)
target_link_libraries(onnx_inference PRIVATE Threads::Threads)

# 查找 ONNX Runtime
# 首先尝试查找系统安装的 ONNX Runtime
find_library(ONNXRUNTIME_LIB NAMES onnxruntime
  PATHS
    /usr/local/lib
    /usr/lib
    /opt/onnxruntime/lib
    $ENV{HOME}/onnxruntime/lib
  NO_DEFAULT_PATH
)

find_path(ONNXRUNTIME_INCLUDE_DIR NAMES onnxruntime_c_api.h
  PATHS
    /usr/local/include
    /usr/include
    /opt/onnxruntime/include
    $ENV{HOME}/onnxruntime/include
  NO_DEFAULT_PATH
)

if(ONNXRUNTIME_LIB AND ONNXRUNTIME_INCLUDE_DIR)
  message(STATUS "找到 ONNX Runtime: ${ONNXRUNTIME_LIB}")
  message(STATUS "ONNX Runtime 头文件: ${ONNXRUNTIME_INCLUDE_DIR}")
  
  target_include_directories(onnx_inference PRIVATE ${ONNXRUNTIME_INCLUDE_DIR})
  target_link_libraries(onnx_inference PRIVATE ${ONNXRUNTIME_LIB})
else()
  message(WARNING "未找到 ONNX Runtime - 插件将编译但无法运行")
  message(WARNING "安装 ONNX Runtime: https://github.com/microsoft/onnxruntime/releases")
  
  # 创建空实现
  target_compile_definitions(onnx_inference PRIVATE ONNX_RUNTIME_NOT_FOUND)
endif()

if (ANDROID)
  # 支持 Android 15 16k 页面大小
  target_link_options(onnx_inference PRIVATE "-Wl,-z,max-page-size=16384")
endif()

option(ONNX_INFERENCE_BUILD_TESTS "Build native tests" OFF)

if (ONNX_INFERENCE_BUILD_TESTS)
  enable_testing()
  add_executable(onnx_inference_utils_test
    "${CMAKE_CURRENT_LIST_DIR}/../tests/onnx_inference_utils_test.cpp"
    "onnx_inference_utils.cpp"
  )
  target_include_directories(onnx_inference_utils_test PRIVATE
    "${CMAKE_CURRENT_LIST_DIR}"
  )
  add_test(NAME onnx_inference_utils_test
    COMMAND onnx_inference_utils_test
  )

  add_executable(onnx_inference_stub_test
    "${CMAKE_CURRENT_LIST_DIR}/../tests/onnx_inference_stub_test.cpp"
    "onnx_inference.cpp"
  )
  target_include_directories(onnx_inference_stub_test PRIVATE
    "${CMAKE_CURRENT_LIST_DIR}"
  )
  target_compile_definitions(onnx_inference_stub_test PRIVATE
    ONNX_RUNTIME_NOT_FOUND
  )
  add_test(NAME onnx_inference_stub_test
    COMMAND onnx_inference_stub_test
  )
endif()
