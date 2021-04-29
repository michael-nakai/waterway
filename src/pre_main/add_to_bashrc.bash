#!/bin/bash
# This script will add the command 'waterway' as an alias to .bashrc

scriptdir=`dirname "$(readlink -f "$0")"`
echo "This command only needs to be run once (ever!), so please don't run it multiple times"
read -p "This will create the command 'waterway' to run waterway.bash. Continue? (y/n): " answer
if [ $answer == "y" ]; then
    echo "alias waterway='bash ${scriptdir}/waterway.bash'" >> ~/.bashrc
    echo 'complete -W "-v --verbose -l --log -m --manifest -h --help -t --test -f --show-functions -c --train-classifier -s --subsets -g --graphs -M --make-manifest -F --fastqc -r --remove-underscores -T --filter-table --install-deicode --install-picrust -n --version --devtest" waterway' >> ~/.bashrc
    alias waterway="bash ${scriptdir}/waterway.bash"
    complete -W "-v --verbose -l --log -m --manifest -h --help -t --test -f --show-functions -c --train-classifier -s --subsets -g --graphs -M --make-manifest -F --fastqc -r --remove-underscores -T --filter-table --install-deicode --install-picrust -n --version --devtest" waterway
elif [ $answer == "test" ]; then
    echo "alias waterway='bash ${scriptdir}/waterway.bash'"
    echo 'complete -W "-v --verbose -l --log -m --manifest -h --help -t --test -f --show-functions -c --train-classifier -s --subsets -g --graphs -M --make-manifest -F --fastqc -r --remove-underscores -T --filter-table --install-deicode --install-picrust -n --version --devtest" waterway'
else
    echo "Exiting without adding command..."
    exit
fi