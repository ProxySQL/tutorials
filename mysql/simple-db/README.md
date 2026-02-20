# Demonstrate Single MySQL environment

## Tutorial Outcomes
1. Validate your Docker setup
2. Launch a single MySQL instance
3. Connect to and verify connectivity

## Pre-requisites
- [Docker](https://docs.docker.com/desktop/)
- [Docker Compose](https://docs.docker.com/compose/)

## Launch the Container

This tutorial will launch a single MySQL server to validate your environment prerequisites for future tutorials. For simplicity we remove customization features. See the [simple](../simple) tutorial for a fully customized version of this tutorial.

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
./run.sh
Launching docker container(s)
[+] Running 3/3
 ✔ Network simple-db_proxysql-demo  Created                                                                                                                   0.0s
 ✔ Volume simple-db_primary-data    Created                                                                                                                   0.0s
 ✔ Container primary                Started                                                                                                                   0.2s
Verifying docker processes
NAME      IMAGE       COMMAND                  SERVICE   CREATED         STATUS                            PORTS
primary   mysql:8.4   "docker-entrypoint.s…"   primary   6 seconds ago   Up 5 seconds (health: starting)   0.0.0.0:3306->3306/tcp, [::]:3306->3306/tcp, 33060/tcp
Validating Database access
mysql: [Warning] Using a password on the command line interface can be insecure.
VERSION()
8.4.8
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
