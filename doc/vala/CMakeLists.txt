if(XSLTPROC_EXECUTABLE OR NOT VALA_MUST_BOOTSTRAP)
  set(BOOK_SOURCES
    index.xml
    overview.xml
    types.xml
    expressions.xml
    statements.xml
    namespaces.xml
    methods.xml
    classes.xml
    structs.xml
    interfaces.xml
    enums.xml
    delegates.xml
    exceptions.xml
    attributes.xml
    )
  if(VALA_USE_XSLTPROC)
    # compile from sources

    configure_file(default.css
      "${CMAKE_CURRENT_BINARY_DIR}/default.css" COPYONLY)

    # construct html output names
    string(REGEX REPLACE "([^;]+)\\.xml" "${CMAKE_CURRENT_BINARY_DIR}/\\1.html"
      BOOK_OUTPUT "${BOOK_SOURCES}")

    # run xml sources through xsltproc for html output
    add_custom_command(OUTPUT ${BOOK_OUTPUT}
      COMMAND "${XSLTPROC_EXECUTABLE}"
      --output "${CMAKE_CURRENT_BINARY_DIR}/index.html"
      --xinclude "${CMAKE_CURRENT_SOURCE_DIR}/xhtml.xsl"
      "${CMAKE_CURRENT_SOURCE_DIR}/index.xml"
      DEPENDS ${BOOK_SOURCES} xhtml.xsl
      COMMENT "Generating HTML doc"
      VERBATIM
      )

    # run through xsltproc for devhelp index
    set(DEVHELP_OUTPUT "${CMAKE_CURRENT_BINARY_DIR}/vala.devhelp2")
    add_custom_command(OUTPUT "${DEVHELP_OUTPUT}"
      COMMAND "${XSLTPROC_EXECUTABLE}"
      --output "${CMAKE_CURRENT_BINARY_DIR}/vala.devhelp2"
      --xinclude "${CMAKE_CURRENT_SOURCE_DIR}/devhelp.xsl"
      "${CMAKE_CURRENT_SOURCE_DIR}/index.xml"
      DEPENDS ${BOOK_SOURCES} devhelp.xsl
      COMMENT "Generating devhelp doc"
      VERBATIM
      )

    # add convenience target
    add_custom_target(doc ALL DEPENDS
      ${BOOK_OUTPUT}
      "${CMAKE_CURRENT_BINARY_DIR}/vala.devhelp2"
      )

    # set up for self-contained distribution
    _vala_create_self_contained(book "${CMAKE_CURRENT_SOURCE_DIR}/generated"
      "${BOOK_OUTPUT};${DEVHELP_OUTPUT}" "" "")
  else()
    # use distributed html and devhelp
    string(REGEX REPLACE "([^;]+)\\.xml"
      "${CMAKE_CURRENT_SOURCE_DIR}/generated/\\1.html"
      BOOK_OUTPUT "${BOOK_SOURCES}")
    set(DEVHELP_OUTPUT "${CMAKE_CURRENT_SOURCE_DIR}/generated/vala.devhelp2")
  endif()

  # install the docs
  install(FILES
    ${BOOK_OUTPUT}
    "${DEVHELP_OUTPUT}"
    default.css
    DESTINATION "${VALA_DATA_DIR}/devhelp/books/vala"
    )
endif()
