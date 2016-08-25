#!/bin/sh
# Cookbook Name:: chef-lxc-container
# Recipe:: default
#
# Copyright (C) 2016 PE, pf.
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
name=${name:-lxc-test}
distrib=${distrib:-ubuntu}
release=${release:-trusty}
archi=${archi:-amd64}
packages=${packages:-"apache2 libapache2-mod-php5 ed"}
ip=${ip:-248}

# LXC install:
apt-get install lxc -y
lxc-ls $name| grep -qs $name || lxc-create -n $name -t $distrib -- -r $release -a $archi

# Container packages install:
rootfs=$(lxc-info -n $name -c lxc.rootfs 2>/dev/null| cut -d' ' -f 3)
[ -z "$rootfs" ] && exit 1

chroot $rootfs apt-get update
chroot $rootfs apt-get autoremove --force-yes -y
chroot $rootfs apt-get upgrade --force-yes -y
for I in $packages; do
  chroot $rootfs apt-get install --force-yes -y --no-install-recommends ${I}
done

# start on host boot:
grep -qs lxc.start.auto $rootfs/config || echo "lxc.start.auto = 1" >>$rootfs/config
grep -qs lxc.start.delay $rootfs/config || echo "lxc.start.delay = 5" >>$rootfs/config
ed $rootfs/config <<EOF || exit $?
/lxc.start.auto/s; =.*; = 1;
/lxc.start.delay/s; =.*; = 5;
w
q
EOF

#set network config:
net=$(echo $(ip -4 -br -f inet address|grep lxc)|cut -d' ' -f3| cut -d'.' -f1-3)
[ -z "$net" ] || cat <<EOF > $rootfs/etc/network/interfaces
# This file describes the network interfaces available on your system
# and how to activate them. For more information, see interfaces(5).

# The loopback network interface
auto lo
iface lo inet loopback

auto eth0
iface eth0 inet static
	address $net.$ip
	netmask 255.255.255.0
	gateway $net.1
	dns-search srv.gov.pf gov.pf
	dns-nameservers	$net.1
EOF
(grep -v search $rootfs/etc/resolv.conf; grep search /etc/resolv.conf) >/tmp/resolv.conf; cat /tmp/resolv.conf >$rootfs/etc/resolv.conf

#set proxy:
echo "Acquire::http { Proxy "http://proxy:3142/"; };" >$rootfs/etc/apt/apt.conf.d/02proxy

# start container:
lxc-start -n $name -d || exit $?
chroot $rootfs echo 'LC_ALL=fr_FR' >/etc/default/locale
lxc-attach -n $name -- locale-gen fr_FR

#set /etc/hosts
grep -wqs $name /etc/hosts || echo $(lxc-info -n $name -i| cut -d: -f2) $name >>/etc/hosts

## Specific packages:
# set apache2 document root:
if [ -d /var/lib/squidguard/db/html -a ! -L /var/lib/squidguard/db/html ]; then
 cp -rfp /var/lib/squidguard/db/html/* $rootfs/var/www/html
 mv /var/lib/squidguard/db/html /var/lib/squidguard/db/html.sv
fi
ln -fs $rootfs/var/www/html -t /var/lib/squidguard/db/
[ -d /var/log/apache2 -a ! -L /var/log/apache2 ] && rm -rf /var/log/apache2
ln -fs $rootfs/var/log/apache2 -t /var/log/

lxc-attach -n $name -- service apache2 reload
