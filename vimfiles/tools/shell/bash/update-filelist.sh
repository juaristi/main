#!/bin/bash

# create files
echo "Creating Filelist..."

# test posix regex
find . -maxdepth 1 -regextype posix-extended -regex "test" > /dev/null 2>&1
if test "$?" = "0"; then
    FORCE_POSIX_REGEX_1=""
    FORCE_POSIX_REGEX_2="-regextype posix-extended"
else
    FORCE_POSIX_REGEX_1="-E"
    FORCE_POSIX_REGEX_2=""
fi

# get filelist
echo "  |- generate ${TMP}"

# generate the argument list for find
FIND_ARGS="${FORCE_POSIX_REGEX_1} -type f -not -path */\.* ${FORCE_POSIX_REGEX_2}"

FOLDER_ARGS="${IS_EXCLUDE} -regex .*/("${FOLDERS}")/.* ${FORCE_POSIX_REGEX_2}"
FILE_ARGS="-regex .*\.("${FILE_SUFFIXS}")$"

scan_folder()
{
    if [ "$1" = "." ]; then
        echo "  |- scanning working directory"
    else
        echo "  |- scanning '$1'"
        if [ ! -d "$1" ]; then
            echo "ERROR: '$1' is not a directory"
            return 1
        fi
    fi

    if test "$2" != ""; then
        if [ $3 ]; then
            find $1 ${FIND_ARGS} ${FOLDER_ARGS} ${FILE_ARGS} >> "${TMP}"
        else
            find $1 ${FIND_ARGS} ${FOLDER_ARGS} ${FILE_ARGS} > "${TMP}"
        fi
        EXT="$1 ${FIND_ARGS} ${FOLDER_ARGS}"
    else
        if [ $3 ]; then
            find $1 ${FIND_ARGS} ${FILE_ARGS} >> "${TMP}"
        else
            find $1 ${FIND_ARGS} ${FILE_ARGS} > "${TMP}"
        fi
        EXT="$1 ${FIND_ARGS} ${FILE_ARGS}"
    fi

    if [[ "${FILE_SUFFIXS}" =~ __EMPTY__ ]]; then
        find ${EXT} \
        | grep  -v  "\.\w*$" \
        | xargs -i sh -c 'file="{}";type=$(file $file);[[ $type =~ "text" ]] && echo $file' \
        >> "${TMP}"
    fi
}

# first, scan the working directory
# apply the folder filters defined by the user
# this will overwrite the existing file list
scan_folder "." "${FOLDERS}" false

# now scan all the additional folders
# these are assumed to be out of the project tree
if [ -n "${ADDITIONAL_FOLDERS}" ]; then
    INDEX="1"
    CUR_DIR=""

    while true
    do
        AWK_CMD="BEGIN { FS = \",\" } { print \$${INDEX} }"
        CUR_DIR="$(echo ${ADDITIONAL_FOLDERS} | awk "${AWK_CMD}")"
        if [ -n "${CUR_DIR}" ]; then
            # we ignore folder filters here
            # append new entries to the existing file list
            scan_folder "${CUR_DIR}" "" true
            INDEX=$((${INDEX}+1))
        else
            break
        fi
    done
fi

# DISABLE
# # find . -type f -not -path "*/\.*" > "${TMP}"
# if [ -f "${TMP}" ]; then
#     echo "  |- filter by gawk ${TMP}"
#     gawk -v file_filter=${FILE_FILTER_PATTERN} -v folder_filter=${FOLDER_FILTER_PATTERN} -f "${TOOLS}/gawk/file-filter-${GAWK_SUFFIX}.awk" "${TMP}">"${TMP2}"
#     rm "${TMP}"
# fi


# replace old file
if [ -f "${TMP}" ]; then
    echo "  |- move ${TMP} to ${TARGET}"
    mv -f "${TMP}" "${TARGET}"
fi

if [ -f "${TARGET}" ]; then
    echo "  |- generate ${ID_TARGET}"
    gawk -f "${TOOLS}/gawk/null-terminal-files.awk" "${TARGET}">"${ID_TARGET}"
fi

echo "  |- done!"
