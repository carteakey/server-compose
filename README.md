# <img src="_assets/docker-compose.png" height="30" align="center"/> server-compose

A collection of sample [docker compose](https://docs.docker.com/compose/) files and configurations of popular [self hosted](https://www.reddit.com/r/selfhosted/) for quick reference! Sensible configurations, ports, and folder structures used wherever possible.

# How to Use

- Install [Docker](https://docs.docker.com/get-docker/).
- Download / Clone the github repo.
```bash
cd /opt/
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

Alternatively, use the excellent [Dockge](#dockge) to manage your stacks.

# Applications

:information_source: _Check out [awesome-selfhosted](https://github.com/awesome-selfhosted/awesome-selfhosted) for an exhaustive list._
Sure, I'll merge all the entries into one comprehensive table with the category as the first column:

| Category           | Name                                         | Description | GitHub Repo | Docker Compose Link |
|--------------------|----------------------------------------------|-------------|-------------|---------------------|
| **Dashboard**      | [Homepage by benphelps](https://github.com/benphelps/homepage) | A highly customizable homepage (or startpage / application dashboard) with Docker and service API integrations. Sample configurations are present for most of the listed apps. | [GitHub](https://github.com/benphelps/homepage) | [Compose](homepage) |
| **Media Streaming**| [Plex Media Server](https://www.plex.tv/)    | Centralized home media playback system with a powerful central server. | | [Compose](plexmediaserver) |
|                    | [Jellyfin](https://jellyfin.org)             | Jellyfin is an alternative to the proprietary Emby and Plex, to provide media from a server to end-user devices via multiple apps. | [GitHub](https://github.com/jellyfin/jellyfin) | [Compose](jellyfin) |
|                    | [Navidrome Music Server](https://www.navidrome.org) | Modern Music Server and Streamer, compatible with Subsonic/Airsonic. | [GitHub](https://github.com/navidrome/navidrome) | [Compose](navidrome) |
|                    | [TubeArchivist](https://www.tubearchivist.com/) | Your self hosted YouTube media server. | [GitHub](https://github.com/tubearchivist/tubearchivist) | [Compose](tubearchivist) |
| **Media Downloaders** | [Transmission-OpenVPN](https://haugene.github.io/docker-transmission-openvpn/) | Run Transmission (Torrent Downloader) only when OpenVPN has an active tunnel. All _arr_ applications will use it to download media. | [GitHub](https://github.com/haugene/docker-transmission-openvpn) | [Compose](transmission-openvpn) |
|                    | [Radarr](https://radarr.video/)              | Radarr is an independent fork of Sonarr reworked for automatically downloading movies via Usenet and BitTorrent, à la Couchpotato. | [GitHub](https://github.com/Radarr/Radarr) | [Compose](radarr) |
|                    | [Sonarr](https://sonarr.tv/)                 | Automatic TV Shows downloader and manager for Usenet and BitTorrent. | [GitHub](https://github.com/Sonarr/Sonarr) | [Compose](sonarr) |
|                    | [Lidarr-on-steroids](https://github.com/youegraillot/lidarr-on-steroids) | A modded version of Lidarr with Native Deemix integration as an indexer and downloader for Lidarr. | [GitHub](https://github.com/youegraillot/lidarr-on-steroids) | [Compose](lidarr-on-steroids) |
|                    | [Prowlarr](https://wiki.servarr.com/prowlarr) | Indexer manager/proxy built on the popular _arr_ stack to integrate with your PVR apps. | [GitHub](https://github.com/Prowlarr/Prowlarr) | [Compose](prowlarr) |
|                    | [Bazarr](https://www.bazarr.media/)          | Companion application to Sonarr and Radarr that manages and downloads subtitles. | [GitHub](https://github.com/morpheus65535/bazarr) | [Compose](bazarr) |
|                    | [Deemix](https://deemix.app/)                | Barebone deezer downloader library. | | [Compose](deemix) |
|                    | [Overseerr](https://overseerr.dev/)          | Request management and media discovery tool for Plex ecosystem. | [GitHub](https://github.com/sct/overseerr) | [Compose](overseerr) |
| **Home Automation**| [Home Assistant](https://www.home-assistant.io) | Open source home automation that puts local control and privacy first. | [GitHub](https://github.com/home-assistant/core) | [Compose](home-assistant) |
|                    | [Nextcloud](https://nextcloud.com/install/#instructions-server) | A safe home for all your data. Access & share your files, calendars, contacts, mail & more from any device, on your terms. | [GitHub](https://github.com/nextcloud/server) | [Compose](nextcloud) |
| **Container Management**|[Portainer](https://www.portainer.io)        | Lightweight management UI for Docker containers. | [GitHub](https://github.com/portainer/portainer) | [Compose](portainer) |
|                    | [WatchTower](https://containrrr.dev/watchtower/) | Automates Docker container base image updates. | [GitHub](https://github.com/containrrr/watchtower) | [Compose](watchtower) |
|                    | <a id="dockge"></a>[Dockge](https://dockge.kuma.pet) | A fancy, easy-to-use and reactive self-hosted docker compose.yaml stack-oriented manager. | [GitHub](https://github.com/louislam/dockge) | [Compose](dockge) |
| **Tools**          | [Epic Games Store Weekly Free Games](https://hub.docker.com/r/charlocharlie/epicgames-freegames) | Automatically redeem promotional free games from the Epic Games Store. | [GitHub](https://github.com/claabs/epicgames-freegames-node) | [Compose](epicgames-freegames) |
|                    | [pyLoad](https://pyload.net)                 | Free & Open Source lightweight download manager written in Python. | [GitHub](https://github.com/pyload/pyload) | [Compose](pyload) |
|                    | [changedetection.io](https://github.com/dgtlmoon/changedetection.io) | Web Site Change Detection and notifications. | [GitHub](https://github.com/dgtlmoon/changedetection.io) | [Compose](changedetection.io) |
|                    | [FileFlows](https://fileflows.com/)          | Fileflows lets you process files through a simple rule flow. | [GitHub](https://github.com/revenz/FileFlows) | [Compose](fileflows) |
| **Finance**        | [Firefly III](https://www.firefly-iii.org) | "Firefly III" is a (self-hosted) manager for your personal finances. | [GitHub](https://github.com/firefly-iii/firefly-iii/) | [Compose](firefly-iii) |
|                    | [Actual Budget](https://actualbudget.org)                 | Actual Budget is a super fast and privacy-focused app for managing your finances. | [GitHub](https://github.com/actualbudget/actual) | [Compose](actual-budget) |
| **Server Monitoring**     | [cAdvisor](https://github.com/google/cadvisor) | Analyzes resource usage and performance of running docker containers. | [GitHub](https://github.com/google/cadvisor) | [Compose](cadvisor) |
|                    | [Prometheus](https://prometheus.io/)         | Open-source monitoring system. | [GitHub](https://github.com/prometheus/prometheus) | [Compose](prometheus) |
|                    | [node-exporter](https://github.com/prometheus/node_exporter) | Exposes hardware- and kernel-related metrics. | [GitHub](https://github.com/prometheus/node_exporter) | [Compose](node-exporter) |
|                    | [Grafana](https://grafana.com/)              | Multi-platform open source analytics and interactive visualization web application. | [GitHub](https://github.com/grafana/grafana) | [Compose](grafana) |
|                    | [Scrutiny](https://github.com/AnalogJ/scrutiny) | WebUI for smartd S.M.A.R.T monitoring. | [GitHub](https://github.com/AnalogJ/scrutiny) | [Compose](scrutiny) |
| **Passive Income / Bandwidth Sharing** | [HoneyGain](https://www.honeygain.com/) | Make money by sharing your Internet. | | [Compose](honeygain) |
|                    | [EarnApp](https://earnapp.com/bandwidth)     | Earn passive income while your devices rest. | | [Compose](earnapp) |
|                    | [PawnsApp](https://pawns.app/internet-sharing/) | Make passive money online by sharing your internet. | | [Compose](pawnscli) |



# Roadmap

- List will continue to grow, but will try to not be overwhelming.
- Website (Maybe)
- Individual README files for each compose.

# Contribution.

Feel free to open a pull request and add your favorite apps.
