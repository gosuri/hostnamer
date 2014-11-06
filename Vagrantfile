# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"
ENV['DEPENDS'] = "awscli"

$maintainer = ENV['MAINTAINER']   || `git config user.name`.strip
$email      = ENV['EMAIL']        || `git config user.email`.strip
$deps       = ENV['DEPENDS']      # Array eg DEPENDS='ruby, awscli > 2, python >= 3'

fpmcmd      = ENV['FPMCMD']       || "fpm --force -s gem -t deb --no-gem-fix-name -m '#{$maintainer} \<#{$email}\>' "

fpmcmd += $deps.split(',').map { |d| "--depends #{d.strip}" }.join(' ') if $deps

$script = <<-BASH
sudo su -
export EMAIL="#{$email}"
export DEBFULLNAME="#{$maintainer}"

apt-get update -y && apt-get install build-essential gcc ruby1.9.3 -y
gem install rake bundler fpm --no-ri --no-rdoc

echo '--> packaging .gem'
cd /src && bundle install && bundle exec rake build

echo '--> packaging .deb'
cd /src/pkg
gem=`ls *.gem | awk '{print $NF}' | tail -n1`
echo "--> exec #{fpmcmd} ./$gem"
#{fpmcmd} ./$gem
deb=`ls *.deb | awk '{print $NF}' | tail -n1`
lesspipe $deb

echo "--> $deb is built to /src/pkg/$deb"
BASH

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  config.vm.box = "hashicorp/precise64"
  config.vm.synced_folder '.', "/src"
  config.vm.provision "shell", inline: $script
end
