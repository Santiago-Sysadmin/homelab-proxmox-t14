#!/bin/bash
set -u
[ -f /etc/default/photos-backup ] && . /etc/default/photos-backup   # define VM_HOST, VM_USER y SSH_KEY
REPO=${REPO:-/mnt/backup/photos-restic}; PW=${PW:-/etc/homelab/restic-password}; MNT=/mnt/vm-photos   # la contraseña de restic NO está en el repo
mountpoint -q /mnt/backup || { echo "disco de copias no montado"; exit 1; }
mkdir -p $MNT
mountpoint -q $MNT || sshfs -o ro,IdentityFile=${SSH_KEY},StrictHostKeyChecking=accept-new,reconnect,ServerAliveInterval=15,sftp_server="/usr/bin/sudo /usr/lib/openssh/sftp-server" ${VM_USER}@${VM_HOST}:/mnt/photos $MNT || { echo "no pude montar la carpeta de la VM"; exit 1; }
# Se excluyen miniaturas y vídeos transcodificados: Immich los regenera; se guardan originales, base de datos (volcados) y perfiles.
restic -r $REPO --password-file $PW backup $MNT --tag immich --exclude "$MNT/library/thumbs" --exclude "$MNT/library/encoded-video" --host immich 2>&1 | tail -6
RC=$?
restic -r $REPO --password-file $PW forget --tag immich --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --prune 2>&1 | tail -3
# Una vez por semana (domingo), comprobar la integridad leyendo el 5 % de los datos
[ "$(date +%u)" = "7" ] && restic -r $REPO --password-file $PW check --read-data-subset=5% 2>&1 | tail -3
fusermount -u $MNT 2>/dev/null || umount $MNT
exit $RC
