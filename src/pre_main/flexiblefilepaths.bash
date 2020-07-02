#!/bin/bash

str=$filepath
i=$((${#str}-1)) 2> /dev/null
j=${str:$i:1} 2> /dev/null
if [[ $j == '/' ]]; then
	str=${str%?}
fi
filepath=${str}

temparray=($projpath $qzaoutput)
fuck=1
for e in ${temparray[@]}; do
	# see if last char in e is '/', and if not, add it
	str=$e
	i=$((${#str}-1)) 2> /dev/null
	j=${str:$i:1} 2> /dev/null
	if [ $j != '/' ]; then
		str="${str}/"
	fi
	
	if [ $fuck -eq 1 ]; then
		projpath=$str
	fi
	if [ $fuck -eq 2 ]; then
		qzaoutput=$str
	fi
	fuck=$(($fuck+1))
done