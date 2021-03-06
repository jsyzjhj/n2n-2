project(n2n C)
cmake_minimum_required(VERSION 3.7)

# N2n information
set(N2N_VERSION 2.3.0)
set(N2N_OSNAME ${CMAKE_SYSTEM_NAME})

add_definitions(-DN2N_VERSION=\"${N2N_VERSION}\" -DN2N_OSNAME=\"${N2N_OSNAME}\")

# N2n specific params
if(NOT DEFINED N2N_OPTION_AES)
set(N2N_OPTION_AES OFF)
endif(NOT DEFINED N2N_OPTION_AES)

if(N2N_OPTION_AES)
add_definitions(-DN2N_HAVE_AES)
endif(N2N_OPTION_AES)

if(USE_GCRYPT)
        add_definitions(-DUSE_GCRYPT=1)
        set(CRYPTO_LIB gcrypt)
elseif(USE_NETTLE)
        add_definitions(-DUSE_NETTLE=1)
        set(CRYPTO_LIB nettle)
elseif(USE_MBEDTLS)
        add_definitions(-DUSE_MBEDTLS=1)
        set(CRYPTO_LIB mbedcrypto)
elseif(USE_OPENSSL)
        add_definitions(-DUSE_OPENSSL=1)
        set(CRYPTO_LIB crypto)
elseif(USE_ELL)
        add_definitions(-DUSE_ELL=1)
        set(CRYPTO_LIB dl ell)
elseif(DEFINED WIN32)
        add_definitions(-DUSE_BCRYPT=1)
        set(CRYPTO_LIB bcrypt)
endif()

# Build information
if(NOT DEFINED BUILD_SHARED_LIBS)
set(BUILD_SHARED_LIBS OFF)
endif(NOT DEFINED BUILD_SHARED_LIBS)

if(NOT DEFINED CMAKE_BUILD_TYPE)
set(CMAKE_BUILD_TYPE None)
endif(NOT DEFINED CMAKE_BUILD_TYPE)
#set(CMAKE_BUILD_TYPE Debug)
#set(CMAKE_BUILD_TYPE Release)

#Ultrasparc64 users experiencing SIGBUS should try the following gcc options
#(thanks to Robert Gibbon) 
#PLATOPTS_SPARC64=-mcpu=ultrasparc -pipe -fomit-frame-pointer -ffast-math -finline-functions -fweb -frename-registers -mapp-regs

## DEBUG FOR CMAKE
#message(${N2N_VERSION}) 
#message(${N2N_OSNAME})
##message(${CMAKE_BUILD_TYPE})
#message(${N2N_OPTION_AES})
## DEBUG FOR CMAKE

add_library(n2n OBJECT
        n2n.c
        wire.c
        version.c
)
set_property(TARGET n2n PROPERTY C_STANDARD 99)
set(OBJECTS $<TARGET_OBJECTS:n2n>)

if(DEFINED WIN32)
set(CMAKE_RC_FLAGS /nologo)
if (MSVC)
set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} /wd4477 /wd4267 /utf-8")
add_definitions(-D_CRT_SECURE_NO_WARNINGS -D_CRT_NONSTDC_NO_DEPRECATE)
endif(MSVC)

add_subdirectory(win32)
set(OBJECTS
        ${OBJECTS}
        $<TARGET_OBJECTS:n2n_win32>
        ${CMAKE_CURRENT_SOURCE_DIR}/win32/application.manifest
)
set(EDGE_RESOURCE ${CMAKE_CURRENT_SOURCE_DIR}/win32/edge.rc )
set(SN_RESOURCE ${CMAKE_CURRENT_SOURCE_DIR}/win32/sn.rc )

else(DEFINED WIN32)

set(EDGE_RESOURCE )
set(SN_RESOURCE )

endif(DEFINED WIN32)

add_executable(edge
        edge.c
        aes.c
        twofish.c
        transform_null.c
        transform_tf.c
        transform_aes.c
        n2n_keyfile.c
        minilzo.c
        tuntap_freebsd.c
        tuntap_netbsd.c
        tuntap_linux.c
        tuntap_osx.c
        ${OBJECTS} ${EDGE_RESOURCE}
)
if (${CMAKE_SYSTEM_NAME} MATCHES "Linux")
        target_link_libraries(edge cap)
endif()
set_property(TARGET edge PROPERTY C_STANDARD 99)

add_executable(supernode
        sn.c
        ${OBJECTS} ${SN_RESOURCE}
)
set_property(TARGET supernode PROPERTY C_STANDARD 99)

if(DEFINED WIN32)
set_target_properties(edge PROPERTIES LINK_FLAGS "/manifestuac:level='requireAdministrator'")
add_custom_command(
        TARGET supernode
        POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy "${CMAKE_CURRENT_SOURCE_DIR}/win32/install.ps1" "${CMAKE_CURRENT_BINARY_DIR}/install.ps1"
        DEPENDS "${CMAKE_CURRENT_SOURCE_DIR}/win32/install.ps1"
)
endif(DEFINED WIN32)

# For Solaris (or OpenSolaris?)
#target_link_libraries(edge socket nsl)
#target_link_libraries(supernode socket nsl)

if(N2N_OPTION_AES)
target_link_libraries(edge ${CRYPTO_LIB})
endif(N2N_OPTION_AES)

if(NOT DEFINED WIN32)
#add_executable(test test.c)
#target_link_libraries(test n2n)

#add_executable(benchmark benchmark.c)
#target_link_libraries(benchmark n2n)
endif(NOT DEFINED WIN32)

install(TARGETS edge supernode
        RUNTIME DESTINATION sbin
        LIBRARY DESTINATION lib
        ARCHIVE DESTINATION lib
)

# Documentation
if(DEFINED UNIX)
add_dependencies(n2n doc)
file(MAKE_DIRECTORY ${PROJECT_BINARY_DIR}/doc)
add_custom_command(OUTPUT ${PROJECT_BINARY_DIR}/doc/edge.8.gz
                   COMMAND gzip -c ${PROJECT_SOURCE_DIR}/edge.troff > ${PROJECT_BINARY_DIR}/doc/edge.8.gz
                   DEPENDS ${PROJECT_SOURCE_DIR}/edge.troff
                  )

add_custom_command(OUTPUT ${PROJECT_BINARY_DIR}/doc/supernode.1.gz
                   COMMAND gzip -c ${PROJECT_SOURCE_DIR}/supernode.troff > ${PROJECT_BINARY_DIR}/doc/supernode.1.gz
                   DEPENDS ${PROJECT_SOURCE_DIR}/supernode.troff
                  )

add_custom_command(OUTPUT ${PROJECT_BINARY_DIR}/doc/n2n_v2.7.gz
                   COMMAND gzip -c ${PROJECT_SOURCE_DIR}/n2n_v2.troff > ${PROJECT_BINARY_DIR}/doc/n2n_v2.7.gz
                   DEPENDS ${PROJECT_SOURCE_DIR}/n2n_v2.troff
                  )

add_custom_target(doc DEPENDS ${PROJECT_BINARY_DIR}/doc/edge.8.gz
                              ${PROJECT_BINARY_DIR}/doc/supernode.1.gz
                              ${PROJECT_BINARY_DIR}/doc/n2n_v2.7.gz
                 )

set_source_files_properties(${PROJECT_BINARY_DIR}/doc/edge.8.gz
                            ${PROJECT_BINARY_DIR}/doc/supernode.1.gz
                            ${PROJECT_BINARY_DIR}/doc/n2n_v2.7.gz
                            PROPERTIES GENERATED 1)

install(FILES ${PROJECT_BINARY_DIR}/doc/edge.8.gz
        DESTINATION /usr/share/man8)
install(FILES ${PROJECT_BINARY_DIR}/doc/supernode.1.gz
        DESTINATION /usr/share/man1)
install(FILES ${PROJECT_BINARY_DIR}/doc/n2n_v2.7.gz
        DESTINATION /usr/share/man7)
endif(DEFINED UNIX)
