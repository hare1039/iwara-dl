# iwara-dl

This program downloads `ecchi.iwara.tv` videos

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
  -s       makes shallow update: quiet mode and download users first page
```

```
# Download. Video page url, Video id, playlist, and user page are supported
iwara-dl.sh https://ecchi.iwara.tv/videos/ooxxzz

# You can also use env to set your login cred
IWARA_USER="Jacky" IWARA_PASS="password" iwara-dl.sh videoid
```
