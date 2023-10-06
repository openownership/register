# Register

Register is a web app for the [Open Ownership](https://www.openownership.org/en/) [Register](https://github.com/openownership/register) project.

This repository contains the code which powers <https://register.openownership.org>, Open Ownership's demonstration of a global beneficial ownership register.

The website uses Ruby on Rails and runs on Heroku.

This README mainly provides instructions for running and maintaining the live website. If you want to reuse the code for other projects, please feel free to contact us on <tech@openownership.org> and we'd be happy to advise.

## Installation

Configure your environment using the example file (e.g. Heroku `openownership-register-stg` app config, if you have access):

```sh
cp .env.example .env
```

Install and boot:

```sh
docker compose up
```

Wait for the healthchecks to become `healthy`:

```sh
watch docker ps
```

Visit the app in your browser (for a different port, override `WEB_PORT`):

<http://localhost:14972>

## Testing

Run the tests:

```sh
docker compose exec web test
```

## Development

If you need to run Rails commands (e.g. to get a Rails console), there's no need to prefix with `bundle exec` or `bin/`:

```sh
docker compose exec web rails c
```

The app depends on a number of libraries which are included as Ruby gems in `Gemfile`.
If you're working on code spanning multiple repositories, it can be convenient to be able to override the libraries and mount your latest code within the containers.
To do so, set the `DC_WEB_LIB_*` env vars (see `.env.example`), and restart the services.
Note that changes to local gem libraries do not get automatically detected, so if you need them to update, restart the services manually.
If you want to restore things to a clean state, simply ensure that `DC_WEB_LIB_*` are not set, rebuild, and restart the services.

## Related repositories

This repository contains only the web app. There are a number of related repositories within this project, including:

### Libraries

- <https://github.com/openownership/register-common>
- <https://github.com/openownership/register-sources-bods>
- <https://github.com/openownership/register-sources-dk>
- <https://github.com/openownership/register-sources-oc>
- <https://github.com/openownership/register-sources-psc>
- <https://github.com/openownership/register-sources-sk>

### Ingesters

- <https://github.com/openownership/register-ingester-dk>
- <https://github.com/openownership/register-ingester-oc>
- <https://github.com/openownership/register-ingester-psc>
- <https://github.com/openownership/register-ingester-sk>

### Transformers

- <https://github.com/openownership/register-transformer-dk>
- <https://github.com/openownership/register-transformer-psc>
- <https://github.com/openownership/register-transformer-sk>

## Archived documentation

This project has quite an extensive history, and a lot has changed over that time.
Register 1 used MongoDB, and contained most things within a single repository.
Register 2 saw extensive rearchitecture, splitting out the data ingestion and transformation into multiple repositories, and moving to Elasticsearch and AWS S3 with read-only access.
Because of this, much of the documentation which used to be in this README is no longer relevant, so it has been removed. If you want to read it, you can [view archived documentation](https://github.com/openownership/register/blob/6d04ea12f6f50eaef32f028dc9509e0d6b1bc82d/README.markdown).
