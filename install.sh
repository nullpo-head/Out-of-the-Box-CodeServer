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

echo_stage "== Checking existing LXD containers for Code-Server =="

info "Querying existing LXD containers"
if [ -n "$(lxc ls ootb-code-server --format=csv)" ]; then
  if prompt_yn "A LXC container named 'ootb-code-server' already exists. Do you want to delete it? [y/N]" n; then
    info "Stopping ootb-code-server. This might cause an expected errorfail."
    lxc stop ootb-code-server || true
    info "Deleting ootb-code-server"
    lxc delete ootb-code-server
    info stopped and deleted the container.
  else
    error "Aborting"
    exit 0
  fi
fi

echo_stage "== Filling some variables in .env =="

sed -i "s;^HEARTBEATS_FOLDER=.*;HEARTBEATS_FOLDER=$(realpath ./heartbeats_files_placeholder);" ./helper_containers/.env
touch ./helper_containers/emails
sed -i "s;^ALLOWED_EMAILS_LIST=.*;ALLOWED_EMAILS_LIST=$(realpath ./helper_containers/emails);" ./helper_containers/.env
sed -i "s;^OAUTH2_PROXY_COOKIE_SECRET=.*;OAUTH2_PROXY_COOKIE_SECRET=$(head -c 32 /dev/urandom | sha512sum | cut -c1-32);" ./helper_containers/.env

info done.

echo_stage "== Initializing a LXC container for Code-Server =="

USERNAME="$(whoami)"
UID_="$(id -u)"
GID="$(id -g)"

if prompt_yn "Do you run 'lxd init'? Run it if this is your first time to use LXD. [Y/n]" y; then
    info "Launch 'lxd init'... The default options are suitable for most cases."
    lxd init
fi

info "Creating an Ubuntu:20.04 LXC container"
lxc init ubuntu:20.04 ootb-code-server -p default -c security.nesting=true
sed "s/%%user%%/$USERNAME/g" ./codeserver/cloud-init.yml | lxc config set ootb-code-server user.user-data -
lxc start ootb-code-server
while ! ( lxc exec ootb-code-server -- tail -n50 /var/log/cloud-init-output.log | grep "Cloud-init .* finished .* Up .* seconds" ) ; do
    sleep 2
    info "waiting for the container getting ready..."
done

sleep 2

info "Mounting heartbeats_files_placeholder directory"
info "To allow for $USERNAME to mount a directory to a LXD container, adding a subuid mapping..."
set -x
sudo usermod --add-subuids ${UID_}-${UID_} --add-subgids ${GID}-${GID} root
set +x
echo -e "uid $(id -u "$USERNAME") 1000\ngid $(id -g "$USERNAME") 1000" | lxc config set ootb-code-server raw.idmap -
lxc exec ootb-code-server -- sudo -u "${USERNAME}" sh -c "mkdir -p /home/$USERNAME/.local/share"
lxc config device add ootb-code-server heartbeats disk source=$(realpath heartbeats_files_placeholder) path="/home/$USERNAME/.local/share/code-server"

info "Enabling code-server in the container..."
lxc exec ootb-code-server -- sudo -u "${USERNAME}" sh -c "DBUS_SESSION_BUS_ADDRESS='unix:path=/run/user/1000/bus' systemctl --user enable code-server"
lxc stop ootb-code-server
lxc file push -p ./codeserver/config.yaml ootb-code-server/home/nullpo/.config/code-server/
lxc start ootb-code-server

info "Querying the IP address of the container..."
sleep 3
sed -i "s;^LXC_IP=.*;LXC_IP=$(lxc ls ootb-code-server -c4 --format=csv | grep -o '^[0-9.]*');" ./helper_containers/.env

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
info "If they have no errors, you should be able to access to https://$(grep -o 'CODER_HOST=.*' .env | cut -c12-)"
info
info "If you want to enter the container of code-server from your shell, run 'lxc exec ootb-coder-server -- /bin/bash -i'"

echo_stage "== Follow-up =="

if prompt_yn "Would you like to see docker-compose logs now? [Y/n]" y; then
    info "Hit ctrl+c to exit from the log"
    sleep 1
    sudo docker-compose logs --tail=30 -f
fi
