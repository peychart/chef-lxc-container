#
# Author:: Philippe EYCHART (<peychart@mail.pf>)
# Cookbook Name:: chef-squid
# Resource:: default
#
# Copyright 2015-2017, Philippe EYCHART
#
# Licensed under the GNU License, Version 3;
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.gnu.org/licenses/gpl-3.0.html
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

default['chef-lxc-container'] = {
  'name' => 'lxc-ldap',
  'distrib' => 'ubuntu',
  'release' => 'trusty',
  'architecture' => 'amd64',
  'repository' => 'http://repository.srv.gov.pf/lxc-container'
}

