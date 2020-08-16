FROM ubuntu:18.04

WORKDIR /app

RUN apt-get update && apt-get upgrade -y && apt-get install psmisc

COPY sshbash_heartbeat.bash /app/sshbash_heartbeat.bash
RUN chmod a+x /app/sshbash_heartbeat.bash

ENTRYPOINT ["/app/sshbash_heartbeat.bash"]
