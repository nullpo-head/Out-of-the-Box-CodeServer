#!/bin/bash

set -e

prompt_yn () {
    info -n "$1: "
    read response
    if [[ -z "$response" ]]; then
	response="$2"
    fi
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])+$ ]]; then
	true
    elif [[ "$response" =~ ^([nN][oO]|[nN])+$ ]]; then
	false
    else
	$(prompt_yn "$1" "$2")
    fi
}

echo_stage () {
    echo -e "\e[32m$*\e[m"
}

error () {
    echo -e "\e[91m[Error] $*\e[m" >&2
}

info () {
    local flags=-e
    if [[ "$1" == -n ]]; then
	flags=-ne
	shift
    fi
    echo $flags "\e[2m=> \e[m$*" >&2
}

check_install() {
    if ! which $1; then
        error "$1 is not found. Please install $1"
        exit 1
    fi

    info $1 is installed.
}

if [[ $(whoami) == root ]]; then
    error "Please run this script by a regular user, not by sudo or root" >&2
    exit 1
fi

cd "$(dirname "$(realpath "$0")")"

echo_stage "== Checking if lxd and docker are installed =="

check_install lxd
check_install docker
check_install docker-compose

echo_stage "== Checking .env =="

if [[ ! -e helper_containers/.env ]]; then
    error "Please fill in .env file following README.md"
    exit 1
else
    info ".env file is found"
fi

echo_stage "== Checking existing LXC containers for Code-Server =="

if [ -n "$(lxc ls oob-code-server --format=csv)" ]; then
  if prompt_yn "A LXC container named 'oob-code-server' already exists. Do you want to delete it? [y/N]" n; then
    lxc stop oob-code-server || true
    lxc delete oob-code-server
    info stopped and deleted the container.
  else
    error "Aborting"
    exit 0
  fi
fi

echo_stage "== Filling some variables in .env =="

sed -i "s;^HEARTBEATS_FOLDER=.*;HEARTBEATS_FOLDER=$(realpath ./heartbeats);" ./helper_containers/.env
touch ./helper_containers/emails
sed -i "s;^ALLOWED_EMAILS_LIST=.*;ALLOWED_EMAILS_LIST=$(realpath ./helper_containers/emails);" ./helper_containers/.env
sed -i "s;^OAUTH2_PROXY_COOKIE_SECRET=.*;OAUTH2_PROXY_COOKIE_SECRET=$(head -c 32 /dev/urandom | sha512sum | cut -c1-32);" ./helper_containers/.env

info done.

echo_stage "== Initializing a LXC container for Code-Server =="

info -n "Please input your user name in the Code-Server container [ubuntu]: "
read USERNAME
if [ -z "$USERNAME" ]; then
    USERNAME=ubuntu
fi

if prompt_yn "Do you run 'lxd init'? [Y/n]" y; then
    lxd init
fi


lxc init ubuntu:20.04 oob-code-server -p default -c security.nesting=true
sed "s/%%user%%/$USERNAME/g" ./codeserver/cloud-init.yml | lxc config set oob-code-server user.user-data -
lxc start oob-code-server
while ! ( lxc exec oob-code-server -- tail -n50 /var/log/cloud-init-output.log | grep "Cloud-init .* finished .* Up .* seconds" ) ; do
    sleep 2
    info "waiting for the container getting ready..."
done

info "Enabling code-server in the container..."
sleep 2
lxc exec oob-code-server -- sudo -u "${USERNAME}" sh -c "DBUS_SESSION_BUS_ADDRESS='unix:path=/run/user/1000/bus' systemctl --user enable code-server"
lxc stop oob-code-server
lxc file push -p ./codeserver/config.yaml oob-code-server/home/nullpo/.config/code-server/
lxc start oob-code-server

info "Querying the IP address of the container..."
sleep 3
sed -i "s;LXC_IP^=.*;LXC_IP=$(lxc ls oob-code-server -c4 --format=csv | grep -o 'LXC_IP=[0-9.]*');" ./helper_containers/.env

echo_stage "== Making Docker containers up =="

cd helper_containers

if prompt_yn "Would you like to build the heartbeat watcher to automatially deallocate your Azure VM? [y/N]: " n; then
    sudo docker-compose up -d
else
    sudo docker-compose up -d https-portal oauth2-proxy
fi

echo_stage "== Finish =="

info "Done!"
info "* PLEASE cd to helper_containers and run 'docker-compose logs' to check whether containers are working fine. *"
info 'If they have no errors, you should be able to access to https://"your host name".'
info
info "If you want to enter the container of code-server from your shell, run 'lxc exec oob-coder-server -- /bin/bash -i'"

echo_stage "== Follow-up =="

if prompt_yn "Would you like to see docker-compose logs now? [Y/n]" y; then
    info "Hit ctrl+c to exit from the log"
    sleep 1
    sudo docker-compose logs --tail=30 -f
fi
