# docker-pod

Docker CLI plugin for managing pods

This plugin add the manual management of pods to Docker. You can create a pods, add containers to a pod, remove containers from a pod as well as manage the containers (logs, exec).

## Installation

1. Please make sure you are running Docker 19.03.

1. Copy `docker-pod.sh` to `~/.docker/cli-plugins`:

    ```bash
    bash docker-pod.sh install
    ```

1. Call `docker` and make sure it lists the CLI plugin `pod`:

    ```bash
    $ docker
    # REDACTED
    Management Commands:
    builder     Manage builds
    config      Manage Docker configs
    container   Manage containers
    context     Manage contexts
    engine      Manage the docker engine
    image       Manage images
    network     Manage networks
    node        Manage Swarm nodes
    plugin      Manage plugins
    pod*        Manage pods (Nicholas Dille, 0.7.0)
    secret      Manage Docker secrets
    # REDACTED
    ```

## Internals

This plugin manages pod by creating a dummy container representing the pod.

Additional containers are started next to the dummy container and shares the network as well as the PID namespace.

## Usage

The following section demonstrate working with a pod. This build on each other.

### Create a pod

The following command creates a new pod called `foo`:

```bash
$ docker pod create foo
1e31f69e597d39cc45909cd1b0a19f8184298ff6d8b547790a562a39a20b6294
```

The command has started a container called `pod_foo_sleeper` to represent the pod `foo`:

```bash
$ docker container ps --filter name=pod_
CONTAINER ID        NAMES               IMAGE               STATUS
1e31f69e597d        pod_foo_sleeper     ubuntu              Up 21 seconds
$ docker container exec pod_foo_sleeper ps x
  PID TTY      STAT   TIME COMMAND
    1 ?        Ss     0:00 sleep infinity
   31 ?        Rs     0:00 ps x
```

### Add containers to the pod

The following command adds a container called `registry` to the pod `foo` running on the image `registry:2`:

```bash
$ docker pod add foo registry registry:2
1d80af468de5660f898d8f75087fc4eda9bdffb3c33f131c867fb8a6c64cd1ff
```

The command has created a container called `pod_foo_registry` sharing namespaces with the initial container:

```bash
$ docker container ps --filter name=pod_
CONTAINER ID        NAMES               IMAGE               STATUS
1d80af468de5        pod_foo_registry    registry:2          Up 3 minutes
1e31f69e597d        pod_foo_sleeper     ubuntu              Up 9 minutes
```

The `add` command accepts the Docker options before the image name as well as command line arguments for the command. Consider the following example:

```bash
$ docker pod add foo dind --privileged docker:stable-dind dockerd --host tcp://127.0.0.1:2375
c7948a83120010330e7d789103b67fd7f6c0bad23e29be8d78102d00e78b1252
```

### List pods

The following command lists all containers belonging to the pod `foo`:

```bash
$ docker pod list foo
CONTAINER ID        NAMES               IMAGE                STATUS
c7948a831200        pod_foo_dind        docker:stable-dind   Up 53 seconds
1d80af468de5        pod_foo_registry    registry:2           Up 17 minutes
1e31f69e597d        pod_foo_sleeper     ubuntu               Up 24 minutes
```

### Show logs

The following command shows the logs of the container `registry` in the pod `foo`:

```bash
$ docker pod logs foo registry
time="2020-09-04T10:30:11.4878484Z" level=warning msg="No HTTP secret provided - generated random secret. This may cause problems with uploads if multiple registries are behind a load-balancer. To provide a shared secret, fill in http.secret in the configuration file or set the REGISTRY_HTTP_SECRET environment variable." go.version=go1.11.2 instance.id=7fbd9225-90c1-4f0a-ae09-c836984b9ada service=registry version=v2.7.1
time="2020-09-04T10:30:11.4880837Z" level=info msg="redis not configured" go.version=go1.11.2 instance.id=7fbd9225-90c1-4f0a-ae09-c836984b9ada service=registry version=v2.7.1
time="2020-09-04T10:30:11.4880289Z" level=info msg="Starting upload purge in 34m0s" go.version=go1.11.2 instance.id=7fbd9225-90c1-4f0a-ae09-c836984b9ada service=registry version=v2.7.1
time="2020-09-04T10:30:11.4994109Z" level=info msg="using inmemory blob descriptor cache" go.version=go1.11.2 instance.id=7fbd9225-90c1-4f0a-ae09-c836984b9ada service=registry version=v2.7.1
time="2020-09-04T10:30:11.5002438Z" level=info msg="listening on [::]:5000" go.version=go1.11.2 instance.id=7fbd9225-90c1-4f0a-ae09-c836984b9ada service=registry version=v2.7.1
```

The `logs` command accepts all Docker options.

### Use the pod interactively

The following command creates an interactive container in the pod `foo`:

```bash
$ docker pod run foo cmd.cat/bash/curl/jq bash
bash-5.0# ps faux
PID   USER     TIME  COMMAND
    1 root      0:00 sleep infinity
   36 root      0:00 registry serve /etc/docker/registry/config.yml
   67 root      0:00 bash
   72 root      0:00 ps faux
bash-5.0# curl -s localhost:5000/v2/ | jq
{}
```

The `run` command accepts the Docker options before the image name as well as command line arguments for the command. Consider the following example:

```bash
$ docker pod run foo --read-only alpine mount | grep " on / "
overlay on / type overlay (ro,relatime,lowerdir=/var/lib/docker/overlay2/l/RZVZH4MJEZPNPIKUHFBGHQXVRP:/var/lib/docker/overlay2/l/UC7XX6HQHKLGVSSKB5XEMZMF42,upperdir=/var/lib/docker/overlay2/08bc16d617f673774ce15ee1de6dcc87febb5c39249b45a46a2e407a03172e82/diff,workdir=/var/lib/docker/overlay2/08bc16d617f673774ce15ee1de6dcc87febb5c39249b45a46a2e407a03172e82/work)
```

### Enter a container in the pod

The following command enters the container `registry` in the pod `foo`:

```bash
$ docker pod exec foo registry sh
/ # ps faux
PID   USER     TIME  COMMAND
    1 root      0:00 sleep infinity
   36 root      0:00 registry serve /etc/docker/registry/config.yml
   84 root      0:00 dockerd --host tcp://127.0.0.1:2375
  104 root      0:00 containerd --config /var/run/docker/containerd/containerd.toml --log-level info
  224 root      0:00 sh
  230 root      0:00 ps faux
```

The above command also accepts arguments for the process:

```bash
$ docker pod exec foo registry ps x
PID   USER     TIME  COMMAND
    1 root      0:00 sleep infinity
    6 root      0:00 registry serve /etc/docker/registry/config.yml
   22 root      0:00 dockerd --host tcp://127.0.0.1:2375
   43 root      0:00 containerd --config /var/run/docker/containerd/containerd.
  170 root      0:00 ps x
```

### Remove a container from the pod

The following command removes the container called `dind` from the pod `foo`:

```bash
$ docker pod remove foo dind
pod_foo_dind
```

The command has removed the container `pod_foo_dind`:

```bash
$ docker pod list foo
CONTAINER ID        NAMES               IMAGE               STATUS
1d80af468de5        pod_foo_registry    registry:2          Up 20 minutes
1e31f69e597d        pod_foo_sleeper     ubuntu              Up 27 minutes
```

### Delete a pod

The following command removed the pod `foo`:

```bash
$ docker pod delete foo
1d80af468de5
1e31f69e597d
```

After the command has run, the pod is removed and accessing it produces and error message:

```bash
$ docker pod list foo
ERROR: Pod foo does not exist.
```
