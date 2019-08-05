if(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "WindowsStore")
    message(FATAL_ERROR "${PORT} does not currently support UWP")
endif()

if (VCPKG_LIBRARY_LINKAGE STREQUAL static)
  if(NOT VCPKG_CMAKE_SYSTEM_NAME)
    set(DLL_DECORATOR s)
  endif()
  set(MPC_STATIC_FLAG -static)
endif()

include(vcpkg_common_functions)


set(ACE_ROOT ${CURRENT_BUILDTREES_DIR}/src/ACE_wrappers)
set(TAO_ROOT ${ACE_ROOT}/tao)
set(ENV{ACE_ROOT} ${ACE_ROOT})
set(ENV{TAO_ROOT} ${TAO_ROOT})
set(QTDIR ${VCPKG_ROOT_DIR}/installed/${TARGET_TRIPLET})
#set(QTDIR "C:\\local\\Qt\\5.12.0\\msvc2017_64")
set(ENV{QTDIR} ${QTDIR})

set(ACE_SOURCE_PATH ${ACE_ROOT}/ace)
set(TAO_SOURCE_PATH ${TAO_ROOT}/tao)

set(INSTALLED_PATH ${VCPKG_ROOT_DIR}/installed/${TARGET_TRIPLET})
if(${CMAKE_BUILD_TYPE} MATCHES "^Debug$")
set(INSTALLED_PATH ${VCPKG_ROOT_DIR}/installed/${TARGET_TRIPLET}/debug)
endif()

set(SSL_ROOT ${INSTALLED_PATH})
set(ENV{SSL_ROOT} ${SSL_ROOT})
set(ENV{ZLIB_ROOT} ${INSTALLED_PATH})
set(ENV{BOOST_ROOT} ${INSTALLED_PATH})


vcpkg_download_distfile(ARCHIVE
    URLS "http://github.com/DOCGroup/ACE_TAO/releases/download/ACE%2BTAO-6_5_5/ACE+TAO-src-6.5.5.zip"
    FILENAME ACE+TAO-src-6.5.5.zip
    SHA512 888295877d498b85168cea7b199aba4805b920e9e9f3e65865e3190e5b00b1574c3b941b4a76bc7ef4c5d21d3dc03865cbc6f5286fea4c37643390fb211c76a2
)
vcpkg_extract_source_archive(${ARCHIVE})

# Acquire Perl and add it to PATH (for execution of MPC)
vcpkg_find_acquire_program(PERL)
get_filename_component(PERL_PATH ${PERL} DIRECTORY)
vcpkg_add_to_path(${PERL_PATH})

set(QT5_CORE_MPB_PATH "${CURRENT_BUILDTREES_DIR}/src/ACE_wrappers/MPC/config/qt5_core.mpb")
FILE(READ ${QT5_CORE_MPB_PATH} QT5_CORE_MPB_DATA)
STRING(REGEX REPLACE "QT5_BINDIR\\)\\/" "QTDIR)/tools/qt5/" NEW_QT5_CORE_MPB_DATA ${QT5_CORE_MPB_DATA})

STRING(REGEX REPLACE "libpaths \\+\\= \\$\\(QT5_LIBDIR\\)" "libpaths += $(QT5_LIBDIR) ${VCPKG_ROOT_DIR}/installed/${TARGET_TRIPLET}/debug/lib" NEW_QT5_CORE_MPB_DATA ${QT5_CORE_MPB_DATA})

FILE(WRITE ${QT5_CORE_MPB_PATH} "${NEW_QT5_CORE_MPB_DATA}")


if (TRIPLET_SYSTEM_ARCH MATCHES "arm")
    message(FATAL_ERROR "ARM is currently not supported.")
elseif (TRIPLET_SYSTEM_ARCH MATCHES "x86")
    set(MSBUILD_PLATFORM "Win32")
else ()
    set(MSBUILD_PLATFORM ${TRIPLET_SYSTEM_ARCH})
endif()

# Add ace/config.h file
# see https://htmlpreview.github.io/?https://github.com/DOCGroup/ACE_TAO/blob/master/ACE/ACE-INSTALL.html
if(NOT VCPKG_CMAKE_SYSTEM_NAME)
  set(LIB_RELEASE_SUFFIX .lib)
  set(LIB_DEBUG_SUFFIX d.lib)
  if(VCPKG_PLATFORM_TOOLSET MATCHES "v142")
    set(SOLUTION_TYPE vs2019)
  elseif(VCPKG_PLATFORM_TOOLSET MATCHES "v141")
    set(SOLUTION_TYPE vs2017)
  else()
    set(SOLUTION_TYPE vc14)
  endif()
  file(WRITE ${ACE_SOURCE_PATH}/config.h "#include \"ace/config-windows.h\"\n#define ACE_NO_INLINE")
endif()

if(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(DLL_DECORATOR)
  set(LIB_RELEASE_SUFFIX .a)
  set(LIB_DEBUG_SUFFIX .a)
  set(LIB_PREFIX lib)
  set(SOLUTION_TYPE gnuace)
  file(WRITE ${ACE_SOURCE_PATH}/config.h "#include \"ace/config-linux.h\"")
  file(WRITE ${ACE_ROOT}/include/makeinclude/platform_macros.GNU "include $(ACE_ROOT)include/makeinclude/platform_linux.GNU")
endif()

# Invoke mwc.pl to generate the necessary solution and project files
vcpkg_execute_required_process(
    COMMAND ${PERL} ${ACE_ROOT}/bin/mwc.pl -type ${SOLUTION_TYPE} tao_ace.mwc ${MPC_STATIC_FLAG} -features stl=1,boost=1,mfc=0,ace_for_tao=0,ace_inline=0,ssl=1,openssl11=0,qt5=1,zlib=1 -use_env -expand_vars
    WORKING_DIRECTORY ${TAO_ROOT}
    LOGNAME mwc-tao-${TARGET_TRIPLET}
)

# Build 
if(NOT VCPKG_CMAKE_SYSTEM_NAME) 
	vcpkg_build_msbuild(
		PROJECT_PATH ${TAO_ROOT}/tao_ace.sln 
		PLATFORM ${MSBUILD_PLATFORM}
		OPTIONS_DEBUG "/LIBPATH:${VCPKG_ROOT_DIR}/installed/${TARGET_TRIPLET}/debug/lib"
		)
endif()

if(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "Linux")
  FIND_PROGRAM(MAKE make)
  IF (NOT MAKE)
    MESSAGE(FATAL_ERROR "MAKE not found")
  ENDIF ()
  vcpkg_execute_required_process(
    COMMAND make
    WORKING_DIRECTORY ${ACE_ROOT}/ace
    LOGNAME make-${TARGET_TRIPLET}
  )
endif()

# Install include files
function(install_includes SOURCE_PATH SUBDIRECTORIES INCLUDE_DIR)
	foreach(SUB_DIR ${SUBDIRECTORIES})
		file(GLOB INCLUDE_FILES ${SOURCE_PATH}/${SUB_DIR}/*.h ${SOURCE_PATH}/${SUB_DIR}/*.inl ${SOURCE_PATH}/${SUB_DIR}/*.cpp)
		file(INSTALL ${INCLUDE_FILES} DESTINATION ${CURRENT_PACKAGES_DIR}/include/${INCLUDE_DIR}/${SUB_DIR})
	endforeach()
endfunction()

set(ACE_INCLUDE_FOLDERS "." "Compression" "Compression/rle" "ETCL" "QoS" "Monitor_Control" "os_include" "os_include/arpa" "os_include/net" "os_include/netinet" "os_include/sys")
install_includes(${ACE_SOURCE_PATH} "${ACE_INCLUDE_FOLDERS}" "ace")

set(TAO_INCLUDE_FOLDERS "." "AnyTypeCode" "BiDir_GIOP" "CodecFactory" "Codeset" "Compression" "Compression/bzip2" "Compression/lzo" "Compression/rle" "Compression/zlib"
    "CSD_Framework" "CSD_ThreadPool" "DiffServPolicy" "Dynamic_TP" "DynamicAny" "DynamicInterface" "EndpointPolicy" "EndpointPolicy" "ETCL" "FlResource" "FoxResource"
	"IFR_Client" "ImR_Client" "IORInterceptor" "IORManipulation" "IORTable" "Messaging" "Monitor" "ObjRefTemplate" "PI" "PI_Server" "PortableServer" "QtResource"
	"RTCORBA" "RTPortableServer" "RTScheduling" "SmartProxies" "Strategies" "TkResource" "TransportCurrent" "TypeCodeFactory" "Utils" "Valuetype" "XtResource" "ZIOP")
install_includes(${TAO_SOURCE_PATH} "${TAO_INCLUDE_FOLDERS}" "tao")

set(ORBSVCS_INCLUDE_FOLDERS "." "AV" "Concurrency" "CosEvent" "ESF" "FaultTolerance" "FtRtEvent/ClientORB" "FtRtEvent/EventChannel" "FtRtEvent/Utils" "HTIOP" "IFRService"
    "LifeCycle" "LoadBalancing" "Log" "Naming" "Naming/FaultTolerant" "Notify" "Notify/Any" "Notify/MonitorControl" "Notify/MonitorControlExt" "Notify/Sequence"
	"Notify/Structured" "PortableGroup" "Property" "Sched" "Security" "SSLIOP" "Time" "Trader")
install_includes(${TAO_ROOT}/orbsvcs/orbsvcs "${ORBSVCS_INCLUDE_FOLDERS}" "orbsvcs")


# Install libraries
function(install_libraries SOURCE_PATH LIBRARIES)
	foreach(LIBRARY ${LIBRARIES})
		set(LIB_PATH ${SOURCE_PATH}/lib/)
		
		if (VCPKG_LIBRARY_LINKAGE STREQUAL dynamic)
			# Install the DLL files
			file(INSTALL ${LIB_PATH}/${LIBRARY}d.dll DESTINATION ${CURRENT_PACKAGES_DIR}/debug/bin)
			file(INSTALL ${LIB_PATH}/${LIBRARY}.dll DESTINATION ${CURRENT_PACKAGES_DIR}/bin)
		endif()
		# Install the lib files
		file(INSTALL ${LIB_PATH}/${LIB_PREFIX}${LIBRARY}${DLL_DECORATOR}${LIB_DEBUG_SUFFIX} DESTINATION ${CURRENT_PACKAGES_DIR}/debug/lib)
		file(INSTALL ${LIB_PATH}/${LIB_PREFIX}${LIBRARY}${DLL_DECORATOR}${LIB_RELEASE_SUFFIX} DESTINATION ${CURRENT_PACKAGES_DIR}/lib)
	endforeach()
endfunction()

set(ACE_TAO_LIBRARIES "ACE" "ACE_Compression" "ACE_ETCL" "ACE_ETCL_Parser" "ACE_HTBP" "ACE_INet"
    "ACE_INet_SSL" "ACE_Monitor_Control" "ACE_QoS" "ACE_QtReactor" "ACE_RLECompression" "ACE_RMCast"
	"ACE_SSL" "ACE_TMCast" "ACEXML" "ACEXML_Parser" "Kokyu" "TAO" "TAO_AnyTypeCode" "TAO_Async_ImR_Client_IDL"
	"TAO_Async_IORTable" "TAO_AV" "TAO_BiDirGIOP" "TAO_Catior_i" "TAO_CodecFactory" "TAO_Codeset" 
	"TAO_Compression" "TAO_CosConcurrency" "TAO_CosConcurrency_Serv" "TAO_CosConcurrency_Skel" "TAO_CosEvent"
	"TAO_CosEvent_Serv"  "TAO_CosEvent_Skel" "TAO_CosLifeCycle" "TAO_CosLifeCycle_Skel" "TAO_CosLoadBalancing"
	"TAO_CosNaming" "TAO_CosNaming_Serv" "TAO_CosNaming_Skel" "TAO_CosNotification" "TAO_CosNotification_MC"
	"TAO_CosNotification_Serv" "TAO_CosNotification_Skel" "TAO_CosNotification_Persist" "TAO_CosProperty"
	"TAO_CosProperty_Serv" "TAO_CosProperty_Skel" "TAO_CosTime" "TAO_CosTime_Serv" "TAO_CosTrading"
	"TAO_CosTrading_Serv" "TAO_CosTrading_Skel" "TAO_CSD_Framework" "TAO_CSD_ThreadPool" "TAO_DiffServPolicy"
	"TAO_DsEventLogAdmin" "TAO_DsEventLogAdmin_Serv" "TAO_DsEventLogAdmin_Skel" "TAO_DsLogAdmin"
	"TAO_DsLogAdmin_Serv" "TAO_DsLogAdmin_Skel" "TAO_DsNotifyLogAdmin" "TAO_DsNotifyLogAdmin_Serv"
	"TAO_DsNotifyLogAdmin_Skel" "TAO_Dynamic_TP" "TAO_DynamicAny" "TAO_DynamicInterface" "TAO_EndpointPolicy"
	"TAO_ETCL" "TAO_FT_Naming_Serv" "TAO_FT_ServerORB" "TAO_FtNaming" "TAO_FtNamingReplication" 
	"TAO_FTORB_Utils" "TAO_FTRT_ClientORB" "TAO_FTRT_EventChannel" "TAO_FtRtEvent" "TAO_HTIOP" "TAO_IDL_BE"
	"TAO_IDL_FE" "TAO_IFR_BE" "TAO_IFR_Client" "TAO_IFR_Client_skel" "TAO_ImR_Activator_IDL" "TAO_ImR_Client"
	"TAO_ImR_Locator_IDL" "TAO_IORInterceptor" "TAO_IORManip" "TAO_IORTable" "TAO_Messaging" "TAO_Monitor"
	"TAO_Notify_Service" "TAO_ObjRefTemplate" "TAO_PI" "TAO_PI_Server" "TAO_PortableGroup" "TAO_PortableServer"
	"TAO_QtResource" "TAO_RLECompressor" "TAO_RT_Notification" "TAO_RTCORBA" "TAO_RTEvent" "TAO_RTEvent_Skel"
	"TAO_RTEventLogAdmin" "TAO_RTEventLogAdmin_Skel" "TAO_RTPortableServer" "TAO_RTSched" "TAO_RTScheduler"
	"TAO_Security" "TAO_SmartProxies" "TAO_SSLIOP" "TAO_Strategies" "TAO_Svc_Utils" "TAO_TC" "TAO_TC_IIOP"
	"TAO_TypeCodeFactory" "TAO_Utils" "TAO_Valuetype" "TAO_ZIOP" "TAO_ZlibCompressor")
install_libraries(${ACE_ROOT} "${ACE_TAO_LIBRARIES}")


# Install executables
function(install_tao_executables SOURCE_PATH EXE_FILE)
	set(EXECUTABLE_SUFFIX ".exe")
	if(VCPKG_CMAKE_SYSTEM_NAME STREQUAL "Linux")
		set(EXECUTABLE_SUFFIX "")
	endif()
	file(INSTALL ${ACE_ROOT}/bin/${EXE_FILE}${EXECUTABLE_SUFFIX} DESTINATION ${CURRENT_PACKAGES_DIR}/tools/ace-tao)
endfunction()

install_tao_executables(${ACE_ROOT}/bin "ace_gperf")
install_tao_executables(${ACE_ROOT}/bin "tao_catior")
install_tao_executables(${ACE_ROOT}/bin "tao_idl")
install_tao_executables(${ACE_ROOT}/bin "tao_ifr")
install_tao_executables(${ACE_ROOT}/bin "tao_imr")
install_tao_executables(${ACE_ROOT}/bin "tao_nsadd")
install_tao_executables(${ACE_ROOT}/bin "tao_nsdel")
install_tao_executables(${ACE_ROOT}/bin "tao_nsgroup")
install_tao_executables(${ACE_ROOT}/bin "tao_nslist")

file(INSTALL ${ACE_ROOT}/lib/ACEd.dll DESTINATION ${CURRENT_PACKAGES_DIR}/tools/ace-tao)
file(INSTALL ${ACE_ROOT}/lib/TAO_IDL_FEd.dll DESTINATION ${CURRENT_PACKAGES_DIR}/tools/ace-tao)
file(INSTALL ${ACE_ROOT}/lib/TAO_IDL_BEd.dll DESTINATION ${CURRENT_PACKAGES_DIR}/tools/ace-tao)

# Handle copyright
file(COPY ${ACE_ROOT}/COPYING DESTINATION ${CURRENT_PACKAGES_DIR}/share/ace-tao)
file(RENAME ${CURRENT_PACKAGES_DIR}/share/ace-tao/COPYING ${CURRENT_PACKAGES_DIR}/share/ace-tao/copyright)

vcpkg_copy_pdbs()
