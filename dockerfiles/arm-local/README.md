# Setup for Positron ARM64 Local Development

Create the following files in the `dockerfiles/arm-local` directory:

![Required Secrets Files](doc-images/secrets.png)

In the .env file, set the following variables:

```bash
E2E_POSTGRES_USER=
E2E_POSTGRES_PASSWORD=
E2E_POSTGRES_DB=
```
(the values to use are in 1Password under POsitron > E2E Postgres DB Connection info)

In the license.txt file, add your the Positron Workbench License from the 1Password IDE/Workbench vault.

# Execution

You will need two terminal windows open to dockerfiles/arm-local for this process.  

In the first terminal, run:

```bash
./run-with-license.sh
```

This will start the containers and keep them alive.

In the second terminal, run:

```bash
./connect.sh
```

Then inside the container, run:

```bash
/tmp/setup-test-env.sh <branch_name>
cd /__w/positron/positron
source ~/.bashrc
```

At this point you will be ready to run tests. Here are a couple sample command lines:

```bash
npx playwright test --project e2e-electron --workers 2 --grep @:connections --repeat-each 1 --max-failures 10
npx playwright test --project e2e-browser --workers 2 --grep @:data-explorer --repeat-each 1 --max-failures 10
```

When you are done, you can run:

```bash
exit
```

In the second terminal.  Then go back to the first and use CTRL-C.  Optionally, you can run:

```bash
 ./stop-containers.sh
 ```
 (if you don't want to leave the containers running).