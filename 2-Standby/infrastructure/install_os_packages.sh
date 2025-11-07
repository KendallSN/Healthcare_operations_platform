#!/bin/bash
# Install required OS packages for Oracle 21c

. /vagrant_config/install.env

echo "******************************************************************************"
echo "Install OS packages." `date`
echo "******************************************************************************"

# Install Oracle preinstall package (sets up users, groups, kernel params)
dnf install -y oracle-database-preinstall-21c

# Install additional required packages
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

# Update system
dnf update -y

echo "******************************************************************************"
echo "Configure kernel parameters." `date`
echo "******************************************************************************"

# Additional kernel parameters for Data Guard
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
# TCP tuning for Data Guard
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
echo "OS package installation complete." `date`
echo "******************************************************************************"
