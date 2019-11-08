# docker-galaxy-uwsgi

This is a container that runs [Galaxy](https://galaxyproject.org/).
The server is started with 
[uWSGI](https://uwsgi-docs.readthedocs.io/en/latest/). 

The name `galaxy-uwsgi` is chosen to differentiate it from the famous
[galaxy-stable](https://github.com/bgruening/galaxy-stable) container
and the [`galaxy` container maintained by the galaxy team](
https://hub.docker.com/r/galaxy/galaxy). 

## Usage
WIP

## Why another galaxy container?

Galaxy administration is quite hard and there are plenty of people who
do maintain Galaxies while it is not their main job. Docker swarm can 
make deployments a lot easier but there is not a good swarm example out 
there. One of the reasons that this is not there is the lack of a proper
container for swarm.

A proper container:
- should do only one task (one process)
- should be stateless

Unfortunately, while galaxy-stable does provide a special 'web' variant
it also includes NgiNX, and thus fails the first requirement. The
vanilla galaxy container cannot start galaxy without installing and 
building first. It is not stateless.

galaxy-uwsgi does only one task. It runs galaxy through uwsgi, this 
is the only process thar runs. Also all the dependencies are 
preinstalled. It even includes a small ready to use sqlite database.
(You can point to other databases by using environment variables.)

Startup times for galaxy-uwsgi are very fast because of this. This 
makes it ideal for use in docker swarm setups or for test cases where
a quick ready to use instance of galaxy is needed.

## Acknowledgements

Many thanks to [@bgruening](https://github.com/bgruening) as his
container was used as an example a lot to get a lot of the installation 
tricks right.

Many thanks as well to the maintainers of [ansible-galaxy-extras](
https://github.com/galaxyproject/ansible-galaxy-extras) for the same 
reason.

And last but not least many thanks to the maintainers of the [Galaxy
documentation](https://docs.galaxyproject.org). It is extraordinaly
good documentation.


