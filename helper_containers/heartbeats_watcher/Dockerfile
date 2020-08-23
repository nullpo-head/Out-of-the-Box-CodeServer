FROM mcr.microsoft.com/azure-cli:latest

RUN az login

WORKDIR /watch_heartbeats
COPY watch_heartbeats.py /watch_heartbeats/

ENTRYPOINT ["python", "/watch_heartbeats/watch_heartbeats.py"]
