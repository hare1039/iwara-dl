# iwara-dl

This program downloads `iwara.tv` videos.

For setup on windows 11: please follow this [guide](./WSL.md)

To-do list:
- [x] Download by id
- [x] Login
- [x] Download by user
- [x] Updater V1
- [x] Download by playlist
- [ ] Updater V2
- [ ] Download by subscription

# Dependency
```
bash
curl
jq
nkf
```

# Usage:
```
usage: iwara-dl.sh [-u [U]] [-p [P]] [-i [n]] [-rhftcsdn] [-F [M]] [-l [f]] [url [url ...]]

positional arguments:
  url

optional arguments:
  -h --help                 show this help message and exit
  --username [U]            username
  --userpass [P]            password
  --load-ignore-list [File] load the list in file that should not download
  -r --resume               try resume download
  --retry [count]           Max time to retry the download fail
  --user                    treat input url as usernames
  --quiet-mode              quiet mode
  --login                   log in upfront
  --accept-insecure         accept insecure https connection
  --name-only               output downloaded file name only(hides curl download bar)

  --shallow-update          only download users first page
  --updater-v1              cd to each username folder; update each folder;
  --updater-v2              create ./dl/ folder and update;

  --rm [File]               add a name to iwara ignore list and delete the file

  --follow  [M]             Download videos of people you are following. M:MaxPage
  --dl-list [f]             Download using the VideoID in the [F] VideoID List file.

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
