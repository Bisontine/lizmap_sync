#!/bin/bash

# usage : "bash /chemin/complet/main.sh"  et non "bash main.sh"
# sinon ${BASH_SOURCE[0]} utilisé par certaines librairies renverra "." au lieu du répertoire attendu 

BASEDIR=$(dirname "$0")

# avec autofs
#INPUT_OUTPUT_PATH="$HOME/owncloud/owncloud"
# sans autofs
INPUT_OUTPUT_PATH="$HOME/owncloud"

INPUT_COPY_PATH="$HOME/owncloud_sync"

# log dans un répertoire dédié
# ls -ld /var/log/lizmap_sync
# drwxrwxr-x 2 georchestra       georchestra     4096 juil.  3 15:05 geosync

# montage à la demande, sans autofs
if grep -qs "$LOGNAME/owncloud" /proc/mounts; then
    echo "déjà monté"
else
    echo "pas encore monté... donc on le monte."
    mount ~/owncloud
fi

#synchronise les fichiers du montage webdav pour être plus performant
#rsync -avr --delete '/home/lizmap/owncloud/owncloud' '/home/lizmap/owncloud_sync/'
cmd="rsync -avr --delete --exclude 'lost+found' --exclude _unpublished '$INPUT_OUTPUT_PATH/' '$INPUT_COPY_PATH/'"
echo $cmd
eval $cmd

# démontage forcé, pour éviter les problèmes
if grep -qs "$LOGNAME/owncloud" /proc/mounts; then
    echo "on démonte"
    umount ~/owncloud
fi

