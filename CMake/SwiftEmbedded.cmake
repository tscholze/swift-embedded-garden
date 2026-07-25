# Helper to compile Swift Embedded sources into a single object file.
# Keep flags in one place so adding new Swift source files or tuning code size
# does not require duplicating command logic.

function(compile_swift_embedded_object)
  set(options)
  set(oneValueArgs TARGET_NAME OUTPUT_OBJECT)
  set(multiValueArgs SOURCES)
  cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

  if(NOT ARG_TARGET_NAME)
    message(FATAL_ERROR "compile_swift_embedded_object requires TARGET_NAME.")
  endif()

  if(NOT ARG_OUTPUT_OBJECT)
    message(FATAL_ERROR "compile_swift_embedded_object requires OUTPUT_OBJECT.")
  endif()

  if(NOT ARG_SOURCES)
    message(FATAL_ERROR "compile_swift_embedded_object requires SOURCES.")
  endif()

  if(NOT DEFINED SWIFT_EXECUTABLE)
    find_program(SWIFT_EXECUTABLE swiftc REQUIRED)
  endif()

  get_filename_component(SWIFT_OUTPUT_DIR "${ARG_OUTPUT_OBJECT}" DIRECTORY)
  file(MAKE_DIRECTORY "${SWIFT_OUTPUT_DIR}")

  add_custom_command(
    OUTPUT "${ARG_OUTPUT_OBJECT}"
    COMMAND "${SWIFT_EXECUTABLE}"
      -target armv6m-none-none-eabi
      -enable-experimental-feature Embedded
      -parse-as-library
      -wmo
      -Osize
      -emit-object
      -module-name PicoBlink
      ${ARG_SOURCES}
      -o "${ARG_OUTPUT_OBJECT}"
    DEPENDS ${ARG_SOURCES}
    VERBATIM
    COMMENT "Compiling Swift Embedded object: ${ARG_OUTPUT_OBJECT}"
  )

  add_custom_target(${ARG_TARGET_NAME} DEPENDS "${ARG_OUTPUT_OBJECT}")
endfunction()
