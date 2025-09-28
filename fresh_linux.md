# useful actions for fresh linux install

## ghostty terminal terminfo

From ghostty docs [https://ghostty.org/docs/help/terminfo]:
```
infocmp -x | ssh [hostname|ip] -- tic -x -
```

## useful packages

First update apt, download tmux (so longer upgrades can be done in detached mode) and some basic stuff, then upgrade:
```
sudo apt update
sudo apt install tmux git tree joe
```

Enter tmux session:
```
tmux
```

Upgrade everything:
```
sudo apt update
sudo apt upgrade
```

## when debootstrap - minimal Debian

### weird terminal/bash
Bash functionality could be missing, do:
```
sudo apt update
sudo apt install -y bash bash-completion readline-common
[ -f ~/.bashrc ] || cp /etc/skel/.bashrc ~/
exec bash -l
```
