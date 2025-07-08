#!/usr/bin/env bash

#set -x

if [ "$(uname)" == "Darwin" ]; then
    SCRIPT=$(greadlink -f "$0");
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    SCRIPT=$(readlink -f "$0");
else
    SCRIPT=$(readlink -f "$0");
fi

export SCRIPTPATH=$(dirname "$SCRIPT");
source "$SCRIPTPATH/iwaralib.sh";
export DOWNLOAD_FAILED_LIST=();
export IWARA_IGNORE=();
export DOWNLOADED_ID_LIST=();
export DOWNLOADING_ID_LIST=();
export ENABLE_CONTINUE="--continue-at -";
export ENABLE_SLEEP="TRUE";
export USE_CF_CURL="FALSE";

trap '
  trap - INT # restore default INT handler
  kill -s INT "$$"
' INT

usage() {
    cat - <<EOF
usage: iwara-dl.sh [-u [U]] [-p [P]] [-i [n]] [-rhftcsdn] [-F [M]] [-l [f]] [url [url ...]]

positional arguments:
  url

optional arguments:
  -h --help                 show this help message and exit
  --username [U]            username
  --userpass [P]            password
  --load-ignore-list [File] load the list in file that should not download
  -r --retry [Count]        try to redownload the video at most [Count] times if not download completely
  --user                    treat input url as usernames
  --max-page [Maxpage]      only download users' videos from page 1 to [Maxpage]
  --cduser-dir              cd to each user directory
  --quiet-mode              quiet mode
  --login                   log in upfront
  --accept-insecure         accept insecure https connection
  --disable-continue        make all video download from start
  --disable-sleep           do not add sleep when download a list of video
  --name-only               output downloaded file name only(hides curl download bar)
  --use-cf-curl             use this option if you hit cloudfront's bot protection (requires uv installed)

  --shallow-update          only download users first page
  --updater-v1              cd to each username folder; update each folder;
  --updater-v2              create ./dl/ folder and update;

  --rm [File]               add a name to iwara ignore list and delete the file

  --follow  [M]             Download videos of people you are following. M:MaxPage
  --dl-list [f]             Download using the VideoID in the [F] VideoID List file.

extra:
  .iwara_ignore file => newline-saperated list of filenames of skipping download
  dl/.iwara_downloaded file => newline-saperated list of VideoID of skipping download

EOF
}

PARSE_AS="";

while true; do
    case "$1" in
        -h | --help ) usage; exit 01 ;;
        --rm )
            IGN_NAME="$2";
            echo "$IGN_NAME" >> .iwara_ignore;
            rm -v *"$IGN_NAME"*;
            exit 0; ;;

        --username ) IWARA_USER="$2"; shift 2; ;;
        --userpass ) IWARA_PASS="$2"; shift 2; ;;
        --load-ignore-list )
            add-iwara-ignore-list "$2";
            shift 2; ;;

        --use-cf-curl )
            export USE_CF_CURL="TRUE";
            shift; ;;

        --login )
            iwara-login;
            shift; ;;

        -r | --retry )
            export RETRY_COUNT=0;
            export MAX_RETRY_COUNT="$2";
            export IWARA_RETRY="TRUE";
            shift 2; ;;

        --user )
            export PARSE_AS="username";
            shift; ;;
        
        --max-page )
            export MAX_PAGE="$2"
            shift 2; ;;

        --cduser-dir )
            export CDUSER="TRUE";
            export CREATE_USER_DIR="TRUE";
            shift; ;;

        --quiet-mode )
            export IWARA_QUIET="TRUE";
            shift; ;;

        --shallow-update )
            export SHALLOW_UPDATE="TRUE";
            shift; ;;

        --accept-insecure )
            export CURL_ACCEPT_INSECURE_CONNECTION="--insecure";
            shift; ;;

        --disable-continue )
            export ENABLE_CONTINUE="";
            shift; ;;

        --disable-sleep )
            export ENABLE_SLEEP="FALSE";
            shift; ;;

        --name-only )
            export PRINT_NAME_ONLY="--silent";
            shift; ;;

        --updater-v1 )
            export CDUSER="TRUE";
            export SHALLOW_UPDATE="TRUE";
            export PARSE_AS="username";
            update_list=()
            for d in */ ; do update_list+=("${d::-1}"); done

            shift; ;;

        --updater-v2 )
            export ENABLE_UPDATER_V2="TRUE";
            mkdir -p dl;
            cd dl;

            shift; ;;

        --follow )
            export ENABLE_UPDATER_V2="TRUE";
            shift 2; ;;

        --dl-list )
            export PARSE_AS="videoidListfile";
            export ENABLE_UPDATER_V2="TRUE";
            export VIDEO_ID_LIST_FILE="$2";
            load_downloading_id_list $VIDEO_ID_LIST_FILE;
            shift; ;;

        -- ) shift; break ;;
        * ) break ;;
    esac
done

args=("$@")
for u in "${update_list[@]}"; do
    args+=("$u");
done

if [[ "${PARSE_AS}" == "following" ]]; then
    expr "$FOLLOWING_MAXPAGE" + 1 >&/dev/null
    if ! [ $? -lt 2 ]; then
        echo "Missing [MaxPage]";
        exit 0;
    fi
elif [[ "${PARSE_AS}" == "videoidListfile" ]]; then
    if ! [ -e $VIDEO_ID_LIST_FILE ]; then
        echo "Missing [VideoID List File]" ;
        exit 0;
    fi
    load_downloading_id_list $VIDEO_ID_LIST_FILE
elif ! (( $(calc-argc "${args[@]}") )); then
    echo "Missing [urls/ids]";
    exit 0;
fi

load-downloaded-id-list ".iwara_downloaded"

if [[ "${PARSE_AS}" == "username" ]]; then
    for user in "${args[@]}"; do
        echo "[[$user]]"
        if [[ -f ".iwara_ignore" ]]; then
            add-iwara-ignore-list ".iwara_ignore"
        fi

        if [[ "$CDUSER" ]]; then
            if [[ "$CREATE_USER_DIR" == "TRUE" ]]; then
                mkdir -p "$user";
            fi

            cd "$user" || { echo "Skip user [$user]"; continue; }
            if [[ -f ".iwara_ignore" ]]; then
                add-iwara-ignore-list ".iwara_ignore"
            fi

            if [[ "$SHALLOW_UPDATE" == "TRUE" ]]; then
                iwara-dl-update-user "$user" "0";
            else
                iwara-dl-update-user "$user";
            fi
            iwara-dl-retry-dl;
            cd "$OLDPWD" || exit 1
        else
            iwara-dl-update-user "$user"
            iwara-dl-retry-dl
        fi
    done
elif [[ "${PARSE_AS}" == "following" ]]; then
    iwara-dl-subscriptions
elif [[ "${PARSE_AS}" == "videoidListfile" ]]; then
    iwara-dl-videoidlistfile
else
    for url in "${args[@]}"; do
        if [[ "$url" == *"iwara.tv/video"* ]]; then
            iwara-dl-by-videoid $(url-get-id "$url")
        elif [[ "$url" == *"iwara.tv/playlist"* ]]; then
            iwara-dl-by-playlist $(url-get-id "$url")
        else
            iwara-dl-by-videoid "$url"
        fi
    done
fi

iwara-dl-retry-dl
