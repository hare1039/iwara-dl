#!/usr/bin/env bash

if [ "$(uname)" == "Darwin" ]; then
    SCRIPT=$(greadlink -f "$0");
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    SCRIPT=$(readlink -f "$0");
fi

export SCRIPTPATH=$(dirname "$SCRIPT");
source "$SCRIPTPATH/iwaralib.sh";

trap '
  trap - INT # restore default INT handler
  kill -s INT "$$"
' INT

iwara-accept-friend()
{
    local friendid=$1
    local output=$(curl 'https://ecchi.iwara.tv/api/user/friends' \
                        --silent -X PUT ${SESSION} --data "frid=${friendid}")
    local ok=$(echo "$output" | jq ".status")
    if [[ "$ok" != "1" ]]; then
        echo "Error happened: ${output}"
    fi
}

iwara-login
get-html-from-url "https://ecchi.iwara.tv/user/friends"
max_page=$(echo "$HTML" | python3 -c "$PYCHECK page.find_max_user_video_page(html);")
echo "Parsing 0 -> $max_page in user page"

accept_counter=0
for i in $(eval echo "{0..$max_page}"); do
    get-html-from-url "https://ecchi.iwara.tv/user/friends?page=${i}"
    IFS='`' read -ra ids <<< $(echo "$HTML" | python3 -c "$PYCHECK page.find_pending_user_list(html);")
    for id in "${ids[@]}"; do
        iwara-accept-friend "${id}"
        accept_counter=$((accept_counter + 1))
    done
done
echo "${accept_counter} people are accepted as your new friend"
