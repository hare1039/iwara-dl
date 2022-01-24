# iwara-dl

This program downloads `ecchi.iwara.tv` videos

For `iwara-friend` instructions, please go [here](https://github.com/hare1039/iwara-dl/blob/master/README-friend.md)

Why I rewrite this downloader? I just figure out that `selenium` is toooooo slow and `Requests` or `urllib3` from python3 are so hard to write comparing to `curl`

# Dependency
```
bash
curl
jq
python3 with BeautifulSoup
nkf
```

# Usage:
```
usage: iwara-dl.sh [-u [U]] [-p [P]] [-i [n]] [-rhftcsdn] [-F [M]] [url [url ...]]

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
  -i [n]   add a name to iwara ignore list and delete the file
  -F [M]   Download videos of people you are following. M:MaxPage

extra:
  .iwara_ignore file => newline-saperated list of filenames of skipping download
  dl/.iwara_downloaded file => newline-saperated list of VideoID of skipping download

```

```
# Download. Video page url, Video id, playlist, and user page are supported
iwara-dl.sh https://ecchi.iwara.tv/videos/ooxxzz

# You can also use env to set your login cred
IWARA_USER="Jacky" IWARA_PASS="password" iwara-dl.sh videoid
```
