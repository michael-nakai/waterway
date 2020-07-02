#!/bin/bash

name="waterway_log"
if [[ -e $name.out ]] ; then
    i=0
    while [[ -e $name-$i.out ]] ; do
        let i++
    done
    name=$name-$i
fi

if [[ "$log" = true ]]; then
	touch "$name".out
	exec 3>&1 4>&2
	trap 'exec 2>&4 1>&3' 0 1 2 3
	exec 1>>"${name}.out" 2>&1
fi