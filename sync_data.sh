#!/bin/bash

# attention : ne pas faire précéder ce code par le flock (ci-dessous) car sinon semble ne pas supprimer le verrou

# utilisation d'un verrou pour éviter que le script sync_data.sh ne se lance plusieurs fois en même temps
(
  # Wait for lock on /var/lock/.myscript.exclusivelock (fd 200) for 10 seconds
  flock -x -w 10 200 || exit 1
  # date dans les logs
  date >> /var/log/lizmap_sync/sync_data.log

  # appel de sync_owncloud_data.sh
  bash /home/lizmap/bin/sync_owncloud_data.sh 1>>/var/log/lizmap_sync/sync_data.log 2>>/var/log/lizmap_sync/sync_data.log

) 200>/var/lock/lizmap_sync.exclusivelock


# à inclure dans un crontab
# toutes les minutes de 8h à 20h, du lundi au vendredi, importe les couches partagées via owncloud dans le owncloudsync
# */1 08-20 * * 1-5 /home/georchestra-ouvert/bin/sync_data.sh 

