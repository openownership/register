# Open Ownership Register

This repository contains the code which powers
https://register.openownership.org, Open Ownership's demonstration of a
global beneficial ownership register. The website uses Ruby on Rails and
runs on Heroku.

This README mainly provides instructions for running and maintaining the
live website. If you want to reuse the code for other projects, please feel
free to contact us on: tech@openownership.org and we'd be happy to advise.

## Contents

- [Installation](#installation)
- [Testing](#testing)
- [Development](#development)
- [Code overview](#code-overview)
- [A note on issue tracking](#a-note-on-issue-tracking)
- [A note on Git history](#a-note-on-git-history)

### Playbooks
These are a series of instructions for performing specific tasks, either in
normal (but not automated) production usage, or for one-off events.

- [Setting up a review app to mimic production](#setting-up-a-review-app-to-mimic-production)
- [Migrating to a new ElasticSearch host](#migrating-to-a-new-elasticsearch-host)
- [Adding new data source pages](adding-new-data-source-pages)

## Installation

Installation can be accomplished either using Docker or without. The newer installation method uses Docker for both the web app and any service dependencies, whereas the older installation method doesn't use Docker for the web app and leaves service dependencies using Docker optional.

### Docker

Configure your environment using the example file; these variables can be taken from the Heroku `openownership-register-v2-stag` app:

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

If you need to run Rails commands (e.g. to get a Rails console), there's no need to prefix with `bundle exec` or `bin/`; e.g.

```sh
docker compose exec web rails c
```

### Non-Docker

Install the Ruby version specified in `.ruby-version`.

Install the Node.js version specified in `package.json` `engines.node`.

Install Yarn stable as detailed in <https://yarnpkg.com/getting-started/install>.

Configure your environment using the example file; these variables can be taken from the Heroku `openownership-register-v2-stag` app:

```sh
cp .env.example .env
```

Install any service dependencies specified in `docker-compose.yml` (apart from `web`).

Run the setup script:

```sh
bin/setup
```

Start the app using the usual Rails commands (e.g. `rails server`).

Visit the app in your browser (for a different port, override `PORT`):

<http://localhost:3000>

## Testing

Testing can be accomplished either using Docker or without.

### Docker

Run the tests:

```sh
docker compose exec web test
```

### Non-Docker

Run the tests:

```sh
bin/test
```

## Development

### Docker

The app depends on a number of [Open Ownership](https://github.com/openownership) libraries which are included as Ruby gems in `Gemfile`. If working on code which spans multiple repositories, it can be convenient to be able to override the libraries and mount your latest code. To do so:

Uncomment the extra lib volumes in `docker-compose.yml`, pointing to the libraries' repositories.

Execute the `configure-dev-lib` script to configure Bundler:

```sh
docker compose exec web configure-dev-lib
```

Restart the services. Note that changes to local gem libraries do not get automatically detected, so if you need them to update, restart the services on demand.

If you want to restore things to their clean state, simply rebuild and restart the services.

## Code overview

The register is a fairly typical Ruby on Rails project, the main distinguishing features
are:

- We use MongoDB as our database
- We write custom Ruby classes for interacting with data sources in `app/clients`
- We write custom Ruby classes for performing other tasks, particularly data manipulation, in `app/service_objects`
- We use Sidekiq extensively to run tasks as a series of small asynchronous jobs, with custom workers in `app/workers`

Clients and Service Object are where we think the most useful code to others is likely to be found.

### Data model

The register's data model has evolved over time, and predates our
[Beneficial Ownership Data Standard](https://github.com/openownership/data-standard).
Because of that, we don't intend to promote it as a basis, or model for other projects.
That said, in order to understand our other code, it helps to have a basic overview of
the data model our importers, service object, etc deal with:

#### Database models
- `Entity` - People, companies and other entities that are involved in relationships
- `Relationship` - The linkages between entities that describe ownership or control. Also embeds a `Provenance` to show where that relationship came from.
- `Statement` - When a company 'states' that they have no beneficial owners, we store it here
- `DataSource` - A place where data comes from (e.g. a national register)
- `DataSourceStatistic` - A summary statistic calculated about all the data from a data source
- `Import` - A specific import of data from a data source
- `RawDataRecord` - A single record of data from a data source, e.g. a row in a CSV
- `RawDataProvenance` - A link between and entity/relationship, the raw data records which contained the data and the import where we saw the data
- `BodsExport` - A specific export of the database in the BODS format

#### Ruby models
These models don't get stored in the database, but are created on-the-fly to represent
particular things that help us reason about the data or display it more easily.

- `UnknownPersonsEntity` - When an ownership chain ends at an unknown, we represent the unknown person(s) with one of these
- `CircularOwnershipEntity` - When an ownership chain becomes a circle, we create one of these to terminate that cycle.
- `EntityGraph` - A graph or network of ownership, with nodes and edges representing entities and relationships. Used to back our graph visualisation and provide the graph traversal algorithm there.
- `InferredRelationship` - A relationship that can be inferred over one or more real relationships. In other words, a beneficial ownership chain.
- `InferredRelationshipGraph` - A graph or network of inferred relationships. This model holds a variety of graph traversal algorithms that allow us to compute things like the ultimate owner(s) of a company.

## A note on issue tracking

Please use Github Issues.

## A note on Git History

Originally this repository contained some sample data, taken from the various
data sources and external systems we interact with, which we used in various
tests. When planning to open-source this repository we received legal advice
that we should remove this data.

To do so, we first invented data to replace it, using the formats and structures
of the existing sources, but generic values. You'll note that all our tests use
companies with names like "Example UK Company", company numbers like 1234567 and
dates which are all based around starting points of 01/01/1950 (for people) or
01/01/2015 (for companies).

In addition to changing this data, we also purged the old data from our Git
history. You'll note that most of our importer tests in particular all suddenly
appear in the history in 2020, which is because of this purging.

If you have a need to see this history, we can provide limited access to a
private repository on an individual basis, please contact us or raise an issue
to request it and we can figure out the details.

Because of this purging, you can expect tests on older commits to be incomplete
or fail because of missing files. Again, if you have a reasonable need for them,
please ask and we'll see what we can do.

## Setting up a review app

Most parts of review app setup are automated, but note that we have a single
shared database hosted on MongoDB's Atlas which is re-used between apps because
there is no free MongoDB add-on on Heroku any more.

If you're testing database specifics, you might want to make a new cluster in
Atlas and change the `ATLAS_URI` configuration string in the review app's
settings. Note that you'll need to create a new 'project' because we're limited
to one free sandbox cluster per project.

If you're not creating a new database, you might want to reset the database to a
known state, since it's shared (and persists) between review apps. You can use
the postdeploy rake task to do so:

```shell
heroku run --app your-review-apps-name bin/rails postdeploy
```

**Remember that this might be shared by other review apps if you have multiple
running!**

## Setting up a review app to mimic production

Usually needed because you want to test a data import, or some other large
data modifying process, for which you need both the power and existing data
of the production site.

Create a review app in the usual way through the Heroku admin and then after the
review app is up and running:

Go into the "Resources" section of the review app (on Heroku) and:

- Click on "Change Dyno Type" and set it to the "Professional" dyno type (as
  you'll need to use these bigger instances).
- Upgrade MemCachier to a higher plan (production uses a 1GB cache, but if you
  don't need to test cache effectiveness on this review app you can use a much
  smaller plan, e.g. 250MB).
- Remove the Heroku Redis instance
- Remove the SearchBox Elasticsearch instance
- Add Redis: `heroku addons:create openredis:micro --app openownership-register--pr-XXX`
- Set the `REDIS_PROVIDER` config var to `OPENREDIS_URL` so that the app can talk
  to redis

Whilst these are getting set up, we need a copy of the production db to
have relevant data.

- Go to https://cloud.mongodb.com/ (login details in 1Password)
- Create a 'cluster' to match the production cluster:
  - Cloud provider & Region: AWS Ireland (eu-west-1)
  - Cluster Tier: M20, scale storage to match production (60GB)
  - Additional settings: Select the same version (3.6)
  - Cluster name: the branch name you're testing
- Once that's created, go to the cluster and select 'Migrate data to this
  cluster" from the [...] menu on the right hand side.

Once this has spun up the instance there are a couple more steps to get an
accesible instance:

- Add a database user through the Database Access menu on the left
- Enable all public IP traffic through the Network Access menu on the left

We also need to clone the production elastic search instance.

- Go to https://cloud.elastic.co/deployments (login details in 1Password)
- Click 'Create deployment'
- Fill-in the following options:
  - Name: Ticket name (e.g. OO-182 Upgrade Elasticsearch)
  - Cloud platform: Leave as AWS
  - Region: EU (Ireland)
  - Version: Same as production (hopefully the default)
  - Tick the box 'Select a deployment to restore from its latest snapshot' and
    choose 'Production' from the dropdown that appears
  - 'Optimize your deployment': Leave as the default
  - Click 'Customize deployment' to set the instance sizes etc
  - Reduce 'Fault tolerance' to '1 node'
  - Select 2GB of ram per node
  - Disable 'APM'
- Finally, click 'Create deployment' and wait for it to start up.
- Copy the password for the `elastic` user that's shown to you on the next page

Back in the Heroku console for the review app, we need to set up env variables
to be able to access these services

- Add the full url to your new elastic cluster into a new `ELASTIC_CLOUD_URL`
  setting – since it uses Basic Auth, the URL should end up like:
  `https://elastic:<password>@<host>`, where `<password>` is what you copied
  from the elastic cloud console.
- Update the `ELASTICSEARCH_URL_ENV_NAME` config variable to `ELASTIC_CLOUD_URL`
- Add the full url to the new Altas deployment into a new `ATLAS_URI` setting
  (click on the cluster in Atlas, then the [CONNECT] button)
- Update `MONGODB_URI_ENV_NAME` to `ATLAS_URI`

Now, locally, sanitize the database copy by running:
  `heroku run --app openownership-register--pr-XXX bin/rails sanitize`

## Migrating to a new Elasticsearch host

This was done in order to upgrade Elasticsearch from 5.6.9 (paid for through
Heroku) to 6.6.1 (on a separate Elastic cloud account), as our experience doing
the upgrade in-place found significant issues. However, it should apply to almost
any data migration where you can't use a simpler method (like just restoring
from a snapshot).

As a prerequisite, this assumes you spun up a new cluster somewhere and it's
running, but empty.

### Create an index in the new cluster

You need to copy across the settings that elasticsearch-model would normally
make for us. The easiest way to find them is asking Elasticsearch itself. e.g.

`GET https://<old-elasticsearch-host>/open_ownership_register_entities_production`

This is what they looked like at the time of writing, but check `index`
definitions in our models (and the existing ES cluster) to make sure.

```json
{
  "aliases": {},
  "mappings": {
    "_doc": {
      "properties": {
        "company_number": {
          "type": "keyword"
        },
        "country_code": {
          "type": "keyword"
        },
        "lang_code": {
          "type": "keyword"
        },
        "name": {
          "type": "text"
        },
        "name_transliterated": {
          "type": "text"
        },
        "type": {
          "type": "keyword"
        }
      }
    }
  },
  "settings": {
    "number_of_shards": "1",
    "number_of_replicas": "0"
  }
}
```

To create a replica index, you just supply those same settings via the api:

```
PUT <new-elasticsearch-host/open_ownership_register_entities_production
{
  // JSON from above
}
```

### Reindex from the existing host

Using Elasticsearch's `_reindex` api, you can request your new cluster loads
data from the existing one:

```
POST <new-elasticsearch-host>/_reindex
{
  "source": {
    "remote": {
      "host": "https://<old-elasticsearch-host>:9243",
      "username": "elastic",
      "password": "PASSWORD"
    },
    "index": "open_ownership_register_entities_production",
    "query": {
      "match_all": {}
    }
  },
  "dest": {
    "index": "open_ownership_register_entities_production"
  }
}
```

Note: This request will try to wait for the full reindex to happen, which may
take up to an hour or more, so it's likely to time out. The reindex task keeps
going though, and you can check on it with the `_tasks` api:

`GET <new-elasticsearch-host>/_tasks?actions=*reindex`

When the response is `nodes:{}` (i.e. an empty list of tasks) the reindex is
done

## Adding new data source pages

The DataSource model provides the content and statistics collection for the PSC
data source 'dashboard' on the site. To add new pages for other sources, you can
just create new data source instances:

```Ruby
DataSource.create(
  name: 'My new data source'
  url: 'Link to the original source'
  overview: 'Markdown content for the first overview/intro section'
  data_availalability: 'Markdown content for the data availability/license'
  timeline_url: 'Twitter timeline url for embedded tweet timeline'
)
```

I've stored the markdown for the PSC register in /db so that it's easier to diff
and edit, then made a data migration to load it in.

If you want statistics for that page also, you'll need to implement a
'calculator' like the `PscStatsCalculator` to create some
`DataSourceStatistics`. This interface is still a work in progress, but the
current code and views assume that you'll have a total count stat, which
represents the total number of companies in the real world, a register total
stat representing how many of those companies the register has data for and then
some other `types` you'll define in `DataSourceStatistic::Types` for whatever your
other stats are. At the moment, it's assumed that stats are a count of companies
that meet some criteria. If this cannot be expressed as a percentage of the
total you should update the method `show_as_percentage?` to exclude it.
