#!/bin/bash

# Make sure only root can run our script
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

##### CHECK OS #####
lowercase(){
    echo "$1" | sed "y/ABCDEFGHIJKLMNOPQRSTUVWXYZ/abcdefghijklmnopqrstuvwxyz/"
}

OS=`lowercase \`uname\``
KERNEL=`uname -r`
MACH=`uname -m`

if [ "{$OS}" == "windowsnt" ]; then
    OS=windows
elif [ "{$OS}" == "darwin" ]; then
    OS=mac
else
    OS=`uname`
    if [ "${OS}" = "SunOS" ] ; then
        OS=Solaris
        ARCH=`uname -p`
        OSSTR="${OS} ${REV}(${ARCH} `uname -v`)"
    elif [ "${OS}" = "AIX" ] ; then
        OSSTR="${OS} `oslevel` (`oslevel -r`)"
    elif [ "${OS}" = "Linux" ] ; then
        if [ -f /etc/redhat-release ] ; then
            DistroBasedOn='RedHat'
            DIST=`cat /etc/redhat-release |sed s/\ release.*//`
            PSUEDONAME=`cat /etc/redhat-release | sed s/.*\(// | sed s/\)//`
            REV=`cat /etc/redhat-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/SuSE-release ] ; then
            DistroBasedOn='SuSe'
            PSUEDONAME=`cat /etc/SuSE-release | tr "\n" ' '| sed s/VERSION.*//`
            REV=`cat /etc/SuSE-release | tr "\n" ' ' | sed s/.*=\ //`
        elif [ -f /etc/mandrake-release ] ; then
            DistroBasedOn='Mandrake'
            PSUEDONAME=`cat /etc/mandrake-release | sed s/.*\(// | sed s/\)//`
            REV=`cat /etc/mandrake-release | sed s/.*release\ // | sed s/\ .*//`
        elif [ -f /etc/debian_version ] ; then
            DistroBasedOn='Debian'
            DIST=`cat /etc/lsb-release | grep '^DISTRIB_ID' | awk -F=  '{ print $2 }'`
            PSUEDONAME=`cat /etc/lsb-release | grep '^DISTRIB_CODENAME' | awk -F=  '{ print $2 }'`
            REV=`cat /etc/lsb-release | grep '^DISTRIB_RELEASE' | awk -F=  '{ print $2 }'`
        fi
        if [ -f /etc/UnitedLinux-release ] ; then
            DIST="${DIST}[`cat /etc/UnitedLinux-release | tr "\n" ' ' | sed s/VERSION.*//`]"
        fi
        OS=`lowercase $OS`
        DistroBasedOn=`lowercase $DistroBasedOn`
        readonly OS
        readonly DIST
        readonly DistroBasedOn
        readonly PSUEDONAME
        readonly REV
        readonly KERNEL
        readonly MACH
    fi

fi

## Check OS and do the install 
# Remove spaces
DISTRIB=${DIST// /-} 					

# Check OS
case "$DISTRIB" in
"Ubuntu") echo $DISTRIB

#########################################
apt-get update

#########################################
# Install LDAP + Autmount
apt-get install sssd libpam-sss libnss-sss sssd-tools tcsh nfs-common -y
mkdir -p /etc/openldap/cacerts
wget http://rauth.epfl.ch/Quovadis_Root_CA_2.pem -O /etc/openldap/cacerts/quovadis.pem
wget http://install.iccluster.epfl.ch/scripts/it/sssd/sssd.conf -O /etc/sssd/sssd.conf
chmod 0600 /etc/sssd/sssd.conf
sed -i 's|simple_allow_groups = IC-IT-unit|simple_allow_groups = IC-IT-unit,LHST-unit,lhstlogins,|g' /etc/sssd/sssd.conf
sed -i 's|nis|ldap|' /etc/nsswitch.conf
echo "session    required    pam_mkhomedir.so skel=/etc/skel/ umask=0022" >> /etc/pam.d/common-session

#PAM Mount
apt-get install -y libpam-mount cifs-utils ldap-utils
# Backup
cp /etc/security/pam_mount.conf.xml /etc/security/pam_mount.conf.xml.orig
cp /etc/pam.d/common-auth /etc/pam.d/common-auth.orig
cd /
wget -P / install.iccluster.epfl.ch/scripts/it/pam_mount.tar.gz
tar xzvf pam_mount.tar.gz
rm -f /pam_mount.tar.gz
# Custom Template
#wget install.iccluster.epfl.ch/scripts/dhlab/template_.pam_mount.conf.xml -O /etc/security/.pam_mount.conf.xml
echo manual | sudo tee /etc/init/autofs.override
echo "unix" >> /var/lib/pam/seen
pam-auth-update --force --package
sed -i.bak '/and here are more per-package modules/a auth    optional      pam_exec.so /usr/local/bin/login.pl common-auth' /etc/pam.d/common-auth
service sssd restart

#########################################
# Create /scratch
curl -s http://install.iccluster.epfl.ch/scripts/it/scratchVolume.sh  >> scratchVolume.sh ; chmod +x scratchVolume.sh ; ./scratchVolume.sh
chmod 775 /scratch
chown root:LHST-unit /scratch

#########################################
# Install CUDA !!! INSTALL APRES REBOOT !!!
echo '#!/bin/sh -e' > /etc/rc.local

echo '
FLAG="/var/log/firstboot.cuda.log"
if [ ! -f $FLAG ]; then
	touch $FLAG
        curl -s http://install.iccluster.epfl.ch/scripts/soft/cuda/cuda_9.2.88_396.26.sh  >> /tmp/cuda.sh ; chmod +x /tmp/cuda.sh; /tmp/cuda.sh;
fi' >> /etc/rc.local

echo '
FLAGSCRATCH="/var/log/firstboot.scratch.log"
if [ ! -f $FLAGSCRATCH ]; then
        touch $FLAGSCRATCH
	chown root:LHST-unit /scratch
fi' >> /etc/rc.local

chmod +x /etc/rc.local

#########################################
# Some basic necessities
apt-get install -y emacs tmux htop mc git subversion vim iotop dos2unix wget screen zsh software-properties-common pkg-config zip g++ zlib1g-dev unzip strace vim-scripts nfs-common vim  wget zsh 

#########################################
# Compiling related
apt-get install -y gdb cmake cmake-curses-gui autoconf gcc gcc-multilib g++-multilib

#########################################
# Python related stuff
apt-get install -y python-pip python-dev python-setuptools build-essential python-numpy python-scipy python-matplotlib python-pandas python-sympy python-nose python3 python3-pip python3-dev python-wheel python3-wheel python-boto

pip install ipython[all]

#########################################
# Install Cuda
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-ubuntu2204.pin
sudo mv cuda-ubuntu2204.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/12.0.1/local_installers/cuda-repo-ubuntu2204-12-0-local_12.0.1-525.85.12-1_amd64.deb
sudo dpkg -i cuda-repo-ubuntu2204-12-0-local_12.0.1-525.85.12-1_amd64.deb
sudo cp /var/cuda-repo-ubuntu2204-12-0-local/cuda-*-keyring.gpg /usr/share/keyrings/
sudo apt-get update
sudo apt-get -y install cuda
sudo apt -y install nvidia-cuda-toolkit
sudo apt -y install nvidia-driver-510 nvidia-dkms-510

########################################
# Install Miniconda
wget https://repo.anaconda.com/miniconda/Miniconda3-py310_23.1.0-1-Linux-x86_64.sh -P /tmp; chmod +x /tmp/Miniconda3-py310_23.1.0-1-Linux-x86_64.sh; /tmp/Miniconda3-py310_23.1.0-1-Linux-x86_64.sh -b -p /opt/anaconda3
echo PATH="/opt/anaconda3/bin:$PATH"  > /etc/environment
export PATH="/opt/anaconda3/bin:$PATH"

########################################
# Install PyTorch
conda install -y pytorch torchvision torchaudio pytorch-cuda=11.7 -c pytorch -c nvidia

curl -s http://install.iccluster.epfl.ch/scripts/it/lab2group.sh  >> /tmp/lab2group.sh ; chmod +x /tmp/lab2group.sh; /tmp/lab2group.sh LHST-unit sudo

########################################
# Mount LHST-data
mkdir /LHSTdata

sudo touch /etc/rc.local
sudo chmod +x /etc/rc.local
sudo echo "sudo mount -t nfs cdh1files.epfl.ch://u13673_cdh_lhst_001_files_nfs /LHSTdata" >> /etc/rc.local
echo 'exit 0' >> /etc/rc.local

    ;;
"CentOS-Linux") echo $DISTRIB
    ;;
*) echo "Invalid OS: " $DISTRIB
   ;;
esac


rm -- "$0"

sudo reboot
