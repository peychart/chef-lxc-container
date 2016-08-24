#
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

# LXC install:
%w( lxc ).each do |package|
  package package do
    action :install
  end
end

node['chef-lxc-container'].each do |name, instance|

  # Container Install:
  bash "lxc-create" do
    code "lxc-ls #{name}|grep -qs #{name} || lxc-create -n #{name} -t #{instance['distrib']} -- -r #{instance['release']} -a #{instance['architecture']}"
  end

  # Post-install script:
  if instance['post-install-script'] != ''
    bash 'wget lxc-post-install-script' do
      code "cd /tmp && wget -O lxc-post-install.sh #{instance['post-install-script']} && chmod 500 lxc-post-install.sh"
    end
  else
    cookbook_file "/tmp/lxc-post-install.sh" do
    source 'lxc-#{name}-post-install.sh'
    owner 'root'
    group 'root'
    mode '0500'
    action :create
  end

  execute 'lxc-post-install.sh' do
    command "export name=#{name}; /tmp/lxc-post-install.sh"
  end

end
