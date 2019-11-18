# docker-galaxy-uwsgi

This is a container that runs [Galaxy](https://galaxyproject.org/).
The server is started with 
[uWSGI](https://uwsgi-docs.readthedocs.io/en/latest/). 

The name `galaxy-uwsgi` is chosen to differentiate it from the famous
[galaxy-stable](https://github.com/bgruening/galaxy-stable) container
and the [`galaxy` container maintained by the galaxy team](
https://hub.docker.com/r/galaxy/galaxy). 

## Usage

### Quickstart

The container includes everything to get started. All the dependencies and 
optional dependencies for galaxy are installed so all config options should 
work out of the box. Also a fresh galaxy sqlite database is present so that 
does not need to be created on runtime.

To start a container for quick testing:

`docker run -p 8080:8080 -it -e GALAXY_CONFIG_ADMIN_USERS=my_email@example.org lumc/galaxy-uwsgi`

This will run a server process in your terminal which will die on keyboard 
interrupt.
The server will be accessible on `http://localhost:8080`. 
You can use the e-mail adress given in `GALAXY_CONFIG_ADMIN_USERS` to register 
with admin rights.

If you want to save the state of your galaxy instance (all files, histories, 
tools etc.) attach a docker volume to the container:

```bash 
docker volume create my_galaxy
docker run -it -p 8080:8080 -v my_galaxy:/galaxy_data -e GALAXY_CONFIG_ADMIN_USERS=my_email@example.org lumc/galaxy-uwsgi
```

Alternatively you can save Galaxy's state to your filesystem
```bash
docker run -it -p 8080:8080 -v $HOME/galaxy:/galaxy_data -e GALAXY_CONFIG_ADMIN_USERS=my_email@example.org lumc/galaxy-uwsgi
````

To start the container as a daemon and not have the output on the command line 
use the `-d` flag instead of the `-it` flags:
```bash
docker run -d -p 8080:8080 -v my_galaxy:/galaxy_data -e GALAXY_CONFIG_ADMIN_USERS=my_email@example.org lumc/galaxy-uwsgi
```

### Ports

galaxy-uwsgi runs an uwsgi process that serves http on port 8080 and uwsgi 
protocol on port 8000. This allows for flexible use of the container.
For use as a test instance (as shown in the quickstart) port 8080 works well.
For production setups usage of the uwsgi protocol on port 8000 is recommended.
This is explained below.

### Galaxy settings

Galaxy itself has a mechanism where all config settings can also be set in the 
environment by capitalizing them and prepending `GALAXY_CONFIG_`. For example 
the `admin_users` setting can be set in the environment with 
`GALAXY_CONFIG_ADMIN_USERS`. Settings in `/opt/galaxy/config/galaxy.yml` take 
priority over settings set in the environment.

For ad-hoc use the galaxy configuration can be set using environment variables 
as shown in the quickstart. For production it is recommended to mount a 
`galaxy.yml` file to `/opt/galaxy/config/galaxy.yml`.

For example:
```bash 
docker run docker run -d -p 8080:8080 -v my_galaxy_config.yml:/opt/galaxy/config/galaxy.yml -v my_galaxy:/galaxy_data lumc/galaxy-uwsgi
```

This container uses the defaults as much as possible, except for file paths. 
These where adjusted to make sure all the generated data end up in 
`/galaxy_data`.  All these settings where set using environment variables. 
`galaxy.yml` in this container is empty. Therefore it can be replaced easily
by mounting a new configuration at `/opt/galaxy/config/galaxy.yml` without
risk of breaking the container.

The settings that are not file related and not default are as follows:

environment variable | value | reason to deviate from default.
---|---|---
GALAXY_CONFIG_WATCH_TOOL_DATA_DIR | True | This container has watchdog available. Without this setting a reboot/reload is needed every time a data manager has run.
GALAXY_CONFIG_WATCH_TOOLS | True  | This container has watchdog available. Automatic reloading is much friendlier to admins.
GALAXY_CONFIG_CONDA_AUTO_INIT | False | Conda auto initialization should not happen as it is available in the container.
GALAXY_CONFIG_LOG_LEVEL | INFO | INFO is more suited for production use cases. The default DEBUG creates very long logs.

These are all the non-default settings. This amount was kept to a minimum to 
prevent unexpected behaviour.

### Database connections
Setting a new database connection can be done with environment variables as 
well:
```bash
docker run lumc/galaxy-uwsgi \
-e GALAXY_CONFIG_DATABASE_CONNECTION=postgresql:///db_user:db_pass@db_host/db_name
```

For more information check the [SQLAlchemy page on database URIs](
https://docs.sqlalchemy.org/en/13/core/engines.html#database-urls). 
Since postgres is the recommended production database and psycopg2
is the default for connecting with a postgres database with SQLAlchemy
[this page](https://docs.sqlalchemy.org/en/13/dialects/postgresql.html?highlight=environment#module-sqlalchemy.dialects.postgresql.psycopg2)
might also be useful.

NOTE: MySQL is not supported by this container. The python dependency is not 
installed in the environment. It will also not be supported by Galaxy anymore 
from 19.09 onwards.

### Other environment variables

Environment variable | default | usage
UWSGI_PROCESSES | 1 | Set the number of uwsgi processes. Do not increase this above 1 if you are using the SQLITE database.
UWSGI_THREADS | 4 | The number of threads uwsgi can use.

### Directories in the container

Directory | usage
---|---
/galaxy_data | All data that is generated during the running of an instance is stored here.
/galaxy_data/database | Contains the sqlite database, files, job_working directory and citations
/galaxy_data/shed_tools | Contains all the installed shed_tools
/galaxy_data/tool_data | Where indexes, reference sequences etc. are stored
/galaxy_data/tool_test_data | Test data for tool tests
/galaxy_data/mutable_config | Contains the config files that are updated on each tool install. Such as the tool panel information.
/galaxy_data/tool_dependencies | Contains the conda prefix (`_conda`) and all the environments necessary for running tool shed tools.
/galaxy_venv | Contains the galaxy virtual environment including all dependencies and optional dependencies
/opt/galaxy | Contains a checkout of the galaxy git repository
/opt/galaxy/config | Where the static config files reside. You can mount your own configs such as galaxy.yml or job_conf.xml in this directory.
/opt/galaxy/lib | The location of galaxy's library.

## Docker compose setup.

Galaxy version 19.05, postgres version 9.6 and nginx version 1.16 will be used 
as  example here. Feel free to use other versions. 

A working compose example can be found in [docs/compose_example](
docs/compose_example). 
Simply go to that directory and type `docker-compose up`. This will start 
galaxy in a production setup with a postgres database and a nginx proxy.

This setup is meant as a quickstart to experiment with the containers and see
how they interact in a production environment. In a real production environment
a docker swarm deployed with a docker stack is recommended.

## Production setup using docker swarm

Docker swarm has major advantages over docker compose:

+ The compose yaml defines services, not containers
    + These services are automatically restarted if they crash.
+ It allows usage of configs and secrets

Because docker swarm tries to keep services in a desired state ('up' in the
case of your galaxy services) it is very resilient against errors. If the
server is randomly restarted, a container crashes due to gamma radiation or
anything else, the docker swarm manager restarts the containers so your galaxy
remains up. This is very convenient as *no manual intervention is needed*.

Secrets are data that are encrypted and stored by docker. They can be mounted 
as files in containers. Most containers allow setting of a `PASSWORD_FILE` 
environment variable, so we do not need to keep the passwords in the 
environment. For example we can set `PGPASSFILE=/run/secrets/db-password` 
as an environment variable in our galaxy containers so galaxy can connect
with our postgres database. Secrets make it very easy to not store passwords as
plain text on your server.

TODO: Write a full working docker swarm setup including secrets.

### Setting up configs and secrets
WIP

## Why another galaxy container?

Galaxy administration is quite hard and there are plenty of people who do 
maintain Galaxies while it is not their main job. Docker swarm can  make 
deployments a lot easier but there is not a good swarm example out there. One 
of the reasons that this is not there is the lack of a proper container for 
docker swarm.

A proper container or docker swarm:
- should run only one process
- should be stateless

Unfortunately, while galaxy-stable does provide a special 'web' variant it also 
runs a nginx process, and thus fails the first requirement. The vanilla galaxy 
container cannot start galaxy without installing and  building first. It is not 
stateless.

galaxy-uwsgi does only one task. It runs galaxy through uwsgi, this is the only 
process that runs. Also all the dependencies and optional dependencies are 
preinstalled. This means every possible configuration of galaxy should be able 
to run without ImportErrors. It even includes a small ready to use sqlite 
database. You can point to other databases by using the 
`GALAXY_CONFIG_DATABASE_CONNECTION` variable.

Startup times for galaxy-uwsgi are very fast because of this. This makes it 
ideal for use in docker swarm setups or for test cases where a quick 
ready-to-use instance of galaxy is needed.

## Acknowledgements

Many thanks to [@bgruening](https://github.com/bgruening) as his container was 
used as an example a lot to get a lot of the installation tricks right.

Many thanks as well to the maintainers of [ansible-galaxy-extras](
https://github.com/galaxyproject/ansible-galaxy-extras) for the same reason.

Many thanks to the maintainers of the [Galaxy documentation](
https://docs.galaxyproject.org). It has a comprehensive list of requirements 
for a production instance, including nice examples which were used for the 
production setup examples here.

Many thanks to the authors of the [dive program](
https://github.com/wagoodman/dive) which was used to inspect the files which 
were added by each layer. Thanks to dive the order of the `RUN` commands in the
Dockerfile is more logical. Also it helped eliminate redundant files from the 
container as well as showing which files did *not* end up in `/galaxy_storage/` 
during runtime.

Many thanks to the authors of the [docker-xwiki project](
https://github.com/xwiki-contrib/docker-xwiki). It contains examples about
docker swarm and this was my first contact with it. I set up an xwiki instance
in our institute with the help of [this role](
https://github.com/lumc/ansible-role-xwiki-docker). This was the 
simplest ansible role I have ever written. The ease of deployment with 
docker swarm for xwiki is what led to this project. I want to enable the same
simplicity for galaxy.
