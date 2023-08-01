#!/usr/bin/env bash
PYCHECK="import sys; html=sys.stdin.read(); import os; os.chdir('${SCRIPTPATH}'); import iwaralib as page;"

echox() { if ! [[ "$IWARA_QUIET" ]]; then echo "$@"; fi }

calc-argc()
{
    local argv_count=0
    for url in "$@"; do argv_count=$((V + 1)) ; done
    echo "$argv_count"
}

add-iwara-ignore-list()
{
    local listfile="$1"
    while read F  ; do
        if [[ "$F" != "" ]]; then
            IWARA_IGNORE+=("$F")
        fi
    done < "$listfile"
}

load-downloaded-id-list()
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

load-downloading-id-list()
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

add-downloaded-id()
{
    if [[ "$1" != "" ]]; then
        if [[ "$ENABLE_UPDATER_V2" == "TRUE" ]]; then
            echo "$1" >> .iwara_downloaded;
        fi
        DOWNLOADED_ID_LIST+=("$1")
    fi
}

is-in-iwara-ignore-list()
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

is-downloaded()
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

        HTML=$(curl 'https://api.iwara.tv/user/login' \
                    -X POST -H 'Content-Type: application/json' \
                    --data-raw "{\"email\":\"${IWARA_USER}\",\"password\":\"${IWARA_PASS}\"}");

        token=$(echo $HTML | jq --raw-output '.token')
        IWARA_SESSION="--oauth2-bearer $token";
        echox "token:'$IWARA_SESSION'"
    fi
}

iwara-dl-by-videoid()
{
    local videoid=$1

    if [[ "$videoid" == "" ]]; then
        echox 'Hey, I got a empty videoid!'
        return
    fi

    if is-downloaded "$videoid"; then
        echox "Skip: $videoid is in downloaded list."
        return
    fi

    local video_stat=$(curl --silent ${IWARA_SESSION} https://api.iwara.tv/video/${videoid});
    local fileapi=$(echo $video_stat | jq --raw-output ".fileUrl");

    if [[ "$fileapi" == "null" ]]; then
        local message=$(echo $video_stat | jq --raw-output ".message");
        local body=$(echo $video_stat | jq --raw-output ".body");
        local embedUrl=$(echo $video_stat | jq --raw-output ".embedUrl");

        if [[ "$message" == "errors.privateVideo" ]] && [[ "$IWARA_SESSION" == "" ]]; then
            echo "looks like private video. try login ";
            iwara-login;
            iwara-dl-by-videoid $videoid;
        elif [[ "$body" == *"youtu.be"* ]]  || \
             [[ "$body" == *"youtube"*  ]]  || \
             [[ "$embedUrl" == *"youtu.be"* ]] || \
             [[ "$embedUrl" == *"youtube"*  ]]; then
            echo "Got a youtube link: $body. Skip. Welcome to contribute to implement this";
        else
            echo "Error: no such videoid ($videoid). Reply from api: $video_stat"
        fi
        return;
    fi
    # https://files.iwara.tv/file/b1764278-fe2e-4795-9e67-1fc85571ca78?expires=1680461922619&hash=d54eb4ff8b98f508557cec9b890f4a732de83b90ec4de6aa2f27abf300d01109
    local iwara_filename=$(echo $fileapi | sed -n 's/.*\/file\/\([^?]*\).*/\1/p');
    local iwara_expires=$(echo $fileapi | grep -o "expires=[0-9]*" | cut -d'=' -f2);
    local iwara_x_version=$(echo -n "${iwara_filename}_${iwara_expires}_5nFp9kmbNnHdAFhaqMvt" | sha1sum | awk '{print $1}');

    for row in $(curl --silent ${IWARA_SESSION} -H "X-Version: ${iwara_x_version}" "$fileapi" | jq -r ".[] | @base64"); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }

        if [[ $(_jq ".name") == "Source" ]]; then

            local title=$(echo $video_stat | jq --raw-output ".title");
            local videousername="$(echo $video_stat | jq --raw-output '.user.username')"
            local filename=$(sed $'s/[:|/?";*\\<>\t]/-/g' <<< "${title}-${videoid}.mp4");

            echo "DL: $filename"
            echo "User: $videousername"

            if [[ -n "$IWARA_DOWNLOADED" ]]; then
                local sleeptime=$(shuf -i 8-13 -n 1)
                echo "Sleep: $sleeptime sec"
                sleep "${sleeptime}s" 2>/dev/null;
            fi

            if [[ "$ENABLE_UPDATER_V2" == "TRUE" ]]; then
                local finalfilename="${videousername}/$filename";
            else
                local finalfilename="$filename";
            fi

            IWARA_DOWNLOADED="TRUE";
            local http_return_code=$(curl -f --create-dirs -o "${finalfilename}" $CURL_ACCEPT_INSECURE_CONNECTION ${PRINT_NAME_ONLY} --continue-at - --write-out "%{http_code}" ${IWARA_SESSION} "https:$(_jq '.src.download')");

            if [[ "$http_return_code" == "416" ]] || [[ "$http_return_code" == "200" ]]; then
                add-downloaded-id "$videoid";
            else
                echo "download failed. curl return: $http_return_code"
                DOWNLOAD_FAILED_LIST+=("${videoid}")
            fi
        fi
    done
}

url-get-id()
{
    IFS='/' read -ra id <<< "$1"
    echo "${id[-1]}"
}

iwara-dl-user()
{
    local username="$1";

    #https://api.iwara.tv/videos?page=0&sort=date&user=318e6b2c-6f55-4672-916b-f6227e429442
    local userid=$(curl --silent "https://api.iwara.tv/profile/$username" | jq --raw-output ".user.id");

    if [[ "$2" ]]; then
        max_page=$2
    else
        max_page=100
    fi

    for i in $(eval echo "{0..$max_page}"); do
        local json_array=$(curl --silent "https://api.iwara.tv/videos?page=$i&sort=date&user=$userid");

        local count=$(echo $json_array | jq '.results | length');

        for ((i=0; i<$count; i++)); do
            local id=$(echo $json_array | jq -r ".results[$i].id");
            iwara-dl-by-videoid "$id";
        done
    done
}

iwara-dl-update-user()
{
    user=$1;

    if [[ "$user" == "" ]]; then
        echo "no user?"
        return
    fi

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


# unfixed functions
iwara-dl-subscriptions()
{
    echo "Sorry. This function (iwara-dl-subscriptions) is still in the process of reimplementing because of the new website update";
    return ;

    iwara-login
    for i in $(eval echo "{0..${FOLLOWING_MAXPAGE}}"); do
        iwara-dl-by-url "https://ecchi.iwara.tv/subscriptions?page=${i}"
    done
}

iwara-dl-videoidlistfile()
{
    echo "Sorry. This function (iwara-dl-videoidlistfile) is still in the process of reimplementing because of the new website update";
    return ;

    iwara-login
    for videoid in "${DOWNLOADING_ID_LIST[@]}"; do
        iwara-dl-by-videoid $videoid
    done
}

iwara-dl-by-url()
{
    echo "Sorry. This function (iwara-dl-by-url) is still in the process of reimplementing because of the new website update";
    return ;
    local URL=$1
    get-html-from-url "${URL}"
    local html=$HTML
    IFS='`' read -ra ids <<< $(echo "$html" | python3 -c "$PYCHECK page.find_videoid(html);")
    for id in "${ids[@]}"; do
        iwara-dl-by-videoid "${id}"
    done
}

iwara-old-dl()
{
#    get-html-from-url "https://ecchi.iwara.tv/videos/${videoid}"
#    local html="$HTML"
#
#    if echo "$html" | python3 -c "$PYCHECK page.is_youtube(html);" > /dev/null; then
#        youtube-dl $(echo "$html" | python3 -c "$PYCHECK page.is_youtube(html);")
#        add-downloaded-id "$videoid"
#        return
#    fi
#
#    local title=$(echo "$html" | python3 -c "$PYCHECK page.parse_title(html);")
#    if [[ "$title" == "" ]]; then
#        echox "Skip: title missing at page ${videoid}."
#        DOWNLOAD_FAILED_LIST+=("${videoid}")
#        return
#    fi
#    local filename=$(sed $'s/[:|/?";*\\<>\t]/-/g' <<< "${title}-${videoid}.mp4")
#
#    if [[ "$DIRECT_DL" == "TRUE" ]]; then
#        local videousername=".";
#    else
#        IFS='`' read -ra ids <<< $(echo "$html" | python3 -c "$PYCHECK page.find_userid(html);")
#        local tmp="${ids}"
#        if command -v nkf &> /dev/null; then
#            tmp=$(echo -n "$tmp" | nkf --url-input);
#        else
#            tmp=$(echo -n "$tmp");
#        fi
#
#        local videousername=$(sed $'s/[:|/?";*\\<>\t]/-/g' <<< "${tmp}");
#    fi
#
#    if [[ -f "$filename" ]] && ! [[ "$RESUME_DL" ]]; then
#        echo "Skip: $filename exist."
#        add-downloaded-id "$videoid"
#        return
#    fi
#    if [[ -f "$videousername/$filename" ]] && ! [[ "$RESUME_DL" ]]; then
#        echox "Skip: $videousername/$filename exist."
#        add-downloaded-id "$videoid"
#        return
#    fi
#    if is-in-iwara-ignore-list "$filename"; then
#        echox "Skip: $filename is in ignore list."
#        add-downloaded-id "$videoid"
#        return
#    fi
#
#    for row in $(curl --silent ${IWARA_SESSION} "https://ecchi.iwara.tv/api/video/${videoid}" | jq -r ".[] | @base64"); do
#        _jq() {
#            echo ${row} | base64 --decode | jq -r ${1}
#        }
#        if [[ $(_jq ".resolution") == "Source" ]]; then
#            echo "DL: $filename"
#            echo "User: $videousername"
#
#            if [[ -n "$IWARA_DOWNLOADED" ]]; then
#                local sleeptime=$(shuf -i 8-13 -n 1)
#                echo "Sleep: $sleeptime sec"
#                sleep "${sleeptime}s" 2>/dev/null;
#            fi
#
#            if [[ "$ENABLE_UPDATER_V2" == "TRUE" ]]; then
#                local finalfilename="${videousername}/$filename";
#            else
#                local finalfilename="$filename";
#            fi
#
#            IWARA_DOWNLOADED="TRUE";
#            if ! curl -f --create-dirs -o "${finalfilename}" $CURL_ACCEPT_INSECURE_CONNECTION ${PRINT_NAME_ONLY} -C- ${IWARA_SESSION} "https:$(_jq '.uri')"; then
#                DOWNLOAD_FAILED_LIST+=("${videoid}")
#            else
#                add-downloaded-id "$videoid";
#            fi
#        fi
#    done
    echo should not call this function;
}
