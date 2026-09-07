# conquest-basic-mariadb

A minimal Docker setup for the [Conquest DICOM Server](https://github.com/marcelvanherk/Conquest-DICOM-Server):
one container running dgate plus the Apache/PHP web layer, and one running MariaDB.
Nothing else.

It builds Conquest from source on first start, generates `dicom.ini` and `acrnema.map`
from your `.env`, and serves DICOM and the web interface **directly on the host's own
interface**. There is no macvlan network to create, no reverse proxy, no identity
provider and no logging stack.

If you want TLS, single sign-on, per-user access control and an audit trail, that is a
different and much larger piece of work — this is deliberately not it.

## Requirements

- Linux host. The Conquest container uses `network_mode: host`, which behaves as
  described only on Linux; on Docker Desktop for macOS or Windows the container would
  not share the host's interfaces.
- Docker with the Compose plugin.
- Roughly 2 GB of free disk for the build, plus whatever your images need.

## Quick start

```sh
git clone https://github.com/DivNet-MakeIT/conquest-basic-mariadb.git
cd conquest-basic-mariadb
cp .env.example .env
# edit .env: set MYSQL_ROOT_PASSWORD and MYSQL_PASSWORD, and your AE title
docker compose up -d --build
docker compose logs -f conquest
```

The first start clones and compiles Conquest, which takes a few minutes. When the log
reaches the dgate banner, the server is listening.

- Web interface: `http://<host>:8080/` (`HTTP_PORT`)
- DICOM: port `4006` on the host (`CONQUEST_PORT`), AE title from `CONQUEST_AET`

Check it from another machine with any DICOM tool, for example:

```sh
echoscu -aec CONQUESTSRV1 <host> 4006
```

## Configuration

Everything lives in `.env`. The two values you must change are `MYSQL_ROOT_PASSWORD`
and `MYSQL_PASSWORD`; the rest has working defaults.

| Variable | Meaning |
|---|---|
| `CONQUEST_REPO` | Source Conquest is built from. Point it at a fork or a specific commit if you need to. |
| `CONQUEST_AET` | AE title of this server. |
| `CONQUEST_PORT` | DICOM port on the host. |
| `HTTP_PORT` | Web interface port on the host. `80` works if nothing else uses it. |
| `CONQUEST_REGENERATE_DATABASE` | `y` recreates the tables on first start. Set to `n` afterwards if you prefer. |
| `DICOM_DATA_PATH` | Path inside the container; it is bind-mounted from `./conquest-data`. |
| `CONQUEST_LOCAL_IP` | The server's own entry in `acrnema.map`. |

`dicom.ini` and `acrnema.map` are generated from `templates/` on the first start only.
After that they are yours: edit `conquest-src/dicom.ini` and restart the container.
Delete `conquest-src/` to force a clean rebuild.

## Where things are kept

| Directory | Contents |
|---|---|
| `conquest-src/` | The built Conquest tree, including `dicom.ini` and `acrnema.map`. |
| `conquest-data/` | The DICOM images. |
| `conquest-db/` | The MariaDB data directory. |

All three are bind mounts, so back them up with ordinary file tools. The database port
is published on `127.0.0.1` only and is not reachable from the network.

## Security

Read this before putting it on a network that carries patient data.

This configuration puts the Conquest web interface on the host interface with **no
authentication in front of it**, because that is what "a simple Docker version" means.
The Conquest web layer is an administrative interface: it can move, change and delete
studies, and Conquest's own documentation is explicit that the server belongs on a
trusted network, never on the open internet.

Practical minimum: run it on a segment only your modalities and workstations can reach,
and put a firewall rule in front of `HTTP_PORT`. From Conquest 1.5.0g onwards the engine
itself also has `AllowedIPs` / `DeniedIPs` lists in `dicom.ini`, per operation, which are
worth setting up — they are enforced inside dgate rather than in front of it.

If you need real authentication, TLS and an audit trail, you want a reverse proxy and an
identity provider in front of this, which is a different project.

## Upgrading Conquest

```sh
docker compose down
rm -rf conquest-src        # keeps conquest-data and conquest-db
docker compose up -d --build
```

Your images and database survive; only the built tree is replaced. Back up
`conquest-src/dicom.ini` first if you have edited it.

## Credits

Conquest DICOM Server is by Marcel van Herk and Lambert Zijp. This repository only
packages it; all the DICOM work is theirs.
