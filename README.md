# java-docker-signal-demo

Demo of Java 10 which can react to Docker signals

## Docker Shell vs Exec

Docker is essentially a process encapsulation.

To run the process in the container, we can use `shell` or `exec` form.

* **Shell**: `ENTRYPOINT top -b` 
* **Exec**: `ENTRYPOINT["top", "-b"]`
    * You can also prefix your shell command with `exec` to run it as exec form
    * `ENTRYPOINT exec top -b`

### Shell

Shell form will spawn a child process, unmanaged by the PID1 process - except in Alpine linux it seems.

The following **Dockerfile** will yield two processes.

```dockerfile
FROM ubuntu
ENTRYPOINT top -b
```

```bash
top - 16:34:56 up 1 day,  5:15,  0 users,  load average: 0.00, 0.00, 0.00
Tasks:   2 total,   1 running,   1 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.4 us,  0.3 sy,  0.0 ni, 99.2 id,  0.1 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem :  2046932 total,   541984 free,   302668 used,  1202280 buff/cache
KiB Swap:  1048572 total,  1042292 free,     6280 used.  1579380 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
    1 root      20   0    4624    760    696 S   0.0  0.0   0:00.05 sh
    6 root      20   0   36480   2928   2580 R   0.0  0.1   0:00.01 top
```

### Shell with exec

```dockerfile
FROM ubuntu
ENTRYPOINT exec top -b
```

```bash
top - 18:12:30 up 1 day,  6:53,  0 users,  load average: 0.00, 0.00, 0.00
Tasks:   1 total,   1 running,   0 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.4 us,  0.3 sy,  0.0 ni, 99.2 id,  0.1 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem :  2046932 total,   535896 free,   307196 used,  1203840 buff/cache
KiB Swap:  1048572 total,  1042292 free,     6280 used.  1574880 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
    1 root      20   0   36480   2940   2584 R   0.0  0.1   0:00.03 top
```

### Exec

```dockerfile
FROM ubuntu
ENTRYPOINT["top", "-b"]
```

```bash
top - 18:10:48 up 1 day,  6:51,  0 users,  load average: 0.02, 0.01, 0.00
Tasks:   1 total,   1 running,   0 sleeping,   0 stopped,   0 zombie
%Cpu(s):  0.4 us,  0.3 sy,  0.0 ni, 99.2 id,  0.1 wa,  0.0 hi,  0.0 si,  0.0 st
KiB Mem :  2046932 total,   538700 free,   304536 used,  1203696 buff/cache
KiB Swap:  1048572 total,  1042292 free,     6280 used.  1577504 avail Mem

  PID USER      PR  NI    VIRT    RES    SHR S  %CPU %MEM     TIME+ COMMAND
    1 root      20   0   36480   3024   2676 R   6.7  0.1   0:00.05 top
```

### Alpine linux

[Alpine linux](https://alpinelinux.org/about/) is a lightweight linux distribution designed to be skeletal and is especially suited for use with Docker.

As one of its main uses is with Docker, it has some tricks up its sleeve.

If you run the `shell` format example:

```dockerfile
FROM alpine
ENTRYPOINT top -b
```

It will result in the following output.

```bash
Mem: 1509068K used, 537864K free, 640K shrd, 126756K buff, 1012436K cached
CPU:   0% usr   0% sys   0% nic 100% idle   0% io   0% irq   0% sirq
Load average: 0.00 0.00 0.00 2/404 5
  PID  PPID USER     STAT   VSZ %VSZ CPU %CPU COMMAND
    1     0 root     R     1516   0%   0   0% top -b
```

The top command also runs as PID 1, what about that....

## Process management

If you want a good process management for your docker container, there are some solutions.

In case you're wondering why you would want process management.
If your process can or will spawn child processes, they will go unmanaged.

A termination will only be send to PID 1, if your process is not PID 1 or cannot distribute the signal to the child processes, you risk leaving behind resources.

### Docker build-in

If you run containers via `docker run` commands, you can make use of the `--init` flag.
This flag makes sure your process runs with [tini](https://github.com/krallin/tini).

Let's see what happens if we run the `shell` example with --init.

```bash
echo "FROM alpine
      ENTRYPOINT top -b" > Dockerfile
docker image build --tag alpine-test .
docker run --rm --name alpine-test -ti --init alpine-test      
```

```bash
Mem: 1510260K used, 536672K free, 640K shrd, 126968K buff, 1013156K cached
CPU:   5% usr   5% sys   0% nic  89% idle   0% io   0% irq   0% sirq
Load average: 0.00 0.02 0.00 1/405 6
  PID  PPID USER     STAT   VSZ %VSZ CPU %CPU COMMAND
    6     1 root     R     1520   0%   1   0% top -b
    1     0 root     S     1044   0%   0   0% /dev/init -- /bin/sh -c top -b
```

No surprise there, we now have two processes. One of them is our tini process, which seemingly has executed our Entrypoint.

#### Docker Compose

```yaml
version: '2.2'
services:
    web:
        image: caladreas/java-docker-signal-demo:no-tini
        init: true
```

> Requires `docker-compose` and `docker` runtime **v1.13+**

#### Docker Swarm

```yaml
version: '3.7'
services:
    web:
        image: caladreas/java-docker-signal-demo:no-tini
        init: true
```

> Requires docker engine in `swarm mode` and `docker` runtime **v18.06+**

### Manual

Now, this is fine you run your containers with manual commands. But in practice you should generally use a orchestrator such as Swarm or Kubernetes.

This means you probably should bake the process manager into your image.

Unless it doesn't work for you or your app, I recommend to always use Alpine.

```dockerfile
FROM alpine
RUN apk add --no-cache tini
ENTRYPOINT ["/sbin/tini", "-vv","-g","-s", "--"]
CMD ["top -b"]
```

The output is as follows.

```bash
[INFO  tini (1)] Spawned child process 'top' with pid '7'
[DEBUG tini (7)] tcsetpgrp failed: no tty (ok to proceed)
Mem: 1527536K used, 519396K free, 640K shrd, 129452K buff, 1013668K cached
CPU:   5% usr  10% sys   0% nic  84% idle   0% io   0% irq   0% sirq
Load average: 0.03 0.08 0.03 1/409 7
  PID  PPID USER     STAT   VSZ %VSZ CPU %CPU COMMAND
    7     1 root     R     1520   0%   0   0% top -b
    1     0 root     S      756   0%   0   0% /sbin/tini -vv -g -s -- top -b
^C[DEBUG tini (1)] Passing signal: 'Interrupt'
[DEBUG tini (1)] Received SIGCHLD
[DEBUG tini (1)] Reaped child with pid: '7'
[INFO  tini (1)] Main child exited with signal (with signal 'Interrupt')
```
The `-vv` means **extra verbose**, which explains the log messages from tini.

This helps us see what tini does for us, it shows us which signal was send and that it made sure it's child process (our `top -b` command) also received the signal.

This allows us to control the signals send to our processes. This is turn allows us to do graceful shutdown.
