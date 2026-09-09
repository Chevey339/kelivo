#!/bin/bash

T='gYw'

echo -e "\n                 40m     41m     42m     43m     44m     45m     46m     47m    100m    101m    102m    103m    104m    105m    106m    107m";

for FGs in '    m' '   1m' \
           '  30m' '1;30m' '  31m' '1;31m' '  32m' '1;32m' '  33m' '1;33m' '  34m' '1;34m' '  35m' '1;35m' '  36m' '1;36m' '  37m' '1;37m' \
           '  90m' '1;90m' '  91m' '1;91m' '  92m' '1;92m' '  93m' '1;93m' '  94m' '1;94m' '  95m' '1;95m' '  96m' '1;96m' '  97m' '1;97m';
  do FG=${FGs// /}
  echo -en " $FGs \033[$FG  $T  "
  for BG in 40m 41m 42m 43m 44m 45m 46m 47m 100m 101m 102m 103m 104m 105m 106m 107m;
    do echo -en "$EINS \033[$FG\033[$BG  $T  \033[0m";
  done
  echo;
done
echo