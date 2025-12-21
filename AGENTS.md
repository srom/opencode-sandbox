# opencode-sandbox

This project aims to package software opencode (https://opencode.ai/) in a docker container to curtail the risk of AI agents going rogue on one's system.

The idea is to build a Docker container plus a thin layer on top of opencode's TUI to orchestrate the container's lifecycle. The current implementation includes a Dockerfile and a shell function added to .zshrc. 

Crucially, we ensure that the local docker user has the same user_id and group_id by building the container as follows:

```sh
docker build \
  --build-arg USER_ID=$(id -u) \
  --build-arg GROUP_ID=$(id -g) \
  -t opencode-sandbox .
```

The current system has built-in persistance for opencode settings / state / auth credentials / auth credentials: everything is saved within the working directory in a folder named `.opencode-sandbox`. IGNORE THIS FOLDER IN THE PRESENT CODEBASE!
