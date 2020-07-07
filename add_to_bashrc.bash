#!/bin/bash
# This script will add the command 'waterway' as an alias to .bashrc

scriptdir=`dirname "$(readlink -f "$0")"`
echo "This command only needs to be run once (ever!), so please don't run it multiple times"
read -p "This will create the command 'waterway' to run waterway.bash. Continue? (y/n): " answer
if [ $answer == "y" ]; then
    echo "alias waterway=bash ${scriptdir}/waterway.bash" >> ~/.bashrc
elif [ $answer == "test" ]; then
    echo "alias waterway=bash ${scriptdir}/waterway.bash"
else
    echo "Exiting without adding command..."
fi