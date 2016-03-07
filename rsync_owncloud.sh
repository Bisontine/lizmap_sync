#!/bin/bash

# usage : "bash /chemin/complet/main.sh"  et non "bash main.sh"
# sinon ${BASH_SOURCE[0]} utilisé par certaines librairies renverra "." au lieu du répertoire attendu 

BASEDIR=$(dirname "$0")

# avec autofs
INPUT_OUTPUT_PATH="$HOME/owncloud/owncloud"

INPUT_COPY_PATH="$HOME/owncloud_sync"

# log dans un répertoire dédié
# ls -ld /var/log/lizmap_sync
# drwxrwxr-x 2 georchestra       georchestra     4096 juil.  3 15:05 geosync

#synchronise les fichiers du montage webdav pour être plus performant
#rsync -avr --delete '/home/lizmap/owncloud/owncloud' '/home/lizmap/owncloud_sync/'
cmd="rsync -avr --delete --exclude 'lost+found' '$INPUT_OUTPUT_PATH/' '$INPUT_COPY_PATH/'"
echo $cmd
eval $cmd

