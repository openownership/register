# Open Ownership Register

This repository contains the code which powers
https://register.openownership.org, Open Ownership's demonstration of a
global beneficial ownership register. The website uses Ruby on Rails and
runs on Heroku.

This README mainly provides instructions for running and maintaining the
live website. If you want to reuse the code for other projects, please feel
free to contact us on: tech@openownership.org and we'd be happy to advise.

## Contents

- [Setting up local development](#setting-up-local-development)
- [Running tests](#running-tests)
- [Code overview](#code-overview)
- [A note on issue tracking](#a-note-on-issue-tracking)
- [A note on Git history](#a-note-on-git-history)

### Playbooks
These are a series of instructions for performing specific tasks, either in
normal (but not automated) production usage, or for one-off events.

- [Running data imports](#running-data-imports)
- [Running the entity integrity checker](#running-the-entity-integrity-checker)
- [Running the natural persons duplicates merger](#running-the-natural-persons-duplicates-merger)
- [Running the OpenCorporates updater](#running-the-opencorporates-updater)
- [Running the PSC stats calculator](#running-the-psc-stats-calculator)
- [Running a BODS export](#running-a-bods-export)
- [Un-merging people](#un-merging-people)
- [Setting up a review app to mimic production](#setting-up-a-review-app-to-mimic-production)
- [Migrating to a new ElasticSearch host](#migrating-to-a-new-elasticsearch-host)
- [Adding new data source pages](adding-new-data-source-pages)

## Setting up local development

Note: Most of our development has been done on Mac machines running OSX, so whilst we
expect things to work ok on Linux as well, the same may not be true for Windows.

- Install the version of ruby specified in `.ruby-version` using your favourite ruby version manager.
- Install yarn (see: https://yarnpkg.com/en/docs/install)
- Install python3 (ideally matching the version in runtime.txt) and it's
  supporting libraries for package installation, pip and virtualenv.

Create an `.env.local` and add in the various required env vars from `.env` – generally, you can use config values from the Heroku app `openownership-register-staging`.

For data stores and other local services, you can use Docker Compose:

```bash
docker-compose up -d
```

Alternatively, you can use your own local method for running these services. See the `docker-compose.yml` file for the required services and versions, and the `.env` file for expected config.

Run the setup command, which will check dependencies and set up the DB

```bash
bin/setup
```

Note: this final step relies on sample data which is held in a private S3
bucket, because it is real data. We will not normally share this data outside of
Open Ownership.

Import a subset of real data that's useful for local development and get it into
ElasticSearch.

```bash
rake postdeploy
```

Then you're ready to use the usual `rails` commands (like `rails serve`) to run / work with the app.

### Updates

`bin/update` will bring your dependencies up to date, though note it won't
remove python packages if you remove them from requirements.txt, because pip
doesn't work that way.

## Running tests

**Note**: Tests of our BODS export use the [lib-cove-bods](https://github.com/openownership/lib-cove-bods)
validator to validate BODS output. Tests of our Ukraine import use
[ua-edr-extractor](https://github.com/openownership/ua-edr-extractor).
These are both python packages which provide commandline tools. These tests will
be skipped if those tools can't be found in your $PATH, but it's better to run
everything if you can. The easiest way is to activate the virtualenv which
`bin/setup` created: `source venv/bin/activate` before you run the tests.

**Note**: ua-edr-extractor requires a set of trained models in order to be run.
These can be found in the production S3 bucket. There are two files, one for use
in tests and dev (ner-models/test-models.tar.gz) and one for production.
Download test-models.tar.gz file and then set UA_NER_MODELS to its location on
your system in `.env.test.local` so that the UaExtractor can find them.

To run all the tests and linters, as the CI service would, run:

```bash
bin/test
```

This deals with virtualenv for you.

Or, you can run individual language tests or linters directly:

Ruby tests: `bundle exec rspec`
Javascript tests: `yarn test`
Ruby lint: `bundle exec rubocop`
Haml lint: `bundle exec haml-lint .`
Javascript lint: `yarn lint`

## Code overview

The register is a fairly typical Ruby on Rails project, the main distinguishing features
are:

- We use MongoDB as our database, and heavily rely on a customised `upsert` method in our models for data addition/modification/de-duplication
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
- `User` - A (human) user of the site who can create submissions
- `Submission` - A collection of submitted data from a user
- `Submissions::Entity` - People or companies who have been submitted. These share core concerns with Entity through `ActsAsEntity`
- `Submissions::Relationship` - Relationships which have been submitted

#### Ruby models
These models don't get stored in the database, but are created on-the-fly to represent
particular things that help us reason about the data or display it more easily.

- `UnknownPersonsEntity` - When an ownership chain ends at an unknown, we represent the unknown person(s) with one of these
- `CircularOwnershipEntity` - When an ownership chain becomes a circle, we create one of these to terminate that cycle.
- `EntityGraph` - A graph or network of ownership, with nodes and edges representing entities and relationships. Used to back our graph visualisation and provide the graph traversal algorithm there.
- `InferredRelationship` - A relationship that can be inferred over one or more real relationships. In other words, a beneficial ownership chain.
- `InferredRelationshipGraph` - A graph or network of inferred relationships. This model holds a variety of graph traversal algorithms that allow us to compute things like the ultimate owner(s) of a company.
- `TreeNode` - A node in our simpler tree visualisation used for data submissions.

## A note on issue tracking

Until recently, we used a private Jira instance to host our issue tracking, so
you may see references to things like OO-123 or even OC-123 for very old code.
We recently moved to Github, though we manage our projects internally via Notion.
If you're interested in the history contained in old pieces of work, we have some
archives and can retrieve things as needed.

For all future issues, please use Github Issues.

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

## Running data imports

We run all of the standard 'chunked' imports (UK, UA, SK and DK currently) together
in order to save time and effort over the whole import and integrity checking
process.

### Initial assumptions / prerequisites:

- No other import is currently running or has been triggered to run.
- No worker dyno is currently running.

### Pre-import

1. Note down the current `Entity.count` and `Relationship.count` via the Rails console (`heroku run --app openownership-register bin/rails c`).
1. Open the Papertrail console (via the Heroku console) to monitor logs.
1. Open the [sidekiq admin panel](https://register.openownership.org/admin/sidekiq) to monitor the background jobs.
   - The login details for this can be found via the Config Vars for the production app, in the Heroku console.
1. Upgrade openredis to an instance type that has enough room to store all of
   the import jobs. This is probably a 'small' for most imports, but whenever
   we add a new source the initial import may require more (test on a review app
   first).

### Import

1. Trigger the imports:
   - `heroku run:detached --app openownership-register bin/rails psc:trigger`
   - `heroku run:detached --app openownership-register -s performance-l bin/rails sk:trigger`
   - `heroku run:detached --app openownership-register -s performance-l bin/rails dk:trigger`
1. Now turn on worker dynos to process the import jobs. You can scale these
   horizontally as required, but remember that each will create 10 connections
   to the database, and Atlas is quite limited in performance, so 4-5 is perhaps
   a sensible maximum.
1. Note down the time the workers were started.
1. Monitor the status of the import via the Sidekiq admin panel and papertrail.
   Note that although no jobs may show as active or enqueued, the triggers can
   still be running (if they're downloading data we've already seen, we don't
   have to enqueue anything). Use `heroku ps` to be sure everything's done.

Note: The full import from scratch takes roughly 30 hours, but the incremental
import each month should complete in 2-3 hours.

Note: We did run an import from Ukraine as well, but their format changed and
we didn't see the value in fixing it. It was run with:
`heroku run:detached --app openownership-register -s performance-l bin/rails ua:trigger`

Note: The UA, DK and SK import triggers need a lot of memory to run, because they're
iterating over all of the data, hence the performance-l dynos.

Note: The UA import does not use sidekiq to process jobs, it manages its own
parallelism internally, this means you cannot just rely on watching Sidekiq's
queue to know when it's finished, you need to check the dyno itself with 
`heroku ps --app openownership-register`.

Note: Currently all of our import jobs are set to not retry, so if they fail
they have genuinely failed. We can't currently retry them because of the way we
batch up the data, so we just accept that this process is a best-effort.

### Post-import

Once all jobs have been processed in the Sidekiq admin panel (/admin/sidekiq)
and all of the worker dynos have finished.

1. Shut down the worker dyno in the Heroku console so no workers are running.
1. Downgrade openredis to micro again.
1. From the logs, note down the timestamp when the last worker job finished and note down how long the whole import took.
1. Note down the new `Entity.count` and `Relationship.count` and note down the differences (can share these with the team on Slack if substantial).
1. Run the [`EntityIntegrityChecker`](#the-entityintegritychecker) – and then note down the final results from the logs.
1. Update [the tracking spreadsheet](https://docs.google.com/spreadsheets/d/1OWABqrHis4fznLZwTGu9TEpZjtRrD4Ko7T0kC7mFcCw/edit#gid=0) with the stats from the integrity checking

### Running a BODS import

The BODS importer has only been tested on example data and exports from the
register, so it's possible there are issues with whatever BODS data you may have
from 'the wild'.

Because it's generic, but we assume will be used on a source-by-source basis, it
has more options that need to be supplied in order for it to function correctly:

`heroku run:detached --app openownership-register bin/rails bods:trigger[<url>,<schemes>,<chunk_size>,<jsonl>]`

The arguments are as follows:

- `url`: A url to the data. This currently expects a single, uncompressed file
  in either json (i.e. all statements in one top-level array) or jsonl (i.e. all
  statements as individual lines) format. See `jsonl` for how to specify which.
  It uses Ruby's `open-uri`, so the url can also be a (absolute) local file path.
- `schemes`: an array of company number scheme ids that you expect to find in the
  data's identifiers. This allows the import to extract company numbers from the
  identifiers. Remember that Rake allows array params as space-separated lists
  only. E.g. GB-COH UA-EDR DK-CVR
- `chunk_size`: how many records to process in one chunk. Defaults to 100.
- `jsonl`: whether the data is in jsonl format (true/false). Defaults to false.

As with other importers, scale the Redis instance to something appropriate to
your dataset (note that this importer does not use RawDataRecords yet, so all
the data ends up in Redis in compressed form). Then finally start some workers
to process the jobs.

## Running the entity integrity checker

The `EntityIntegrityChecker` is used to detect various potential issues with entities in the database.

Currently, all issues detected + a final summary are outputted to the log.

It doesn't perform any fixes, but it can be used as the basis for a script / rake task that performs fixes as it emits issues, to be handled separately. See examples under `lib/tasks/migrations`.

Most of the checks are specific to _legal entities_, but some may also be for _natural persons_. Where a check is for both a `type` value will be outputted in the individual log lines.

To run the checker in production:

```bash
heroku run:detached -s performance-l --app openownership-register time bin/rails runner "EntityIntegrityChecker.new.check_all"
```

## Running the natural persons duplicates merger

The `NaturalPersonsDuplicatesMerger` is used to find and merge natural person entities that match on all of `name`, `address` and `dob` (all must be set and not empty).

To run the merge in production:

```bash
heroku run:detached -s performance-l --app openownership-register time bin/rails runner "NaturalPersonsDuplicatesMerger.new.run"
```

Check the log for results and stats.

## Running the OpenCorporates updater

The `OpenCorporatesUpdater` is used to update company data on a regular basis, by re-resolving each
company with OpenCorporates.

It's best to run this after an import, so that it only touches companies which
were left untouched by that import.

Note: this runs the actual resolutions as asynchronous jobs, so you need to
ensure you have a redis instance available with enough memory to store all of
the outdated legal entity ids (worst case around 250MB at the moment, with ~6
million companies in the db). The redis also needs to be able to handle a lot of
simultaneous connections (however many sidekiq is configured to make) so Heroku's
default Redis probably won't cut it.

Resolutions can be monitored via the sidekiq admin as with an import.

To run the updater in production:

```bash
heroku run:detached -s performance-l --app openownership-register bin/rails runner "OpenCorporatesUpdater.new.call"
```

## Running the PSC stats calculator

You can run the `PscStatsCalculator` at any point and it will create a new set
of draft `DataSourceStatistics` for the PSC register. The real world totals are
not calculated by this process (they can't be), so they should be updated
manually through a data migration. Once you're happy with the draft calculations
you have to publish them manually (through the rails console) to make them
appear on the site.

1. Upgrade the Redis instance to 'Large' to store all the calculation jobs
2. Trigger the jobs which create new draft statistics
   ```shell
   heroku run --app openownership-register bin/rails runner "PscStatsCalculator.new.call"
   ```
3. Start a new `performance-l` worker dyno to run the calculations
4. Monitor the jobs in sidekiq until they're all completed
5. When finished, you can check the draft numbers in the shell
   ```shell
   heroku run --app openownership-register bin/rails c
   psc_data_source = DataSource.find('uk-psc-register')
   psc_data_source.statistics.draft.pluck(:type, :value)
   ```
6. If these look right, you can publish those numbers by setting `published` to
   true on them all:
   `psc_data_source.statistics.draft.update_all(published: true)`

## Running a BODS export

Running a BODS export is a CPU intensive process and requires a persistent local
disk to store intermediate results on. Therefore, we run it on an EC2 machine
instead of Heroku (because Heroku's disks are reset every 24hrs). We still use
the database and redis instance attached to the production Heroku app though.

There are three main manual steps:

1. Setting up an AWS server to run the jobs
2. Exporting data to the local filesystem
3. Combining the many small exported files into one JSONLines format file,
   compressing it and uploading it to S3.

The setup process for this looks like:

### Setting up the server

- Increase Redis to an extra-large instance in Heroku
- Get an EC2 server in the eu-west-1 region.
  So far I've used a c5.xlarge (4 CPUs, 8GB ram) with 250GB disk space. There's
  a template in our org AWS account for this purpose and the SSH key to log in
  is in our 1Password account.
- SSH into the machine: `ssh -i wherever/you/have/the.pem ubuntu@the-machines-ip`
- Clone the register: `git clone https://github.com/openownership/register.git`
- Set up the checkout of the repo to be able to connect to the production
  services.
  - `cd register`
  - `bin/setup-bods-export`
  - Activate rbenv: `source ~/.bash_profile`
  - Edit `config/mongoid.yml` and change the development database to a `uri`
    setting like production, copying in the production connection string from
    Heroku. This means swapping the `database` and `hosts` keys for a single `uri`
    key.
  - Edit the empty `.env.local` to add the following environment variable overrides,
    using values from the production Heroku. Note that `REDIS_URL` is called 
    `OPENREDIS_URL` in Heroku.
    ```
    REDIS_URL=
    REDIS_PROVIDER=REDIS_URL
    MEMCACHIER_PASSWORD=
    MEMCACHIER_SERVERS=
    MEMCACHIER_USERNAME=
    BODS_EXPORT_AWS_ACCESS_KEY_ID=
    BODS_EXPORT_AWS_SECRET_ACCESS_KEY=
    BODS_EXPORT_S3_BUCKET_NAME=
    SITE_BASE_URL=https://register.openownership.org
    ```
- Test in rails console you can see db and connect to redis
  `bundle exec rails c`
  
  ```ruby
  Entity.count # Should return a number in the millions
  redis = Redis.new
  redis.keys('*') # Should return an array of strings with sidekiq queue names in
  redis.close
  ```

### Running the export

- Before you start, make sure you've turned off any worker dynos in Heroku

On the EC2 machine:
- Start a screen session: `screen -S bods-export`
- Start sidekiq processes equal to the number of cpus in your EC2 machine:
  `bundle exec sidekiq`, `ctrl+a c`, repeat
- Decide whether you're running an incremental export or a whole one and run
  the necessary steps below
- In a new screen window (ctrl+a c), start a rails console `bundle exec rails c`
- In the rails console, create and start the exporter: `BodsExporter.new.call`
- Detach screen with `ctrl+a ctrl+d`, reattach with `screen -r`

#### Incremental export

For incremental exports, you need to have primed Redis with the existing
statement ids from S3.

- Download the file from S3
- Read each line into an array
- Initialise the exporter with `existing_ids: your_array` and `incremental: true`

#### Monitoring exports

- Open /admin/sidekiq to monitor the jobs (on the live site) and Redis memory
  usage
- Optional: open Atlas' metrics page to monitor CPU usage and Disk IOPS
- Optional: check the temporary statements directory to make sure files are being
  created and they look right.
- Optional: Use AWS' instance monitoring to check on CPU and Memory utilisation
- Optional: Use AWS' volume monitoring to check on Disk utilisation
- Check on disk usage and inode usage: `df -h`, `df -i`

### Combining and Uploading the results

- Re-attach to the screen session (assuming you left it running)
- Stop the sidekiq instances and close each screen window:
  `ctrl+a 1`, `ctrl+c`, `ctrl+d`, repeat for each numbered screen window.
- In the existing rails console, or a new one. Clean up the Redis set used
  to de-dupe the exported statements. It's not needed (we only need a 
  list for ordering the combined file now) and takes up precious memory in Redis. 
  `redis.del('bods-export-redis-statements-set')`.
- Find the export id from the export you just finished (it should be the same as
  the latest/only folder name in RAILS_ROOT/tmp/exports).
- Run a BodsExportUpoloader:
  `BodsExportUploader.new(export_id).call`
- This will take hours, so disconnect your screen session again

**Note**: If you're starting a new rails shell to run this command, remember
a) to do it in a Screen session (it takes hours so you'll want to disconnect)
and b) to run that rails session **without** spring:

```shell
DISABLE_SPRING=1 bundle exec rails c
```

Otherwise, spring tries to scan every single statement file that's been written
to the rails tmp folder, locking up the whole machine and eating up all of the
volume's boost credits. If you forget, you have to kill the spring process
before anything can start, because it keeps running in the background (hint: it
doesn't appear in ps for your user either).

#### Incremental update

- Assuming you ran the export with a primed list of existing statement ids!
- Run `BodsExportUploader.new(export_id, incremental: true).call`

#### Monitoring data combining/uploading

- Check on the export's output folder and monitor the filesize of the files
  therein.

### Troubleshooting

- Sudden slowdown? Have we tripped over one of the burst credit limits, either
  on EC2, EBS or Atlas' DB?

## Un-merging people

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
