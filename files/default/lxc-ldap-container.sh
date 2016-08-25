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
repository=${repository:-http://repository.srv.gov.pf/lxc-container}
packages=${packages:-"slapd ldap-utils xinetd ed"}
ip=${ip:-162}

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
lxc-attach -n $name -- service slapd stop

# installation des schemas:
wget -O $rootfs/etc/ldap $repository/ldap.tgz || exit 1
chroot $rootfs chown -R openldap: /etc/ldap/ /var/run/slapd/

(echo '/openldap/s;false$;bash;'; echo wq)| ed $rootfs/etc/passwd
(echo '/openldap/s;:!:;:$6$cioh8YSx$m0FBQFwiFzebRBcfSPhRgD7pIv3lsXHUEsPrHANUqMjLF9FYQjCGCvBn3PObNy1YPBpV4CVy7zjeyp0KPiEP./:;'; echo wq)| ed $rootfs/etc/shadow

# vidage base:
ldaphome=$(grep openldap $rootfs/etc/passwd| cut -d: -f6)
[ -z "$ldaphome ] || rm -rf $ldaphome/pf
mkdir $ldaphome/pf ; chown openldap: $ldaphome/pf

# synchro base:
# lxc-attach -n $name -- ssh root@ldapwrite.srv.gov.pf slapcat| slapadd

lxc-attach -n $name -- service slapd start
lxc-attach -n $name -- service xinetd restart
