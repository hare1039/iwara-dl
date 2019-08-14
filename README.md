# iwara-dl

This program downloads `ecchi.iwara.tv` videos

For `iwara-friend` instructions, please go [here](https://github.com/hare1039/iwara-dl/blob/master/README-friend-func.md)

Why I rewrite this downloader? I just figure out that `selenium` is toooooo slow and `Requests` or `urllib3` from python3 are so hard to write comparing to `curl`

# Dependency
```
bash
curl
jq
python3 with BeautifulSoup
```

# Usage:
```
usage: iwara-dl.sh [-h] [-u [U]] [-p [P]] [-r] [-f] [-t] [-c] [-s] [url [url ...]]

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
```

```
# Download. Video page url, Video id, playlist, and user page are supported
iwara-dl.sh https://ecchi.iwara.tv/videos/ooxxzz

# You can also use env to set your login cred
IWARA_USER="Jacky" IWARA_PASS="password" iwara-dl.sh videoid
```
