#!/bin/bash

#########################################
# Safe options

# exit as soon as a command fails
set -o errexit
# fail when accessing an unset variable
set -o nounset
# treat a pipeline as failed when one command fails
set -o pipefail

#########################################
# Make sure only root can run our script

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

#########################################
# CHECK OS

# we only support Ubuntu
# also specify the version (to make sure we can install all the expected packages)
SUPPORTED_VERSION='22.04'

if [[ "$(uname)" != "Linux" ]]
then
    echo "This machine seems to run $(uname), the installation script only works with Linux" >&2
    exit 1
fi

if [[ ! -f /etc/debian_version ]]
then
    echo "This script only works with Ubuntu (installed distribution is not based on Debian)" >&2
    exit 1
fi

DISTRIB="$(grep '^DISTRIB_ID' /etc/lsb-release | cut -d= -f2)"

if [[ "$DISTRIB" != "Ubuntu" ]]
then
    echo "This script only works with Ubuntu (installed distribution is $DISTRIB)" >&2
    exit 1
fi

RELEASE="$(grep '^DISTRIB_RELEASE' /etc/lsb-release | cut -d= -f2)"

if [[ "$RELEASE" != "$SUPPORTED_VERSION" ]]
then
    echo "Expected Ubuntu version $SUPPORTED_VERSION, found $RELEASE instead" >&2
    exit 1
fi

#########################################
# Update package info before installing anything

apt-get update
apt-get upgrade -y

#########################################
# Install LDAP + Automount

apt-get install -y sssd libpam-sss libnss-sss sssd-tools tcsh nfs-common
mkdir -p /etc/openldap/cacerts
wget https://rauth.epfl.ch/DigiCert_Global_Root_CA.pem -O /etc/openldap/cacerts/DigiCert_Global_Root_CA.pem
wget http://install.iccluster.epfl.ch/scripts/it/sssd/sssd.conf -O /etc/sssd/sssd.conf
chmod 0600 /etc/sssd/sssd.conf
sed -i 's|simple_allow_groups = IC-IT-unit|simple_allow_groups = IC-IT-unit,LHST-unit,lhstlogins|g' /etc/sssd/sssd.conf
sed -i 's|nis|ldap|' /etc/nsswitch.conf
echo "session    required    pam_mkhomedir.so skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-session

# CIFS PAM Mount
apt-get install -y libpam-mount cifs-utils ldap-utils

service sssd restart

#########################################
# Create /scratch

curl -s http://install.iccluster.epfl.ch/scripts/it/scratchVolume.sh  >> scratchVolume.sh
chmod +x scratchVolume.sh
./scratchVolume.sh
chmod 775 /scratch
chown root:LHST-unit /scratch

########################################
# Mount point for lhstdata1

mkdir /lhstdata1
echo "#lhstdata1" >> /etc/fstab
echo "cdh1files.epfl.ch:/u13673_cdh_lhst_001_files_nfs/lhstdata1 /lhstdata1 nfs     defaults 0 0" >> /etc/fstab

########################################
# Give sudo powers to our power users

usermod --append --groups sudo chachere
usermod --append --groups sudo sidorenk
usermod --append --groups sudo pgupta

#########################################
# Some basic necessities

install() {
    apt-get install -y "$1"
}

install emacs
install vim
install vim-scripts

install screen
install tmux

install htop
install iotop
install strace

install mc
install git
install subversion

install zsh

install zip
install unzip

install dos2unix

#########################################
# Compiling related

install gdb
install cmake
install cmake-curses-gui
install autoconf
install gcc
install gcc-multilib
install g++
install g++-multilib

install build-essential
install pkg-config

#########################################
# Python related stuff

install python3
install python3-pip
install python3-setuptools
install python3-numpy
install python3-scipy
install python3-matplotlib
install python3-pandas
install python3-sympy
install python3-nose
install python3-dev
install python3-wheel
install python-dev-is-python3

pip install ipython[all]

#########################################
# Install Cuda

wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/12.0.1/local_installers/cuda-repo-ubuntu2204-12-0-local_12.0.1-525.85.12-1_amd64.deb
dpkg -i cuda-repo-ubuntu2204-12-0-local_12.0.1-525.85.12-1_amd64.deb
cp /var/cuda-repo-ubuntu2204-12-0-local/cuda-*-keyring.gpg /usr/share/keyrings/
apt-get update
apt-get install -y cuda
apt-get install -y nvidia-cuda-toolkit
apt-get install -y nvidia-driver-510 nvidia-dkms-510

########################################
# Install Miniconda

wget https://repo.anaconda.com/miniconda/Miniconda3-py310_23.1.0-1-Linux-x86_64.sh -P /tmp
chmod +x /tmp/Miniconda3-py310_23.1.0-1-Linux-x86_64.sh
/tmp/Miniconda3-py310_23.1.0-1-Linux-x86_64.sh -b -p /opt/anaconda3
echo PATH="/opt/anaconda3/bin:$PATH"  > /etc/environment
export PATH="/opt/anaconda3/bin:$PATH"

########################################
# Install PyTorch

conda install -y pytorch torchvision torchaudio pytorch-cuda=11.7 -c pytorch -c nvidia

echo
echo
echo "DONE!"
echo "You most probably want to run \`reboot'"

rm -- "$0"
