# Demonstrate Single PostgreSQL environment

## Tutorial Outcomes
1. Validate your Docker setup
2. Launch a single PostgreSQL instance
3. Connect to and verify connectivity

## Pre-requisites
- [Docker](https://docs.docker.com/desktop/)
- [Docker Compose](https://docs.docker.com/compose/)

## Launch the Container

This tutorial will launch a single PostgreSQL server to validate your environment prerequisites for future tutorials. For simplicity we remove customization features. See the [simple](../simple) tutorial for a fully customized version of this tutorial.

### For Mac OS and Linux
```
$ ./run.sh
```

### For Windows

Using Powershell:
```
run.ps1
```

NOTE: You may need to run `Set-ExecutionPolicy RemoteSigned` once to allow PowerShell scripts. Alternatively, you run it with `powershell -ExecutionPolicy Bypass -File run.ps1`.

Using Command Prompt:
```
run.bat
```

## Expected Output

```
$ ./run.sh
Launching docker container(s)
[+] Running 3/3
 ✔ Network tutorial1_default      Created                                                                                 0.0s
 ✔ Volume tutorial1_primary-data  Created                                                                                 0.0s
 ✔ Container primary              Started                                                                                 0.2s
Verifying docker processes
NAME      IMAGE         COMMAND                  SERVICE        CREATED        STATUS                                     PORTS
primary   postgres:18   "docker-entrypoint.s…"   postgresql18   1 second ago   Up Less than a second (health: starting)   0.0.0.0:5432->5432/tcp, [::]:5432->5432/tcp
Validating PostgreSQL access
                                                         version
--------------------------------------------------------------------------------------------------------------------------
 PostgreSQL 18.1 (Debian 18.1-1.pgdg13+2) on aarch64-unknown-linux-gnu, compiled by gcc (Debian 14.2.0-19) 14.2.0, 64-bit
(1 row)

To test using the container run
$ docker exec -it primary bash
To exit the containers run
$ docker compose down -v
```

## Teardown

The following will delete all containers resources.

```
docker compose down -v
```
