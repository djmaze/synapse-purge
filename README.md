# synapse-purge

Purge old room events from synapse, a homeserver for the Matrix network.

## Prerequisites

You need:

* access to synapse's database (postgresql only, read access is sufficient)
* an admin account on the homeserver
* Ruby or Docker installed on your server

As you need direct database access, the app probably needs to run on the same host / network as synapse.

## Installation

Without Docker, clone this repository first. Then run:

```bash
bundle install --without development
```

With Docker, use the supplied `docker-compose.yml` file as an example.

## Configuration

Copy `.env.example` to `.env` and adjust the homeserver URL, admin credentials and database URL for your configuration.

## Running

Without Docker:

```bash
ruby synapse-purge.rb
```

With Docker Compose:

```bash
docker-compose run --rm app
```

Alternatively, deploy using supplied `docker-compose.yml` on your Docker swarm.
