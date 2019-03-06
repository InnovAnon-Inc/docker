#! /bin/bash
set -exo nounset

[ $# -ge 1 ] || exit 1
[ -f $1/port -o $# -eq 2 ] || exit 1
T="`sed 's#/$##' <<< "$1"`"
if [ -f $1/port ] ; then
	P="`cat $1/port`"
else
	P=$2
fi

trap "sudo docker rmi -f $T" 0

./systemctl.sh $T
sudo docker run -p $P -ti $T /bin/sh
