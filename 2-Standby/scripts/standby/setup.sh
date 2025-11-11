#!/bin/bash
# Punto de entrada de configuración del nodo Standby

echo "******************************************************************************"
echo "Iniciando configuración del nodo STANDBY." `date`
echo "******************************************************************************"

# Ejecutar script de configuración raíz
sudo bash -c 'sh /vagrant/2-Standby/scripts/standby/root_setup.sh'

echo "******************************************************************************"
echo "Configuración del nodo STANDBY completada." `date`
echo "******************************************************************************"
