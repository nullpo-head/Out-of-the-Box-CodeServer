# OOTB Code-Server

OOTB Code-Server is an out-of-the-box Code-Server environment. 

With OOTB Code-Server, you can set up a Code-Server environment in your cloud to which your iPad or laptop can connect, with little efforts.  
OOTB Code-Server is equipped with

1. HTTPS powered by Let's Encrypt
2. Authorization by your GitHub account
3. Mutable LXC Code-Server container, inside which you can do any mutable things as you usually do in an Ubuntu machine
4. Automatic deallocation of your VM after 15-minutes idle time (Currently Azure VM is supported)

OOTB Code-Server consists of Docker-Compose containers for immutable components such as Https proxy and GitHub auth proxy,
and a LXC container for mutable Code-Server environment.

## Getting Started

### 0. Prerequisites

Please install `docker`, `docker-compose`, and `lxd`. Ubuntu has `lxd` by default.

### 1. Clone this repository

Please clone this repository to a good location

```bash
$ git clone https://github.com/nullpo-head/Out-of-Box-CodeServer-Environment.git ~/oob-code-server
```

### 2. Set up environment variables

1. Copy `.env.example` to `.env`

   ```bash
   $ cd oob-code-server
   $ cp ./helper_containers/.env.example ./helper_containers/.env
   ```
   Pleaes edit `.env` as follows

2. DNS Name

   Rewrite `CODER_HOST` to your server's DNS name. Let's Encrypt will issue a certificate for this domain.  
   For example, if you use an Azure VM, it has a name like this
   ```
   CODER_HOST=my-oob-codeserver.japaneast.cloudapp.azure.com
   ```

3. GitHub Authorization
   
   Create a new project at https://github.com/settings/developers.

   Please fill in `OAUTH2_PROXY_CLIENT_ID` and `OAUTH2_PROXY_CLIENT_SECRET` in `.env` according to the project you created.

   Put your email address in `emails` file. Only the email address listed here are allowed to login to your Code-Server.
   ```bash
   $ echo 'your.email.address@example.com' > ~/oob-code-server/emails
   ```

4. **(Optional)** Automatic Deallocation of Your VM (Azure is only supporeted)

   Azure VM is only supported right now because I'm an Azure user. Any PRs to support other clouds are welcome.

   If you enable automatic deallocation of your VM,
   rewrite `HEARTBEATS_ACTION` so that it corresponds to your VM.

   ```
   HEARTBEATS_ACTION="az vm deallocate --subscription 'Put Your Subscription Here' -g 'Put Your Resource Group Name Here' -n 'Put Your VM Name Here"
   ```

   You can set `HEARTBEATS_TIMEOUT` to determine how many minutes of idle time the VM will deallocate after. The default minutes is 15.

### 3. Init OOTB Code-Server

**First**, please make sure that `80` and `443` ports are not used by other web servers.  
Installtion will fail if they are not available. If it fails, re-run `install.sh` after making those ports available.

Run `install.sh`, following the instruction it prompts.
```bash
$ ./install.sh
```

After that, you can access your Code-Server at `https://your-host-name`.

Containers of OOTB Code-Server will automatically launch when your server starts.  

## Stop / Monitor Container statuses

OOTB Code-Server consists of Docker Compose and LXD. So, you can controll containers by `docker-compose` and `lxc`.

You can stop containers
```bash
$ cd ~/oob-code-server/helper_containers
$ sudo docker-compose stop  # or `down` to delete containers
$ lxc stop oob-code-server
```

You can monitor containers by
```bash
$ cd ~/oob-code-server/helper_containers
$ sudo docker-compose ps
CONTAINER ID        IMAGE                               COMMAND               CREATED             STATUS              PORTS                                      NAMES
7c9806549c66        steveltn/https-portal:1             "/init"               2 hours ago         Up 2 hours          0.0.0.0:80->80/tcp, 0.0.0.0:443->443/tcp   helper_containers_https-portal_1
6f0ce90981c9        quay.io/oauth2-proxy/oauth2-proxy   "/bin/oauth2-proxy"   2 hours ago         Up 2 hours                                                     helper_containers_oauth2-proxy_1
```
and 
```bash
$ lxc ls
+------------------+---------+---------------------+--------+------------+-----------+
|       NAME       |  STATE  |        IPV4         |  IPV6  |    TYPE    | SNAPSHOTS |
+------------------+---------+---------------------+--------+------------+-----------+
| ootb-code-server | RUNNING | 10.238.18.27 (eth0) |        | PERSISTENT | 0         |
+------------------+---------+---------------------+--------+------------+-----------+
```
