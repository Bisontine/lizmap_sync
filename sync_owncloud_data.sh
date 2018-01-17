#!/bin/bash

# usage : "bash /chemin/complet/main.sh"  et non "bash main.sh"
# sinon ${BASH_SOURCE[0]} utilisé par certaines librairies renverra "." au lieu du répertoire attendu 

BASEDIR=$(dirname "$0")

OWNCLOUD_URL="https://owncloud-mshe.univ-fcomte.fr"

INPUT_COPY_PATH="$HOME/owncloudsync"

# log dans un répertoire dédié
# ls -ld /var/log/lizmap_sync
# drwxrwxr-x 2 georchestra       georchestra     4096 juil.  3 15:05 geosync

# on synchronise les fichiers distants avec le client owncloud-client-cmd
# NB1 : pour disposer d'une version récente de owncloud-client-cmd, on déclare les jessie-backports
# l'installation du paquet sur fait donc avec la commande suivante :
# apt-get install -t jessie-backports owncloud-client-cmd
#
# NB2 : l'installation par les jessie-backports n'installe pas les fichiers à exclure par le système
# créer en conséquence /etc/ownCloud/sync-exclude.lst ou /etc/owncloud-client/sync-exclude.lst
# utiliser "strace -o logfile owncloudcmd ..." pour voir les erreurs éventuelles de owncloudcmd
#
cmd="owncloudcmd --silent --unsyncedfolders folder-to-exclude.lst --user lizmap --password Lesoleilauzenith $INPUT_COPY_PATH $OWNCLOUD_URL"
echo $cmd
eval $cmd

