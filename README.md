# opencode-sandbox

This project packages opencode in a docker container to curtail the risk of AI going rogue on one's system.

At the moment it is made of one `Dockerfile` and a frontend implemented as a shell function appended to .zshrc.

Usage:

```sh
cd my-project
opencode-sandbox
```

The current system has built-in persistance for opencode settings / state / auth credentials / auth credentials: everything is saved within the working directory in a folder named `.opencode-sandbox`. It is recommended to add this folder to `.gitignore`.
