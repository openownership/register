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

For all chunked imports (UK and DK currently), make sure you follow these
generic steps and then any additional source-specific steps from the sections
below.

### Initial assumptions / prerequisites:

- Track each import in a separate ticket on JIRA (may need scheduling into a
  sprint, etc.) – this is where stats, timestamps, special instructions, etc.
  can be noted down.
- No other import is currently running or has been triggered to run.
- No worker dyno is currently running.
- All Heroku stuff below can be carried out in the Heroku console for the
  [production app](https://dashboard.heroku.com/apps/openownership-register)
- To access a Rails console to the production app you can run:
  - `heroku run --app openownership-register bin/rails c`

### Pre-import

1. Make a backup of the MongoDB database via the mLabs console (from the Heroku console).
1. Note down the current `Entity.count` and `Relationship.count` via the Rails console.
1. Open the Papertrail console (via the Heroku console) to monitor logs.
1. Open the [sidekiq admin panel](https://register.openownership.org/admin/sidekiq) to monitor the background jobs.
   - The login details for this can be found via the Config Vars for the production app, in the Heroku console.

### Import

See the source-specific documentation.

### Post-import

Once all jobs have been processed in the Sidekiq admin panel (/admin/sidekiq)

1. Shut down the worker dyno in the Heroku console so no workers are running.
1. Downgrade any add-ons you temporarily bumped up.
1. From the logs, note down the timestamp when the last worker job finished and note down how long the whole import took.
1. Note down the new `Entity.count` and `Relationship.count` and note down the differences (can share these with the team on Slack if substantial).
1. Run the [`EntityIntegrityChecker`](#the-entityintegritychecker) – and then note down the final results from the logs.

### PSC (UK Companies House "Persons of Significant Control")

Below are the sets of steps required to run a full PSC import on production.

#### Pre-import

1. Upgrade the `openredis` instance to the `Large` plan in the Heroku console (give this a few mins to get set up and for dyno(s) to restart).

#### Import

1. Trigger the import:
   - `heroku run:detached --app openownership-register bin/rails psc:trigger`
1. Now turn on **1** worker dyno, making sure it's a `performance-l`.
1. Note down the time the worker was started.
1. Monitor the status of the import via the Sidekiq admin panel + Papertrail logs.
   - Look for failed jobs, or errors in the log, etc.
   - The full import takes roughly 20 hours, so don't need to constantly monitor things!

#### Post-import

1. Downgrade openredis back to the micro plan.

### DK CVR (Danish company register)

#### Pre-import

No additional pre-import steps are needed.

#### Import

1. Trigger the import:
   `heroku run:detached -s standard-2x --app openownership-register bin/rails dk:trigger`
   (Note: this import needs a 2x worker dyno to run effectively).
1. Now turn on **1** worker dyno, making sure it's a `performance-l`.
1. Note down the time the worker was started.
1. Monitor the status of the import via the Sidekiq admin panel + Papertrail logs.
   - Look for failed jobs, or errors in the log, etc.
   - The full import takes roughly 20 hours, so don't need to constantly monitor things!

## The `EntityIntegrityChecker`

… is used to detect various potential issues with entities in the database.

Currently, all issues detected + a final summary are outputted to the log.

It doesn't perform any fixes, but it can be used as the basis for a script / rake task that performs fixes as it emits issues, to be handled separately. See examples under `lib/tasks/migrations`.

Most of the checks are specific to _legal entities_, but some may also be for _natural persons_. Where a check is for both a `type` value will be outputted in the individual log lines.

To run the checker in production:

```bash
heroku run:detached -s performance-m --app openownership-register time bin/rails runner "EntityIntegrityChecker.new.check_all"
```

## The `NaturalPersonsDuplicatesMerger`

… is used to find and merge natural person entities that match on all of `name`, `address` and `dob` (all must be set and not empty).

To run the checker in production:

```bash
heroku run:detached -s performance-l --app openownership-register time bin/rails runner "NaturalPersonsDuplicatesMerger.new.run"
```

Check the log for results and stats.

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
- Add ElasticSearch: `heroku addons:create foundelasticsearch:beagle-standard --elasticsearch-version 5.6.9 --app openownership-register--pr-XXX`

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

Back in the Heroku console for the review app, click on the "Elasticsearch" addon to open it's console, then:
- Reset the password by going to the "Shield" tab and clicking on "Reset" – the
  new username and password will show on screen.
- Now add this username and password in the `FOUNDELASTICSEARCH_URL` config
  variable in the review app's config (via the Heroku console) – since it uses
  Basic Auth, the URL should end up like: `https://<username>:<password>@<host>`.
- Now update the `ELASTICSEARCH_URL_ENV_NAME` config variable to be
  `FOUNDELASTICSEARCH_URL`

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

- Index the entities into search by running:
 `heroku run:detached -s standard-2x --app openownership-register--pr-XXX time bin/rails runner "Entity.import(force: true)"`.
 This can take a few hours (roughly 9 hours currently).
- Test that the site works as expected, by doing a few searches.
- Finally, run your import, see [Running data imports on production](#running-data-imports-on-production)
  for specific instructions on that.
