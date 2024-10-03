[Running on windows]

As this tool is a `bash` script, so we need `bash` to execute.

Here is a complete step for running the tool on Windows.

1. Enable WSL (Windows Subsystem for Linux)

- Press `Windows key + R` and run `optionalfeatures`. Find Windows Subsystem for Linux and enable the feature.
![Alt text](https://filestore.community.support.microsoft.com/api/images/757cab71-c2fc-4351-8b5e-f062aeaa0ece)

- Install WSL from Windows command line. (Need to be admin. You should able to right click on windows icon and launch `cmd`) 

- After launch, install ubuntu by
```
wsl --install -d Ubuntu
```
<img width="735" alt="螢幕擷取畫面 2024-09-22 221024" src="https://github.com/user-attachments/assets/5a3b7ba7-b4ef-4ad5-b797-c2438bdc59c4">

Note: Make sure the Hypervisors and VM platform are also enabled if Ubuntu launch failed.

2. Install `iwara-dl` on WSL with dependency. Lets put the code into Windows' `Document folder`
```
sudo apt update;  ## update package manager
sudo apt install unzip jq curl nkf;   ## install dependency
cd /mnt/c/Users/hare1039/Documents/;  ## go to windows document
wget https://github.com/hare1039/iwara-dl/archive/refs/heads/master.zip; ## download this repo's master branch
unzip master.zip;   ## unzip code
rm master.zip;      ## delete zip
cd iwara-dl-master; ## go to code directory
```
<img width="735" alt="螢幕擷取畫面 2024-09-22 221640" src="https://github.com/user-attachments/assets/5f731d55-e9cd-400f-8ee5-679eb6d3d42d">

After install the dependency, you can check whether the install works ok or not:

<img width="735" alt="螢幕擷取畫面 2024-09-22 222539" src="https://github.com/user-attachments/assets/670fb104-bd4c-4e30-8d2c-1bc28b316fba">

You can see `iwara-dl` downloads the video, but the videos are inside the code directory. Lets setup some shortcut.

3. Setup shortcut
```
nano ~/.bashrc;

# And add
alias iwara-dl='IWARA_USER=hare1039 IWARA_PASS=password /mnt/c/Users/hare1039/Documents/iwara-dl-master/iwara-dl.sh'
# Ctrl-X and save the file

source ~/.bashrc
```

<img width="735" alt="螢幕擷取畫面 2024-09-22 223030" src="https://github.com/user-attachments/assets/c98e5ab7-36f3-4972-aff9-f826527715aa">
Now you should have your `iwara-dl` ready.

4. Lets test it:
```
cd /mnt/c/Users/hare1039/Downloads;
iwara-dl https://www.iwara.tv/playlist/8ae13720-750d-46f0-b8a4-0162daf4a439;
```

<img width="960" alt="螢幕擷取畫面 2024-09-22 223501" src="https://github.com/user-attachments/assets/10cf6a30-81d7-4b40-9d14-bea4cba70a1f">

Good if you see the videos in your downloads

