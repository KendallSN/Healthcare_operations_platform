#!/bin/bash
# Instalar paquetes del sistema operativo requeridos para Oracle 21c

. /vagrant_config/install.env

echo "******************************************************************************"
echo "Install OS packages." `date`
echo "******************************************************************************"

# Instalar paquete oracle-database-preinstall-21c: configura usuarios, grupos y parámetros del kernel
dnf install -y oracle-database-preinstall-21c

# Instalar paquetes requeridos adicionales
dnf install -y \
  bc \
  binutils \
  elfutils-libelf \
  elfutils-libelf-devel \
  fontconfig-devel \
  glibc \
  glibc-devel \
  ksh \
  libaio \
  libaio-devel \
  libgcc \
  libnsl \
  librdmacm-devel \
  libstdc++ \
  libstdc++-devel \
  libX11 \
  libXau \
  libxcb \
  libXi \
  libXrender \
  libXrender-devel \
  libXtst \
  make \
  net-tools \
  nfs-utils \
  policycoreutils \
  policycoreutils-python-utils \
  smartmontools \
  sysstat \
  targetcli \
  unzip \
  zip \
  chrony \
  rsync

# Actualizar sistema
dnf update -y

echo "******************************************************************************"
echo "Configure kernel parameters." `date`
echo "******************************************************************************"

# Parámetros del kernel adicionales para Data Guard
cat >> /etc/sysctl.d/98-oracle.conf << EOF
fs.file-max = 6815744
kernel.sem = 250 32000 100 128
kernel.shmmni = 4096
kernel.shmall = 1073741824
kernel.shmmax = 4398046511104
net.core.rmem_default = 262144
net.core.rmem_max = 16777216
net.core.wmem_default = 262144
net.core.wmem_max = 16777216
net.ipv4.ip_local_port_range = 9000 65500
fs.aio-max-nr = 1048576
# Ajuste de TCP para Data Guard
net.ipv4.tcp_rmem = 4096 87380 16777216
net.ipv4.tcp_wmem = 4096 16384 16777216
EOF

sysctl -p /etc/sysctl.d/98-oracle.conf

echo "******************************************************************************"
echo "Disable SELinux and Firewall." `date`
echo "******************************************************************************"

sed -i 's/SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
setenforce Permissive 2>/dev/null || true
systemctl stop firewalld 2>/dev/null || true
systemctl disable firewalld 2>/dev/null || true

echo "******************************************************************************"
echo "Instalación de paquetes del sistema operativo completada." `date`
echo "******************************************************************************"
