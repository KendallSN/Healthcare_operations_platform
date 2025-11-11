#!/bin/bash
# Punto de entrada de configuración del nodo primario

echo "******************************************************************************"
echo "Iniciando configuración del nodo PRIMARY." `date`
echo "******************************************************************************"

# Ejecutar script de configuración root
sudo bash -c 'sh /vagrant/2-Standby/scripts/primary/root_setup.sh'

echo "******************************************************************************"
echo "Configuración del nodo PRIMARY completada." `date`
echo "******************************************************************************"
