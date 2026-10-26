#!/bin/bash
# update-office-version: 1
# Actualiza la oficina dev-office en todos tus proyectos con un doble click en el Finder.
cd "$(dirname "$0")" || exit 1
exec bash ./update-office.sh
