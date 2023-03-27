# Homepage

## Links:
- Web UI: http://localhost:3000/
- Reference: https://gethomepage.dev/en/installation/
- GitHub: https://github.com/benphelps/homepage
## Compose
Folder Structure:
```
.
└── docker-compose.yml
└── config
    ├── bookmarks.yaml
    ├── docker.yaml
    ├── services.yaml
    ├── settings.yaml
    └── widgets.yaml
└── README.md
```

[docker-compose.yml]()
```
version: "3.3"
services:
  dockerproxy:
      image: ghcr.io/tecnativa/docker-socket-proxy:latest
      container_name: dockerproxy
      environment:
          - CONTAINERS=1 # Allow access to viewing containers
          - POST=0 # Disallow any POST operations (effectively read-only)
      ports:
          - 2375:2375
      volumes:
          - /var/run/docker.sock:/var/run/docker.sock:ro # Mounted as read-only
      restart: unless-stopped

  homepage:
      image: ghcr.io/benphelps/homepage:latest
      container_name: homepage
      volumes:
          - ./config:/app/config
          - /mnt/hdd:/hdd #Path to your additional drives, if any.
      ports:
          - 3000:3000
      restart: unless-stopped
```

## Configuration


