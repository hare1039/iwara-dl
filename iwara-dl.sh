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

while getopts “tnu:p:cs” argv
do
    case $argv in
        t)
            PARSE_AS="username"
            ;;
        u)
            export IWARA_USER=${OPTARG}
            ;;
        p)
            export IWARA_PASS=${OPTARG}
            ;;
        c)
            CDUSER="TRUE"
            ;;
        s)
            SHALLOW_UPDATE="TRUE"
            ;;
        *)
            exit
            ;;
    esac
done
shift $((OPTIND-1))

if [[ "${PARSE_AS}" == "username" ]]; then
    for user in "$@"; do
        echo "$user"
        if [[ "$CDUSER" ]]; then
            cd "$user"
            if [[ "$SHALLOW_UPDATE" ]]; then
                iwara-update-user "$user"
            else
                iwara-dl-user "$user"
            fi
            cd "$OLDPWD"
        else
            if [[ "$SHALLOW_UPDATE" ]]; then
                iwara-update-user "$user"
            else
                iwara-dl-user "$user"
            fi
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
