#!/usr/bin/env bash

if [ "$(uname)" == "Darwin" ]; then
    SCRIPT=$(greadlink -f "$0");
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    SCRIPT=$(readlink -f "$0");
fi

export SCRIPTPATH=$(dirname "$SCRIPT");
source "$SCRIPTPATH/iwaralib.sh";
IWARA_HTTP_REQUEST='-X PUT'

trap '
  trap - INT # restore default INT handler
  kill -s INT "$$"
' INT

iwara-friend()
{
    local friendid=$1
    local output=$(curl 'https://ecchi.iwara.tv/api/user/friends' \
                        --silent ${IWARA_HTTP_REQUEST} ${SESSION} --data "frid=${friendid}")
    local ok=$(echo "$output" | jq ".status")
    if [[ "$ok" != "1" ]]; then
        echo "Error happened: ${output}"
    fi
}

iwara-all-request()
{
    local max_page=$1
    accept_counter=0
    for i in $(eval echo "{0..$max_page}"); do
        get-html-from-url "https://ecchi.iwara.tv/user/friends?page=${i}"
        IFS='`' read -ra ids <<< $(echo "$HTML" | python3 -c "$PYCHECK page.find_pending_user_list(html);")
        for id in "${ids[@]}"; do
            iwara-friend "${id}"
            accept_counter=$((accept_counter + 1))
        done
    done
    if [[ "$IWARA_HTTP_REQUEST" == "-X PUT" ]]; then
        echo "${accept_counter} requests are accepted"
    elif [[ "$IWARA_HTTP_REQUEST" == "-X DELETE" ]]; then
        echo "${accept_counter} requests are deleted"
    fi
}

while getopts "x" argv; do
    case $argv in
        x)
            IWARA_HTTP_REQUEST='-X DELETE'
            ;;
    esac
done
shift $((OPTIND-1))

iwara-login

if [[ "$IWARA_USER" == "" ]] || [[ "${SESSION}" == *"script"* ]]; then
    echo "Cannot login as '$IWARA_USER'. Exiting"
    exit 1
fi


get-html-from-url "https://ecchi.iwara.tv/user/friends"
max_page=$(echo "$HTML" | python3 -c "$PYCHECK page.find_max_user_video_page(html);")
echo "Parsing friend page 0 -> $max_page"

iwara-all-request "$max_page"
