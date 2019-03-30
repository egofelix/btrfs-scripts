#!/bin/bash
MountPoints=`mount | grep btrfs | cut -d' ' -f3`


while read -r MountDir; do
  DirName="${MountDir}"
  if [[ $DirName != */ ]]; then DirName="${DirName}/"; fi;

  echo $DirName.snapshots

  if [[ ! -d "${DirName}.snapshots" ]]; then
    btrfs subvolume create "${DirName}.snapshots"
  fi;

  NOW=`date "+%Y-%m-%d-%H-%M-%S"`

  # Make Snapshot
  btrfs subvolume snapshot -r "${DirName}" "${DirName}.snapshots/${NOW}"
done <<< ${MountPoints}


while read -r MountDir; do
  DirName="${MountDir}"
  if [[ $DirName != */ ]]; then DirName="${DirName}/"; fi;

  SNAPSHOTS=`find "${DirName}.snapshots" -maxdepth 1 -type d -and -not -path "${DirName}.snapshots" -printf '%f\n'`
  PREVIOUSSNAPSHOT=""

  while read -r SnapShot; do
    echo ${SnapShot}

    if [[ ! -f "${DirName}.snapshots/${SnapShot}.snap" ]]; then

      if [[ -z "${PREVIOUSSNAPSHOT}" ]]; then
        echo No Previous - Do Full!
        btrfs send "${DirName}.snapshots/${SnapShot}" > "${DirName}.snapshots/${SnapShot}.snap"

        # TODO CHECK RETURN CODE!!!!
      else

        echo HAHA
        btrfs send -p "${DirName}.snapshots/${PREVIOUSSNAPSHOT}" "${DirName}.snapshots/${SnapShot}" > "${DirName}.snapshots/${SnapShot}.snap"

        # TODO CHECK RETURN CODE!!!!

        if [[ -f "${DirName}.snapshots/${PREVIOUSSNAPSHOT}.snap" ]]; then
          if [[ -f "${DirName}.snapshots/${SnapShot}.snap" ]]; then
            # Remove Parent snapshot
            btrfs subvolume delete "${DirName}.snapshots/${PREVIOUSSNAPSHOT}"
          fi;
        fi;
      fi;
    fi;

    PREVIOUSSNAPSHOT="${SnapShot}"
  done <<< ${SNAPSHOTS}

done <<< ${MountPoints}
