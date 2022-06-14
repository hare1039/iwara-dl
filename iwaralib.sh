#!/usr/bin/env bash
PYCHECK="import sys; html=sys.stdin.read(); import os; os.chdir('${SCRIPTPATH}'); import iwaralib as page;"

echox() { if ! [[ "$IWARA_QUIET" ]]; then echo "$@"; fi }

calc-argc()
{
    local argv_count=0
    for url in "$@"; do argv_count=$((V + 1)) ; done
    echo "$argv_count"
}

add_iwara_ignore_list()
{
    local listfile="$1"
    while read F  ; do
        if [[ "$F" != "" ]]; then
            IWARA_IGNORE+=("$F")
        fi
    done < "$listfile"
}

load_downloaded_id_list()
{
    local listfile="$1"
    if ! [[ -f "$listfile" ]]; then
        return;
    fi
    while read F  ; do
        if [[ "$F" != "" ]]; then
            DOWNLOADED_ID_LIST+=("$F")
        fi
    done < "$listfile"
}

load_downloading_id_list()
{
    local listfile="$1"
    if ! [[ -f "$listfile" ]]; then
        return;
    fi
    while read F  ; do
        if [[ "$F" != "" ]]; then
            DOWNLOADING_ID_LIST+=("$F")
        fi
    done < "$listfile"
}

add_downloaded_id()
{
    if [[ "$1" != "" ]]; then
        if [[ "$ENABLE_UPDATER_V2" == "TRUE" ]]; then
            echo "$1" >> .iwara_downloaded;
        fi
        DOWNLOADED_ID_LIST+=("$1")
    fi
}

is_in_iwara_ignore_list()
{
    local filename="$1"
    for ignorename in "${IWARA_IGNORE[@]}"; do
        if [[ "$filename" == *"$ignorename"* ]]; then
            true
            return
        fi
    done
    false
}

is_downloaded()
{
    local downloadid="$1"
    for downloaded_id in "${DOWNLOADED_ID_LIST[@]}"; do
        if [[ "$downloadid" == *"$downloaded_id"* ]]; then
            true
            return
        fi
    done
    false
}

iwara-login()
{
    if ! [[ "${IWARA_SESSION}" ]]; then
        echox "Logging in..."

        HTML=$(curl "https://ecchi.iwara.tv/user/login" --silent)
        local antibot=$(echo "$HTML" | python3 -c "$PYCHECK page.login_key(html);")
        IWARA_SESSION=$(curl 'https://ecchi.iwara.tv/user/login' -v \
                       --data "name=${IWARA_USER}&pass=${IWARA_PASS}&form_build_id=form-jacky&form_id=user_login&antibot_key=${antibot}&op=%E3%83%AD%E3%82%B0%E3%82%A4%E3%83%B3" 2>&1 \
                       | grep 'set-cookie' | awk '{print $3}' | sed 's/;//g')
        IWARA_SESSION="-HCookie:${IWARA_SESSION}"
        echox "Cookie:'$IWARA_SESSION'"
    fi
}

get-html-from-url()
{
    local URL=$1
    HTML=$(curl ${IWARA_SESSION} "$URL" --silent)

    if [[ "${IWARA_USER}" ]] && echo "$HTML" | python3 -c "$PYCHECK page.is_private(html);"; then
        echox "${videoid} looks like private video."
        iwara-login
        HTML=$(curl ${IWARA_SESSION} "https://ecchi.iwara.tv/videos/${videoid}" --silent)
    fi
}

iwara-dl-by-videoid()
{
    local videoid=$1

    if [[ "$videoid" == "" ]]; then
        echox 'Hey, I got a empty videoid!'
        return
    fi

    if is_downloaded "$videoid"; then
        echox "Skip: $videoid is in downloaded list."
        return
    fi

    get-html-from-url "https://ecchi.iwara.tv/videos/${videoid}"
    local html="$HTML"

    if echo "$html" | python3 -c "$PYCHECK page.is_youtube(html);" > /dev/null; then
        youtube-dl $(echo "$html" | python3 -c "$PYCHECK page.is_youtube(html);")
        add_downloaded_id "$videoid"
        return
    fi

    local title=$(echo "$html" | python3 -c "$PYCHECK page.parse_title(html);")
    if [[ "$title" == "" ]]; then
        echox "Skip: title missing at page ${videoid}."
        DOWNLOAD_FAILED_LIST+=("${videoid}")
        return
    fi
    local filename=$(sed $'s/[:|/?";*\\<>\t]/-/g' <<< "${title}-${videoid}.mp4")

    if [[ "$DIRECT_DL" == "TRUE" ]]; then
        local videousername=".";
    else
        IFS='`' read -ra ids <<< $(echo "$html" | python3 -c "$PYCHECK page.find_userid(html);")
        local tmp="${ids}"
        tmp=$(echo -n "$tmp" | nkf --url-input)
        local videousername=$(sed $'s/[:|/?";*\\<>\t]/-/g' <<< "${tmp}")
    fi

    if [[ -f "$filename" ]] && ! [[ "$RESUME_DL" ]]; then
        echo "Skip: $filename exist."
        add_downloaded_id "$videoid"
        return
    fi
    if [[ -f "$videousername/$filename" ]] && ! [[ "$RESUME_DL" ]]; then
        echox "Skip: $videousername/$filename exist."
        add_downloaded_id "$videoid"
        return
    fi
    if is_in_iwara_ignore_list "$filename"; then
        echox "Skip: $filename is in ignore list."
        add_downloaded_id "$videoid"
        return
    fi

    for row in $(curl --silent ${IWARA_SESSION} "https://ecchi.iwara.tv/api/video/${videoid}" | jq -r ".[] | @base64"); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }
        if [[ $(_jq ".resolution") == "Source" ]]; then
            echo "DL: $filename"
            echo "User: $videousername"

            local sleeptime=$(shuf -i 8-13 -n 1)
            echo "Sleep: $sleeptime sec"
            sleep "${sleeptime}s" 2>/dev/null;

            if [[ "$ENABLE_UPDATER_V2" == "TRUE" ]]; then
                local finalfilename="${videousername}/$filename";
            else
                local finalfilename="$filename";
            fi

            if ! curl -f --create-dirs -o "${finalfilename}" ${PRINT_NAME_ONLY} -C- ${IWARA_SESSION} "https:$(_jq '.uri')"; then
                DOWNLOAD_FAILED_LIST+=("${videoid}")
            else
                add_downloaded_id "$videoid"
            fi
        fi
    done
}

url-get-id()
{
    IFS='/' read -ra id <<< "$1"
    echo "${id[-1]}"
}

iwara-dl-by-url()
{
    local URL=$1
    get-html-from-url "${URL}"
    local html=$HTML
    IFS='`' read -ra ids <<< $(echo "$html" | python3 -c "$PYCHECK page.find_videoid(html);")
    for id in "${ids[@]}"; do
        iwara-dl-by-videoid "${id}"
    done
}

iwara-dl-user()
{
    local username="$1"
    get-html-from-url "https://ecchi.iwara.tv/users/${username}/videos"
    local html=$HTML
    local max_page=$(echo "$html" | python3 -c "$PYCHECK page.find_max_user_video_page(html);")
    if [[ "$2" ]]; then
        max_page=$2
    fi
    for i in $(eval echo "{0..$max_page}"); do
        iwara-dl-by-url "https://ecchi.iwara.tv/users/${username}/videos?page=${i}"
    done
}

iwara-dl-update-user()
{
    local user=$(printf "%s" "$1" | python3 -c "$PYCHECK page.encode(html);")
    if [[ "$SHALLOW_UPDATE" ]]; then
        IWARA_QUIET="TRUE"
        iwara-dl-user "$user" "0" # set $2(max_page) == 0
    else
        iwara-dl-user "$user"
    fi
}

iwara-dl-retry-dl()
{
    if (( ${#DOWNLOAD_FAILED_LIST[@]} )); then
        echo "Download failed on these videoid:"
        for id in "${DOWNLOAD_FAILED_LIST[@]}"; do
            echo "$id"
        done
        if [[ "$IWARA_RETRY" != "FALSE" ]] ; then
            echo "Try resuming..."
            export RESUME_DL="TRUE"
            for id in "${DOWNLOAD_FAILED_LIST[@]}"; do
                iwara-dl-by-videoid "$id"
            done
            if ! [[ "$OPT_SET_RESUME_DL" ]]; then
                unset RESUME_DL
            fi
            DOWNLOAD_FAILED_LIST=()
        fi
    fi
}

iwara-dl-subscriptions()
{
    iwara-login
    for i in $(eval echo "{0..${FOLLOWING_MAXPAGE}}"); do
        iwara-dl-by-url "https://ecchi.iwara.tv/subscriptions?page=${i}"
    done
}

iwara-dl-videoidlistfile()
{
    iwara-login
    for videoid in "${DOWNLOADING_ID_LIST[@]}"; do
        iwara-dl-by-videoid $videoid
    done
}
