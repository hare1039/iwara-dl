#!/usr/bin/env bash


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
        DOWNLOAD_FAILED_LIST=( ${DOWNLOAD_FAILED_LIST[*]/"$1"} )
    fi
}

add-failed-id()
{
    if [[ "$1" != "" ]]; then
        DOWNLOAD_FAILED_LIST=( ${DOWNLOAD_FAILED_LIST[*]/"$1"} )
        DOWNLOAD_FAILED_LIST+=("$1")
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

            echo "DL: $filename by $videousername"
            if is-in-iwara-ignore-list "$filename"; then
                echo "Skip: $filename is ignore by .iwara_ignore"
                continue
            fi

            if [[ "$ENABLE_SLEEP" == "TRUE" ]] && [[ -n "$IWARA_DOWNLOADED" ]]; then
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
            local http_return_code=$(curl -f --create-dirs -o "${finalfilename}" ${CURL_ACCEPT_INSECURE_CONNECTION} ${PRINT_NAME_ONLY} ${ENABLE_CONTINUE} --write-out "%{http_code}" ${IWARA_SESSION} "https:$(_jq '.src.download')");

            if [[ "$http_return_code" == "416" ]] || [[ "$http_return_code" == "200" ]]; then
                add-downloaded-id "$videoid";
            else
                echo "download failed. curl return: $http_return_code"
                add-failed-id "$videoid";
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
    local userid=$(curl ${IWARA_SESSION} --silent "https://api.iwara.tv/profile/$username" | jq --raw-output ".user.id");

    if [[ "$2" ]]; then
        max_page=$2
    else
        max_page=100
    fi

    for i in $(eval echo "{0..$max_page}"); do
        local json_array=$(curl ${IWARA_SESSION} --silent "https://api.iwara.tv/videos?page=$i&sort=date&user=$userid");

        local count=$(echo $json_array | jq '.results | length');

        if [[ "$count" == "0" ]]; then
            break;
        fi

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
    elif [[ "$MAX_PAGE" ]]; then
        iwara-dl-user "$user" "$MAX_PAGE"
    else
        iwara-dl-user "$user"
    fi
}

iwara-dl-retry-dl()
{
    if (( ${#DOWNLOAD_FAILED_LIST[@]} )); then
        if [[ "$IWARA_RETRY" == "TRUE" ]] ; then
            while [[ ${#DOWNLOAD_FAILED_LIST[@]} > 0 && $RETRY_COUNT < $MAX_RETRY_COUNT ]]; do
                RETRY_COUNT=$[$RETRY_COUNT+1]
                echo "Retry for the ${RETRY_COUNT} time. Downloads to be resumed:"
                for id in "${DOWNLOAD_FAILED_LIST[@]}"; do
                    echo "$id"
                done
                for id in "${DOWNLOAD_FAILED_LIST[@]}"; do
                    iwara-dl-by-videoid "$id"
                done
            done
            if [[ ${#DOWNLOAD_FAILED_LIST[@]} > 0 ]]; then
                echo "Unfinished videos after max times of trying:"
                for id in "${DOWNLOAD_FAILED_LIST[@]}"; do
                    echo "$id"
                done
            else
                echo "All videos completed"
            fi
        fi
    fi
}

iwara-dl-videoidlistfile()
{
    for videoid in "${DOWNLOADING_ID_LIST[@]}"; do
        iwara-dl-by-videoid $videoid
    done
}

iwara-dl-by-playlist()
{
    #https://www.iwara.tv/playlist/649ed6ff-a152-4957-849b-6e907c4c94c4
    local playlist_id=$1

    if [[ "$playlist_id" == "" ]]; then
        echo "empty playlist id?"
    fi

    if [[ "$2" ]]; then
        max_page=$2
    else
        max_page=100
    fi

    for i in $(eval echo "{0..$max_page}"); do
        local json_array=$(curl ${IWARA_SESSION} --silent "https://api.iwara.tv/playlist/${playlist_id}?page=$i");
        local count=$(echo $json_array | jq '.results | length');

        if [[ "$count" == "0" ]]; then
            break;
        fi

        for ((i=0; i<$count; i++)); do
            local id=$(echo $json_array | jq -r ".results[$i].id");
            iwara-dl-by-videoid "$id";
        done
    done
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
