#! /usr/bin/env bash
set -euxo pipefail
(( ! $UID ))
#(( $UID ))

if (( $# == 1 )) ; then
    [[ -n "$1" ]]
    WALLET="$1"
elif (( ! $# )) ; then
    WALLET=84FEn5Gak63AReZjRtDwV724TsoUtfajxjLHHJZ3zH3vcaAZJwvg4qWdUG9cx7nhA1ZfT9kK89roADmRb1ehLLhH6HyTATK
else exit 2 ; fi

exec 0<&-          # close stdin
exec 2>&1          # redirect stderr to stdout
renice -n -20 "$$" || : # max prio
#sudo -u nobody -g nogroup -- \
/usr/local/bin/xmrig             \
-u "$WALLET"                     \
-p docker                        \
-a cryptonightv7                 \
-o gulf.moneroocean.stream:10032 \
--keepalive                      \
--donate-level=0                 \
--cpu-priority 5                 \
--cpu-no-yield                   \
--nicehash                       \
--cuda                           \
--cuda-loader /usr/local/lib/libxmrig-cuda.so
#--pause-on-battery
#-c "/conf.d/$1.json"

