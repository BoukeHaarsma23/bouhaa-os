#!/bin/sh
docker build \
  --build-arg PKG_INSTALL="$(grep '^+' packages | sed 's/^+//' | tr '\n' ' ')" \
  --build-arg PKG_REMOVE="$(grep '^-' packages | sed 's/^-//' | tr '\n' ' ')" \
  -f Dockerfile .
