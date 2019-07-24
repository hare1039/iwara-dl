if [ "$(uname)" == "Darwin" ]; then
    SCRIPT=$(greadlink -f "$0");
elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
    SCRIPT=$(readlink -f "$0");
fi

export SCRIPTPATH=$(dirname "$SCRIPT");
source $SCRIPTPATH/lib.sh;
#set -x

trap '
  trap - INT # restore default INT handler
  kill -s INT "$$"
' INT
usage() {
    cat - <<EOF
usage: iwara-dl.sh [-h] [-s] [-r] [-u [U]] [-p [P]] [-t] [-c] [url [url ...]]

positional arguments:
  url

optional arguments:
  -h       show this help message and exit
  -u [U]   username
  -p [P]   password
  -r       try resume download
  -t       treat input url as usernames
  -c       cd to each username folder. Used only when specify -t
  -s       makes shallow update: quiet mode and only download users first page
EOF
}


while getopts “tnu:p:csrh” argv
do
    case $argv in
        t)
            PARSE_AS="username"
            ;;
        u)
            IWARA_USER=${OPTARG}
            ;;
        p)
            IWARA_PASS=${OPTARG}
            ;;
        c)
            CDUSER="TRUE"
            ;;
        s)
            SHALLOW_UPDATE="TRUE"
            ;;
        r)
            RESUME_DL="TRUE"
            ;;
        * | h)
            usage
            exit
            ;;
    esac
done
shift $((OPTIND-1))

if [[ "${PARSE_AS}" == "username" ]]; then
    for user in "$@"; do
        echo "[$user]"
        if [[ "$CDUSER" ]]; then
            cd "$user"
            iwara-dl-update-user "$user"
            cd "$OLDPWD"
        else
            iwara-dl-update-user "$user"
        fi
    done
else
    for url in "$@"; do
        if [[ "$url" == *"iwara.tv/videos"* ]]; then
            iwara-dl-by-videoid $(url-get-id "$url")
        elif [[ "$url" == *"iwara.tv/users"* ]]; then
            iwara-dl-by-url "$url"
        else
            iwara-dl-by-videoid "$url"
        fi
    done
fi
