PYCHECK="import sys; html=sys.stdin.read(); import os; os.chdir('${SCRIPTPATH}'); import lib as page;"

echox() { if ! [[ "$IWARA_QUIET" ]]; then echo $*; fi }

iwara-login()
{
    if ! [[ "${SESSION}" ]]; then
        SESSION=$(curl 'https://ecchi.iwara.tv/user/login' -v \
                       --data "name=${IWARA_USER}&pass=${IWARA_PASS}&form_build_id=form-jacky&form_id=user_login&op=%E3%83%AD%E3%82%B0%E3%82%A4%E3%83%B3" 2>&1 \
                      | grep cookie | awk '{print $3}')
        SESSION="-HCookie:${SESSION::-1}"
    fi
}

get-html-from-url()
{
    local URL=$1
    HTML=$(curl ${SESSION} "$URL" --silent)

    if [[ "${IWARA_USER}" ]] && echo $HTML | python3 -c "$PYCHECK page.is_private(html);"; then
        echox "${videoid} looks like private video. Logging in..."
        iwara-login
        HTML=$(curl ${SESSION} "https://ecchi.iwara.tv/videos/${videoid}" --silent)
    fi
}

iwara-dl-by-videoid()
{
    local videoid=$1
    get-html-from-url "https://ecchi.iwara.tv/videos/${videoid}"
    local html=$HTML

    if echo "$html" | python3 -c "$PYCHECK page.is_youtube(html);" > /dev/null; then
        youtube-dl $(echo "$html" | python3 -c "$PYCHECK page.is_youtube(html);")
        return
    fi

    local title=$(echo "$html" | python3 -c "$PYCHECK page.parse_title(html);")
    local filename=$(sed 's/[:|/?";*<>]/-/g' <<< "${title}-${videoid}.mp4")
    if [[ -f "$filename" ]] && ! [[ "$RESUME_DL" ]]; then
        echox "$filename exist. Skip."
        return
    fi
    for row in $(curl --silent ${SESSION} "https://ecchi.iwara.tv/api/video/${videoid}" | jq -r ".[] | @base64"); do
        _jq() {
            echo ${row} | base64 --decode | jq -r ${1}
        }
        if [[ $(_jq ".resolution") == "Source" ]]; then
            echo "DL: $filename"
            echo "$html" | python3 -c "$PYCHECK page.grep_keywords(html);"
            curl --retry ${IWARA_RETRY} -C- ${SESSION} -o"$filename" "https:$(_jq '.uri')"
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
    get-html-from-url ${URL}
    local html=$HTML
    IFS='`' read -ra ids <<< $(echo "$html" | python3 -c "$PYCHECK page.find_videoid(html);")
    for id in ${ids[@]}; do
        iwara-dl-by-videoid ${id}
    done
}

iwara-dl-user()
{
    local username=$1
    get-html-from-url "https://ecchi.iwara.tv/users/${username}/videos"
    local html=$HTML
    local max_page=$(echo "$html" | python3 -c "$PYCHECK page.find_max_user_video_page(html);")
    if [[ "$2" ]]; then
        max_page=$2
    fi
    for i in {0..$max_page}; do
        iwara-dl-by-url "https://ecchi.iwara.tv/users/${username}/videos?page=${i}"
    done
}

iwara-dl-update-user()
{
    if [[ "$SHALLOW_UPDATE" ]]; then
        IWARA_QUIET="TRUE"
        iwara-dl-user $1 "0" # set $2(max_page) == 0
    else
        iwara-dl-user "$user"
    fi
}
