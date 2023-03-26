# server-compose
A collection of sample [docker compose](https://docs.docker.com/compose/) files and configurations of popular [self hosted](https://www.reddit.com/r/selfhosted/) for quick reference! Sensible configurations, ports, and folder structures used wherever possible.

# How to Use

- Install [Docker](https://docs.docker.com/get-docker/).
- Download/copy the folders of the respective application(s) you want to install.
- Replace &lt;parameters&gt; with your values. More details on each application's link.
- Spin up the docker image.
```bash
docker compose up -d
```
# Applications 
:information_source:  _see [awesome-selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted) for an exhaustive list._

## Dashboard

- [Homepage by benphelps](https://github.com/benphelps/homepage) - A highly customizable homepage (or startpage / application dashboard) with Docker and service API integrations. Sample configurations are present for each of the applications.

## Media Streaming

- [Plex Media Server](https://www.plex.tv/) - Centralized home media playback system with a powerful central server.
- [Navidrome Music Server](https://www.navidrome.org) - Modern Music Server and Streamer, compatible with Subsonic/Airsonic.

## Media Downloaders
 :exclamation: **_Obligatory Piracy Caution Yarrr!_**

- [Transmission-OpenVPN](https://github.com/haugene/docker-transmission-openvpn) - Run [Transmission]()(Torrent Downloader) only when OpenVPN has an active tunnel. All *arr* applications will use it to download media.
- [Radarr](https://radarr.video/) - Radarr is an independent fork of Sonarr reworked for automatically downloading movies via Usenet and BitTorrent, à la Couchpotato. ([GitHub](https://github.com/Radarr/Radarr))
- [Sonarr](https://sonarr.tv/) - Automatic TV Shows downloader and manager for Usenet and BitTorrent. It can grab, sort and rename new episodes and automatically upgrade the quality of files already downloaded when a better quality format becomes available. ([GitHub](https://github.com/Sonarr/Sonarr))
- [Lidarr-on-steroids](https://github.com/youegraillot/lidarr-on-steroids) -A  modded version of [Lidarr](https://lidarr.audio/) with Native Deemix integration as an indexer and downloader for Lidarr.
- [Prowlarr](https://wiki.servarr.com/prowlarr) - Prowlarr is an indexer manager/proxy built on the popular *arr* stack to integrate with your various PVR apps.  ([GitHub](https://github.com/Prowlarr/Prowlarr))
- [Bazarr](https://www.bazarr.media/) - Bazarr is a companion application to Sonarr and Radarr that manages and downloads subtitles based on your requirements.([GitHub](https://github.com/morpheus65535/bazarr))
- [Deemix](https://deemix.app/) - deemix is a barebone deezer downloader library built from the ashes of Deezloader Remix.
- [Overseerr](https://overseerr.dev/) - Overseerr is a request management and media discovery tool built to work with your existing Plex ecosystem.([GitHub](https://github.com/sct/overseerr)) 

## Tools
- [Portainer](https://github.com/portainer/portainer) - Portainer is a lightweight management UI which allows you to easily manage your Docker containers
- [WatchTower](https://github.com/containrrr/watchtower) - A process for automating Docker container base image updates.
- [Scrutiny](https://github.com/AnalogJ/scrutiny) - WebUI for smartd S.M.A.R.T monitoring. Health check for hard drives.
- [Epic Games Store Weekly Free Games](https://github.com/claabs/epicgames-freegames-node) - Automatically login and redeem promotional free games from the Epic Games Store.
- [pyLoad](https://github.com/pyload/pyload) - Free and Open Source download manager written in Python and designed to be extremely lightweight, easily extensible and fully manageable via web.

## Monitoring
See [here](https://prometheus.io/docs/guides/cadvisor/) & [here](https://grafana.com/docs/grafana/latest/getting-started/get-started-grafana-prometheus) on how you can use cAdvisor, Prometheus and Grafana to monitor your server's usage.

- [cAdvisor](https://github.com/google/cadvisor) - Analyzes resource usage and performance characteristics of running docker containers.
- [Prometheus](https://prometheus.io/) - An open-source monitoring system with a dimensional data model, flexible query language, efficient time series database.
- [node-exporter](https://github.com/prometheus/node_exporter) - The Prometheus Node Exporter exposes a wide variety of hardware- and kernel-related metrics. 
- [Grafana](https://grafana.com/) - Grafana is a multi-platform open source analytics and interactive visualization web application. It provides charts, graphs, and alerts for the web when connected to supported data sources. 

## Development
- [SonarQube](https://docs.sonarqube.org/latest) - SonarQube is a self-managed, automatic code review tool that systematically helps you deliver clean code
- [PostgreSQL + pgAdmin](https://www.postgresql.org/) - PostgreSQL is a powerful, open source object-relational database system. PGAdmin is a web-based GUI tool used to interact with the Postgres database sessions.

## Passive Income / Bandwidth Sharing 
 :exclamation: **_Use with caution - They might damage your IP reputation._**
- [HoneyGain](https://www.honeygain.com/) - With Honeygain, you can make money by simply sharing your Internet.
- [EarnApp](https://earnapp.com/bandwidth) - Earn passive income while your devices rest.
- [PawnsApp](https://pawns.app/internet-sharing/) - Make passive money online by completing surveys and sharing your internet.

# Roadmap
- List will continue to grow, but will try to not be overwhelming.
- Individual README files for each compose.
- Interactive build script to spin up docker containers with automatic configurations.

# Contribution.
Feel free to open a pull request and add your favorite apps.
