#! /usr/bin/env bash
set -euxo pipefail
#(( ! $UID ))
(( $UID ))
(( $# == 1 ))
[[ -f "/conf.d/$1.json" ]]
exec 0<&-          # close stdin
exec 2>&1          # redirect stderr to stdout
renice -n -20 "$$" || : # max prio
#sudo -u nobody -g nogroup -- \
sudo /usr/local/bin/xmrig        \
-u 84FEn5Gak63AReZjRtDwV724TsoUtfajxjLHHJZ3zH3vcaAZJwvg4qWdUG9cx7nhA1ZfT9kK89roADmRb1ehLLhH6HyTATK \
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

