# synapse-purge

Purge old room events from synapse, a homeserver for the Matrix network.

Currently, only remote events are purged. Events sent by local users are not deleted, as they may represent the only copies of this content in existence.

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

The purge will keep old events back as far as `DAYS_TO_KEEP` days (120 by default).

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

## How it works

Synapse's [Purge History API](https://github.com/matrix-org/synapse/blob/master/docs/admin_api/purge_history_api.rst) works asynchronously. In order not to overload the homeserver, we purge rooms one-by-one.

The order of operation is as follows:

* The list of all rooms on the server is fetched from the database.
* For each room:
  * A purge is initiated through the synapse admin API.
  * The API is polled every half second for completion of the purge, until it is complete.
