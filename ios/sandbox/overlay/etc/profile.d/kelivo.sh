# Kelivo Workspace shell configuration
# Loaded by /etc/profile via the profile.d mechanism.

export HOME="${HOME-/root}"
export HISTFILE="${HISTFILE-$HOME/.ash_history}"
export HISTSIZE="${HISTSIZE-1000}"
export ENV="${ENV-$HOME/.ashrc}"
export TERM="${TERM-xterm-256color}"
export LANG="${LANG-C.UTF-8}"
export CHARSET="${CHARSET-UTF-8}"
export PATH="${PATH-/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin}"
if [ -z "${PS1+x}" ]; then
    PS1='\u@kelivo:\w\$ '
fi
export PS1
