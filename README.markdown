# OpenOwnership Register

## Setup

Install the version of ruby specified in `.ruby-version` using your favourite ruby version manager.

Install and run bundler:

```bash
gem install bundler
bundle
```

Create an `.env.local` and add in the various required env vars from `.env` – generally, you can use config values from the Heroku app `openownership-register-staging`.

For data stores and other local services, you can use Docker Compose:

```bash
docker-compose up -d
```

Alternatively, you can use your own local method for running these services. See the `docker-compose.yml` file for the required services and versions, and the `.env` file for expected config.

Run the setup command, which will create, seed and add indexes to the DB and elasticsearch

```bash
bin/setup
```

Then you're ready to use the usual `rails` commands (like `rails serve`) to run / work with the app.

To run tests:

```bash
bundle exec rspec
```

## Import more data

The above will create a few example records, but you can import a subset of real data, by running:

```bash
rake postdeploy
```

## Writing an importer

Importers are intended to run multiple times and so must be idempotent. If the source data itself is idempotent (i.e. it doesn't matter which order records are imported), then importers can be parallelised.

## Running data imports on production

We run all of the standard 'chunked' imports (UK, SK and DK currently) together
in order to save time and effort over the whole import and integrity checking
process.

### Initial assumptions / prerequisites:

- No other import is currently running or has been triggered to run.
- No worker dyno is currently running.

### Pre-import

1. Make a backup of the MongoDB database via the mLabs console (from the Heroku console).
1. Note down the current `Entity.count` and `Relationship.count` via the Rails console.
1. Open the Papertrail console (via the Heroku console) to monitor logs.
1. Open the [sidekiq admin panel](https://register.openownership.org/admin/sidekiq) to monitor the background jobs.
   - The login details for this can be found via the Config Vars for the production app, in the Heroku console.
1. Upgrade openredis to the 'Extra large' instance type so that it has enough
   room to store all of the downloaded data.

### Import

1. Trigger the imports:
   - `heroku run:detached --app openownership-register bin/rails psc:trigger`
   - `heroku run:detached --app openownership-register -s performance-m bin/rails sk:trigger`
   - `heroku run:detached --app openownership-register -s performance-m bin/rails dk:trigger`
1. Now turn on **1** worker dyno, making sure it's a `performance-l`.
1. Note down the time the worker was started.
1. Monitor the status of the import via the Sidekiq admin panel, you should see
   a spike in 'Enqueued' jobs as we download the PSC dump, a gradual increase as
   the DK/SK triggers download data faster than we can process it, then the
   number gradually decreasing as we work our way through the queue.

Note: The full import takes roughly 36 hours, so don't need to constantly monitor things!

Note: The DK import trigger needs a lot of memory to run, hence the
performance-m dyno.

Note when evaluating errors that 'failed' in the sidekiq web admin
doesn't mean the job wasn't successful later. Jobs that fail are automatically
retried up to 25 times so if e.g. an api timed out, they might succeed on a
retry. 'Dead' jobs are the main concern, as these are jobs which failed every
retry and so weren't run. See: https://github.com/mperham/sidekiq/wiki/API#dead
for docs on how to access those jobs.

### Post-import

Once all jobs have been processed in the Sidekiq admin panel (/admin/sidekiq)

1. Shut down the worker dyno in the Heroku console so no workers are running.
1. Downgrade openredis to micro again.
1. From the logs, note down the timestamp when the last worker job finished and note down how long the whole import took.
1. Note down the new `Entity.count` and `Relationship.count` and note down the differences (can share these with the team on Slack if substantial).
1. Run the [`EntityIntegrityChecker`](#the-entityintegritychecker) – and then note down the final results from the logs.
1. Update [the tracking spreadsheet](https://docs.google.com/spreadsheets/d/1OWABqrHis4fznLZwTGu9TEpZjtRrD4Ko7T0kC7mFcCw/edit#gid=0) with the stats from the integrity checking

## The `EntityIntegrityChecker`

… is used to detect various potential issues with entities in the database.

Currently, all issues detected + a final summary are outputted to the log.

It doesn't perform any fixes, but it can be used as the basis for a script / rake task that performs fixes as it emits issues, to be handled separately. See examples under `lib/tasks/migrations`.

Most of the checks are specific to _legal entities_, but some may also be for _natural persons_. Where a check is for both a `type` value will be outputted in the individual log lines.

To run the checker in production:

```bash
heroku run:detached -s performance-l --app openownership-register time bin/rails runner "EntityIntegrityChecker.new.check_all"
```

## The `NaturalPersonsDuplicatesMerger`

… is used to find and merge natural person entities that match on all of `name`, `address` and `dob` (all must be set and not empty).

To run the checker in production:

```bash
heroku run:detached -s performance-l --app openownership-register time bin/rails runner "NaturalPersonsDuplicatesMerger.new.run"
```

Check the log for results and stats.

### Un-merging people

It's possible to remove one or more people from a 'merged' group by following
these steps:

1. Identify the entity(ies) you want to un-merge. The easiest way to find their
   mongodb ids is by finding a Relationship they're in and looking at the
   `source_id` field, or finding them by their source identifiers.
2. Open a rails console on the heroku app:
   `heroku run --app openownership-register bin/rails c`
3. Find the entity to split, e.g. `splitter = Entity.find('id-of-splitter')`
4. Find the master entity e.g. `master = Entity.find('id-of-master')`
5. Clear the `master_entity` on the entity you want to split:
   ```ruby
   splitter.master_entity = nil
   splitter.save!
   ```
6. Re-index the split entity with Elasticsearch:
  `IndexEntityService.new(splitter).index`
7. Due to a bug in Mongoid, we have to update the cached count manually:
   `master.reset_counters(:merged_entities)`

## Setting up a review app to mimic production (e.g. to review data imports)

Create a review app in the usual way through the Heroku admin and then after the
review app is up and running:

Go into the "Resources" section of the review app (on Heroku) and:
- Click on "Change Dyno Type" and set it to the "Professional" dyno type (as
  you'll need to use these bigger instances).
- Upgrade MemCachier to a higher plan (production uses a 1GB cache, but if you
  don't need to test cache effectiveness on this review app you can use a much
  smaller plan, e.g. 250MB).
- Remove the Heroku Redis instance
- Remove the mLab MongoDB instance (because upgrading to a clustered plan is not
  possible)
- Remove the SearchBox Elasticsearch instance
- Add Redis: `heroku addons:create openredis:micro --app openownership-register--pr-XXX`
- Set the `REDIS_PROVIDER` config var to `OPENREDIS_URL` so that the app can talk
  to redis
- Add MongoDB: `heroku addons:create mongolab:dedicated-cluster-m1 --db-version 3.4 --app openownership-register--pr-XXX`

Whilst these are getting set up, we need to copy across the production db to
have relevant data. This needs a fast and stable internet connection, so it's
best done from an EC2 instance in the same datacenter as the database
(EU-west-1):
- Spin up an EC2 t2.micro instance on Ubuntu 18.04, editing the disk space to
  give it 20GB (but leaving all of the other settings at their defaults)
- In the last step of the instance creation where it asks about access keys,
  create a new key pair for the instance and download the .pem file.
- `chmod 400 <path/to/new-key-file.pem>` the key file so that SSH will use it
- SSH into the new instance: `ssh -i <path/to/new-key-file.pem> ubuntu@<host-name-of-instance>`
- Install the right version of MongoDB and its tools following their docs e.g.
  https://docs.mongodb.com/v3.4/tutorial/install-mongodb-on-ubuntu/ (the 16.04
  docs seem to work equally well for 18.04)
- Dump the production db:
  `mongodump -h ds135134-a0.mlab.com:35134 -d heroku_kjwvs0sm -u readonly -o dump`
  (this will prompt you for a password, ask another dev to share the readonly
  user's password with you).

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

Back in the Heroku console for the review app
- Add the full url to your new elastic cluster into a new `ELASTIC_CLOUD_URL`
  setting – since it uses Basic Auth, the URL should end up like:
  `https://elastic:<password>@<host>`, where `<password>` is what you copied
  from the elastic cloud console.
- Update the `ELASTICSEARCH_URL_ENV_NAME` config variable to `ELASTIC_CLOUD_URL`

Now open the Mlab admin by clicking on the "mLab MongoDB …" addon, then:
- Wait for this to finish being set up.
- Once set up and ready, click to drill down into the deployment.
- Click on the "Networking" tab and then the "Allow all public internet traffic"
  and then "Apply security changes" – this may take a few minutes to complete.
- Assuming the data dump earlier is ready…
- Obtain the full URI for your instance:
  `heroku config:get MONGODB_URI --app openownership-register--pr-XXX`

On your EC2 instance:
- Use the username, password and host address from this to construct and run
  the data import command from your EC2 instance using the following structure:
  `mongorestore -h <host_address_incl_port> -d <username> -u <username> dump/heroku_kjwvs0sm`
  make sure to run this from the directory you ran the data dump in (it
  currently takes about 45 mins). Again this will prompt you for the password,
  which can be found in the heroku settings for the review app.
- Once this has run, you can terminate the EC2 instance.

Locally, once the restore has finished:
- Sanitize the database by running:
  `heroku run --app openownership-register--pr-XXX bin/rails sanitize`

In the Mlab admin
- Then go back to the MongoDB console and make a manual backup (this is useful
  if you need to restore to a clean state).
- Verify the database works as expected by opening up a Rails console using:
  `heroku run --app openownership-register--pr-XXX bin/rails c` and typing in:
  `Entity.count`. If a number is outputted then this means the app can talk to
  the db okay.
- Test that the site works as expected, by doing a few searches.
- Finally, run your import, see [Running data imports on production](#running-data-imports-on-production)
  for specific instructions on that.

## Restoring from an offsite backup

Note: If you're looking to restore from a normal backup, see [Setting up a review app to mimic production](#setting-up-a-review-app-to-mimic-production-eg-to-review-data-imports)

In the event that something happens to mLab and the backups they store within
their platform, we have several options to retrieve the production database.

Firstly, mLab should have been making nightly backups to an S3 bucket under the
OO AWS organisation account named 'oo-register-mlab-backups', and storing 8 days
worth of old backups in there. If you can trust these backups and the S3 bucket
is available, restoring from here will be the most efficient way to get the data
back.

If these backups are unavailable, or untrusted, the most recent 3 months of
backups from this bucket should have also been duplicated to Google Cloud
Storage under the OO-Register project. They're in a storage bucket with a
similar name 'oo-register-mlab-backups'.

### Verifying a backup locally
Once you've chosen a backup source, download the zip file of the backup you want
to restore and extract it locally. They can be accessed via the AWS Console or
the GCP Console in a web browser. Then, restore it using `mongorestore` to your
local mongodb (which must be running first):

```shell
$ mongorestore -h localhost:27017 ~/Downloads/rs-ds135134_2019-01-27T000458.000Z --drop --oplogReplay
```

This will restore the contents as faithfully as possible from the original
backup, creating an `admin` db and a `heroku_some-random-chars` database for you
locally, matching what mLab had in the production db. Note that it will drop
any existing collections if those databases already exist, allowing you to run
this multiple times. It takes a few minutes on a fast machine, so make a cup of
tea.

Finally, verify the database by switching the db name in `config/mongoid.yml` to
the `heroku_some-random-chars` one you just created and perform some checks in
the rails console:

- Count the entities and relationships
- Find some specific entities and check their networks
- If relevant, ensure whatever corruption is present in the current production
  db is not present in the backup

As a final test, you can run the dev server and browse the data, though note that
you'll have to re-index everything with elasticsearch for the search to work,
which takes several hours.

## Restoring a backup to production

The details of this are too situation-specific to list, but assuming that you've
identified a suitable backup to restore, and have a fresh, empty, MongoDB
instance into which to restore it (making sure it's running the same version of
MongoDB to avoid any compatibility issues), you can use `mongorestore` to
rebuild the production instance and then edit heroku's config variables to point
to the new instance. Exactly which databases you want to restore and how you
want that process to execute is up to you, but you probably only want to restore
the `heroku_` db, so `oplogReplay` won't be possible.

# Migrating to a new elasticsearch host

This was done in order to upgrade Elasticsearch from 5.6.9 (paid for through
Heroku) to 6.6.1 (on a separate Elastic cloud account), as our experience doing
the upgrade in-place found significant issues. However, it should apply to almost
any data migration where you can't use a simpler method (like just restoring
from a snapshot).

As a prerequisite, this assumes you spun up a new cluster somewhere and it's
running, but empty.

## Create an index in the new cluster

You need to copy across the settings that elasticsearch-model would normally
make for us. The easiest way to find them is asking elasticsearch itself. e.g.

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

## Reindex from the existing host

Using elasticsearch's `_reindex` api, you can request your new cluster loads
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

Note: This request will try to wait for the full reindex to happen, which may
take up to an hour or more, so it's likely to time out. The reindex task keeps
going though, and you can check on it with the `_tasks` api:

`GET <new-elasticsearch-host>/_tasks?actions=*reindex`

When the response is `nodes:{}` (i.e. an empty list of tasks) the reindex is
done

# Adding new data source pages

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
current code and views assume that you'll have a total count stat, and then some
other `types` you'll define in `DataSourceStatistic::Types` for whatever your
other stats are. At the moment, it's assumed that every stat is a count of
companies that meet some criteria, which can also be expressed as a percentage
of the total.

# Running the PscStatsCalculator

You can run the `PscStatsCalculator` at any point and it will create a new set
of `DataSourceStatistics` for the PSC register, as well as a total.

```shell
heroku run --app openownership-register bin/rails runner "PscStatsCalculator.new/call"
```
