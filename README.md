# benchmark_infrastructure

Ansible setup that builds and serves the 13 LargeRDFBench datasets as QLever
SPARQL endpoints, one dataset per container, fronted by a shared Caddy that
enforces an access token on every query.

## Architecture

- **One QLever container per dataset**, each with its own on-disk index
   and its own port. QLever itself is **not**
  exposed to the host, it only listens on a private docker network.
- **One shared Caddy container** per physical machine is the only thing that
  publishes ports to the host. It rejects any request whose `Authorization`
  header isn't exactly `Bearer <qlever_access_token>` (see
  `templates/Caddyfile.j2`), then reverse-proxies the rest to the matching
  QLever container.
- Right now every dataset in the `endpoints` inventory group points at the
  **same physical machine**, they're just different ports on one box. To
  move a dataset to a real separate host later, give it its own
  `ansible_host` in `inventory-qlever.yml`; nothing else needs to change.

## Prerequisites

- Ansible on your laptop
- SSH access to the target machine. A dedicated key is recommended:
  ```bash
  ssh-keygen -t ed25519 -f ~/.ssh/idlab -C "idlab"
  ssh-copy-id -i ~/.ssh/idlab.pub root@<host>
  ssh-add ~/.ssh/idlab
  ```


## Inventory

`inventory-qlever.yml` lists one entry per dataset under the `endpoints`
group, each with its own `ansible_host` and `endpoint_port`:

```yaml
Affymetrix: { ansible_host: 10.10.160.149, endpoint_port: 3002, endpoint_engine: qlever }
ChEBI:      { ansible_host: 10.10.160.149, endpoint_port: 3003, endpoint_engine: qlever }
...
```

Connection settings (`ansible_user`, `ansible_ssh_private_key_file`) live
once in `all.vars` and apply to every dataset. Tunables shared by all
datasets (QLever memory limits, the access token, Caddy image, etc.) live in
`group_vars/all.yml`.

## Usage

Run these roughly in order on a fresh machine:

```bash
make ping        # check the host is reachable
make common       # base provisioning: disk, NAT, packages
make endpoints    # install Docker, pull the QLever image
make transfer     # build + serve every dataset's QLever index behind Caddy
make get-ip       # print each dataset's host address
```


`make transfer` builds each dataset's index **one at a time**
(`throttle: 1` in `tasks/start_endpoint.yml`), with 13 datasets sharing one
RAM-limited host, building them in parallel would OOM the machine. Indexing
also disables QLever's parallel parser (`--parallel-parsing false`), since
some of these datasets are concatenations of multiple Turtle files with
`@prefix` blocks partway through, which the parallel parser rejects.



## Querying an endpoint

Every request needs the access token:

```bash
curl -G "http://<host>:<port>/sparql" \
  --data-urlencode "query=ASK{?s ?p ?o}" \
  -H "Accept: application/sparql-results+json" \
  -H "Authorization: Bearer <qlever_access_token>"
```

## Known limitations

- **RAM is tight.** 13 QLever servers share one host's page cache for their
  on-disk indexes (several multi-GB)

