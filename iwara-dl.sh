#!/usr/bin/env bash

if [ "$(uname)" == "Darwin" ]; then
    SCRIPT=$(greadlink -f "$0");
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    SCRIPT=$(readlink -f "$0");
fi

export SCRIPTPATH=$(dirname "$SCRIPT");
source "$SCRIPTPATH/iwaralib.sh";
export DOWNLOAD_FAILED_LIST=()
export IWARA_IGNORE=()

trap '
  trap - INT # restore default INT handler
  kill -s INT "$$"
' INT
usage() {
    cat - <<EOF
usage: iwara-dl.sh [-u [U]] [-p [P]] [-rhftcsdn] [url [url ...]]

positional arguments:
  url

optional arguments:
  -h       show this help message and exit
  -u [U]   username
  -p [P]   password
  -r       try resume download
  -f       do not retry on failed download
  -t       treat input url as usernames
  -c       cd to each username folder. Used only when specify -t
  -s       makes shallow update: quiet mode and only download users first page
  -d       generate list of names from current folder and try to update them all
           implies -t -c -s
  -n       output downloaded file name only(hides curl download bar)

extra:
  .iwara_ignore file => newline-saperated list of filenames of skipping download

EOF
}

while getopts "tu:p:csrhfdn" argv; do
    case $argv in
        t)
            PARSE_AS="username"
            ;;
        u)
            export IWARA_USER="${OPTARG}"
            ;;
        p)
            export IWARA_PASS="${OPTARG}"
            ;;
        c)
            CDUSER="TRUE"
            ;;
        s)
            export SHALLOW_UPDATE="TRUE"
            ;;
        r)
            export RESUME_DL="TRUE"
            export OPT_SET_RESUME_DL="TRUE"
            ;;
        f)
            export IWARA_RETRY="FALSE"
            ;;
        d)
            PARSE_AS="username"
            CDUSER="TRUE"
            export SHALLOW_UPDATE="TRUE"

            update_list=()
            for d in */ ; do update_list+=("${d::-1}"); done
            ;;
        n)
            export PRINT_NAME_ONLY="--silent"
            export IWARA_QUIET="TRUE"
            ;;
        h | *)
            usage
            exit
            ;;
    esac
done
shift $((OPTIND-1))

args=("$@")
for u in "${update_list[@]}"; do args+=("$u"); done

if ! (( $(calc-argc "${args[@]}") )); then
    echo "Missing [urls/ids]";
    exit 0;
fi

if [[ "${PARSE_AS}" == "username" ]]; then
    for user in "${args[@]}"; do
        echo "[[$user]]"
        if [[ -f ".iwara_ignore" ]]; then
            add_do_not_dl_list ".iwara_ignore"
        fi

        if [[ "$CDUSER" ]]; then
            cd "$user" || { echo "Skip user [$user]"; continue; }
            if [[ -f ".iwara_ignore" ]]; then
                add_do_not_dl_list ".iwara_ignore"
            fi
            iwara-dl-update-user "$user"
            iwara-dl-retry-dl
            cd "$OLDPWD" || exit 1
        else
            iwara-dl-update-user "$user"
            iwara-dl-retry-dl
        fi
    done
else
    for url in "${args[@]}"; do
        if [[ "$url" == *"iwara.tv/videos"* ]]; then
            iwara-dl-by-videoid $(url-get-id "$url")
        elif [[ "$url" == *"iwara.tv/users"* ]] ||
             [[ "$url" == *"iwara.tv/playlist"* ]]; then
            iwara-dl-by-url "$url"
        else
            iwara-dl-by-videoid "$url"
        fi
    done
fi

iwara-dl-retry-dl
