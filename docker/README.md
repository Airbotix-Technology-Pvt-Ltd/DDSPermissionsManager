
# 🛠️ DDS Permissions Manager — Docker Setup Guide

**DDS Permissions Manager** is a backend system built using Java (Micronaut), PostgreSQL, and OAuth2 for securely managing permissions across distributed systems. This guide provides a complete step-by-step installation and setup process to run the project locally with full functionality, including:

* Java backend server
* Keycloak OAuth2 login support
* PostgreSQL integration
* Sourced environment variable setup
* Initial admin creation for system access

Whether you're developing or deploying, follow the steps below to get up and running in minutes.


## STEP 0: Required Tools and Setup

* Install **Java JDK 11 or higher**
* Install **Node.js (version 18 or higher)** along with **npm**, then downgrade npm to version 3.1.0
* Install **PostgreSQL** database server
* Configure PostgreSQL authentication method for the `postgres` user from `peer` to `trust` in the `pg_hba.conf` file
* Restart PostgreSQL service after updating authentication
* Set a password for the `postgres` user

Don't worry you don't have to do it all manually, just run the `install.sh` shell script, it will do everything for you:
```bash
# First Clone the project
git clone <your-dds-permissions-manager-repo>
# Go to project $HOME dir
cd DDSPermissionsManager
# Make script executable
chmod +x install/install.sh
# Run shell script
./install/install.sh
```

For uninstallation:
```bash
# Go to project $HOME dir
cd DDSPermissionsManager
# Make script executable
chmod +x install/uninstall.sh
# Run shell script
./install/uninstall.sh
```


## STEP 1: Setup Environment Variables and Run Backend Server
 
The shell script `setup.sh` automatically generate `.env` file and source all your environment variables and keys, edit it for any modification:

Then source it:
```bash
# Go to project $HOME dir
cd DDSPermissionsManager
# Go to project $HOME dir and make script executable
chmod +x docker/setup.sh
# Run shell script
source docker/setup.sh
```

For sourcing environment varaibles to other terminals, use the generated `.env` file to source:
```bash
# Export the env varailes
source docker/.env
```

## STEP 2: Build and run docker
```bash
# Generate a dockerfile
./gradlew dockerfile

# Build the layers
./gradlew buildLayers

# Build the docker
docker compose build

# Run the docker
docker compose up
```

### Access URLs

- Backend API	http://localhost:8080
- Keycloak UI	http://localhost:8180

### Keycloak Login

Default credentials:
- username: admin
- password: change_me

Once logged in:

- Create a new Keycloak admin user.
- Create a new Realm called dds-realm.
- Add a new Client under this realm.
- Download the client credentials JSON and rename it as auth_client.json. This file is referenced by the setup.sh script for auth configuration.

Reference: [Micronaut OAuth2 + Keycloak Setup](https://guides.micronaut.io/latest/micronaut-oauth2-keycloak-gradle-java.html)


## STEP 3: Add Initial Admin User from another terminal

The first user have to be added manually to the database, but dont worry we have shell script for tht too:
```bash
# Go to project $HOME dir and make script executable
chmod +x docker/add_admin.sh
# Run shell script
./install/add_admin.sh
```
---