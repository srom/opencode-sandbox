# opencode-sandbox

This project packages opencode in a docker container to curtail the risk of AI going rogue on one's system.

At the moment it is made of one `Dockerfile` and a cli frontend implemented as a shell function.

## Installation

```sh
curl -fsSL https://raw.githubusercontent.com/srom/opencode-sandbox/refs/heads/main/install.sh | bash
```

## Usage

```sh
cd my-project
ocs
```

The current system has built-in persistance for opencode settings / state / auth credentials / auth credentials: everything is saved within the working directory in a folder named `.opencode-sandbox`. It is recommended to add this folder to `.gitignore`.
