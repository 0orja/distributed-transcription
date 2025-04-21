#!/bin/bash

# filepath: remove_folders.sh
while read folder; do
  # Skip comment lines
  [[ $folder == //* ]] && continue
  # Skip empty lines
  [[ -z $folder ]] && continue
  echo "removing $folder"
  rm -rf "$folder"
done < "$1"

echo "removing itemlist.txt"
rm -f itemlist.txt
