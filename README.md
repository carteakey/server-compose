# <img src="_assets/docker-compose.png" height="30" align="center"/> server-compose

A collection of sample [docker compose](https://docs.docker.com/compose/) files and configurations of popular [self hosted](https://www.reddit.com/r/selfhosted/) for quick reference! Sensible configurations, ports, and folder structures used wherever possible.

# How to Use

- Install [Docker](https://docs.docker.com/get-docker/).
- Download/Clone the github repo.
```bash
git clone https://github.com/carteakey/server-compose.git
```
- Open the folders of the respective application(s) you want to install.
```bash
cd <<your application>>
```
- Replace &lt;parameters&gt; with your values. More details on each application's link and README.md of each folder.
- Spin up the docker image.

```bash
docker compose up -d
```

- To stop and remove all containers of the application run:

```
docker compose down
```

# Applications

:information_source: _Check out [awesome-selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted) for an exhaustive list._

|Icon|Description|
|----|----|
|<img src="_assets/docker-compose.png" height="18" align="top"/> | Link to Compose file(s). 
| <img src="_assets/github.png" height="18" align="top"/> | Link to GitHub Repo.


## Dashboard

- [Homepage by benphelps](https://github.com/benphelps/homepage) - A highly customizable homepage (or startpage / application dashboard) with Docker and service API integrations. Sample configurations are present for each of the applications. 
<a href="https://github.com/benphelps/homepage"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="homepage"><img src="_assets/docker-compose.png" height="18" align="top"/></a>

## Media Streaming

- [Plex Media Server](https://www.plex.tv/) - Centralized home media playback system with a powerful central server.
<a href="plexmediaserver"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [Jellyfin](https://jellyfin.org) - Jellyfin is an alternative to the proprietary Emby and Plex, to provide media from a server to end-user devices via multiple apps.
<a href="https://github.com/jellyfin/jellyfin"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="jellyfin"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [Navidrome Music Server](https://www.navidrome.org) - Modern Music Server and Streamer, compatible with Subsonic/Airsonic.
<a href="https://github.com/navidrome/navidrome"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="navidrome"><img src="_assets/docker-compose.png" height="18" align="top"/></a>

## Media Downloaders

:exclamation: **_Obligatory Piracy Caution Yarrr!_**

- [Transmission-OpenVPN](https://haugene.github.io/docker-transmission-openvpn/) - Run [Transmission ]()(Torrent Downloader) only when OpenVPN has an active tunnel. All _arr_ applications will use it to download media.
<a href="https://github.com/haugene/docker-transmission-openvpn"><img src="_assets/github.png" height="18" align="top"/></a> 
<a href="transmission-openvpn"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [Radarr](https://radarr.video/) - Radarr is an independent fork of Sonarr reworked for automatically downloading movies via Usenet and BitTorrent, à la Couchpotato.
<a href="https://github.com/Radarr/Radarr"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="radarr"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [Sonarr](https://sonarr.tv/) - Automatic TV Shows downloader and manager for Usenet and BitTorrent. It can grab, sort and rename new episodes and automatically upgrade the quality of files already downloaded when a better quality format becomes available. 
<a href="https://github.com/Sonarr/Sonarr"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="sonarr"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [Lidarr-on-steroids](https://github.com/youegraillot/lidarr-on-steroids) -A modded version of [Lidarr](https://lidarr.audio/) with Native Deemix integration as an indexer and downloader for Lidarr.
<a href="https://github.com/youegraillot/lidarr-on-steroids"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="lidarr-on-steroids"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [Prowlarr](https://wiki.servarr.com/prowlarr) - Prowlarr is an indexer manager/proxy built on the popular _arr_ stack to integrate with your various PVR apps. 
<a href="https://github.com/Prowlarr/Prowlarr"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="prowlarr"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [Bazarr](https://www.bazarr.media/) - Bazarr is a companion application to Sonarr and Radarr that manages and downloads subtitles based on requirements.
<a href="https://github.com/morpheus65535/bazarr"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="bazarr"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [Deemix](https://deemix.app/) - deemix is a barebone deezer downloader library built from the ashes of Deezloader Remix.
<a href="deemix"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [Overseerr](https://overseerr.dev/) - Overseerr is a request management and media discovery tool built to work with your existing Plex ecosystem.
<a href="https://github.com/sct/overseerr"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="overseerr"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
## Tools
- [Portainer](https://www.portainer.io) - Portainer is a lightweight management UI which allows you to easily manage your Docker containers.
<a href="https://github.com/portainer/portainer"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="portainer"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [WatchTower](https://containrrr.dev/watchtower/) - A process for automating Docker container base image updates.
<a href="https://github.com/containrrr/watchtower"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="watchtower"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [Scrutiny](https://github.com/AnalogJ/scrutiny) - WebUI for smartd S.M.A.R.T monitoring. Health check for hard drives.
<a href="https://github.com/AnalogJ/scrutiny"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="scrutiny"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [Epic Games Store Weekly Free Games](https://hub.docker.com/r/charlocharlie/epicgames-freegames) - Automatically login and redeem promotional free games from the Epic Games Store.
<a href="https://github.com/claabs/epicgames-freegames-node"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="epicgames-freegames"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [pyLoad](https://pyload.net) - Free and Open Source download manager written in Python and designed to be extremely lightweight, easily extensible and fully manageable via web.
<a href="https://github.com/pyload/pyload"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="pyload"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [changedetection.io](https://github.com/dgtlmoon/changedetection.io) - Web Site Change Detection, Restock monitoring and notifications.
<a href="https://github.com/dgtlmoon/changedetection.io"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="changedetection.io"><img src="_assets/docker-compose.png" height="18" align="top"/></a>

## Monitoring

See [here](https://prometheus.io/docs/guides/cadvisor/) & [here](https://grafana.com/docs/grafana/latest/getting-started/get-started-grafana-prometheus) on how you can use cAdvisor, Prometheus and Grafana to monitor your server's usage.

- [cAdvisor](https://github.com/google/cadvisor) - Analyzes resource usage and performance characteristics of running docker containers.
<a href="https://github.com/google/cadvisor"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="cadvisor"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [Prometheus](https://prometheus.io/) - An open-source monitoring system with a dimensional data model, flexible query language, efficient time series database.
<a href="https://github.com/prometheus/prometheus"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="prometheus"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [node-exporter](https://github.com/prometheus/node_exporter) - The Prometheus Node Exporter exposes a wide variety of hardware- and kernel-related metrics.
<a href="https://github.com/prometheus/node_exporter"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="node-exporter"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [Grafana](https://grafana.com/) - Grafana is a multi-platform open source analytics and interactive visualization web application. It provides charts, graphs, and alerts for the web when connected to supported data sources.
<a href="https://github.com/grafana/grafana"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="grafana"><img src="_assets/docker-compose.png" height="18" align="top"/></a>

## Development

- [SonarQube](https://docs.sonarqube.org/latest) - SonarQube is a self-managed, automatic code review tool that systematically helps you deliver clean code.
<a href="https://github.com/SonarSource/sonarqube"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="sonarqube"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [PostgreSQL + pgAdmin](https://www.postgresql.org/) - PostgreSQL is a powerful, open source object-relational database system. PGAdmin is a web-based GUI tool used to interact with the Postgres database sessions.
<a href="https://github.com/postgres/postgres"><img src="_assets/github.png" height="18" align="top"/></a>
<a href="postgres-pgadmin"><img src="_assets/docker-compose.png" height="18" align="top"/></a>

## Passive Income / Bandwidth Sharing

:exclamation: **_Use with caution - They might damage your IP reputation._**

- [HoneyGain](https://www.honeygain.com/) - With Honeygain, you can make money by simply sharing your Internet.
<a href="honeygain"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [EarnApp](https://earnapp.com/bandwidth) - Earn passive income while your devices rest.
<a href="earnapp"><img src="_assets/docker-compose.png" height="18" align="top"/></a>
- [PawnsApp](https://pawns.app/internet-sharing/) - Make passive money online by completing surveys and sharing your internet. 
<a href="pawnscli"><img src="_assets/docker-compose.png" height="18" align="top"/></a>

# Roadmap

- List will continue to grow, but will try to not be overwhelming.
- Individual README files for each compose.
- Interactive build script to spin up docker containers with automatic configurations.

# Contribution.

Feel free to open a pull request and add your favorite apps.
