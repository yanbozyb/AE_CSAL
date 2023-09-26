#!/bin/bash

parted -s /dev/nvme3n1 mklabel gpt \
  mkpart primary 0GB 1600GB \
  mkpart primary 1600GB 3200GB \
  mkpart primary 3200GB 4800GB \
  mkpart primary 4800GB 6400GB \
  mkpart primary 6400GB 8000GB \
  mkpart primary 8000GB 9600GB \
  mkpart primary 9600GB 11200GB \
  mkpart primary 11200GB 12800GB

