
# 🛠️ DDS Permissions Manager — Full Installation Guide

**DDS Permissions Manager** is a backend system built using Java (Micronaut), PostgreSQL, and OAuth2 for securely managing permissions across distributed systems. This guide provides a complete step-by-step installation and setup process to run the project locally with full functionality, including:

* Java backend server
* Google OAuth2 login support
* PostgreSQL integration
* Sourced environment variable setup
* Initial admin creation for system access

Whether you're developing or deploying, follow the steps below to get up and running in minutes.


## ✅ STEP 0: Required Tools and Setup

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

## ✅ STEP 1: Get Google OAuth Credentials

1. Visit: [https://console.cloud.google.com/](https://console.cloud.google.com/)
2. Create a new project → APIs & Services → Credentials
3. **Create OAuth 2.0 Client ID** for Web application
4. Set **Authorised JavaScript origins** to:

   ```
   http://<your-ip>:8080
   ```
4. Set **redirect URI** to:

   ```
   http://<your-ip>:8080/api/oauth/callback/google
   ```
5. Download the `.json` file
6. Move it to the `install/` directory of your project and rename it:

   ```bash
   mv ~/Downloads/oauth-client.json ./install/google-oauth.json
   ```


## ✅ STEP 2: Setup Environment Variables and Run Backend Server
 
The shell script `setup.sh` automatically generate `.env` file and source all your environment variables and keys, edit it for any modification:

Then source it:
```bash
# Go to project $HOME dir
cd DDSPermissionsManager
# Go to project $HOME dir and make script executable
chmod +x install/setup.sh
# Run shell script
source install/setup.sh
```

For sourcing environment varaibles to other terminals, use the generated `.env` file to source:
```bash
# Export the env varailes
source install/.env.generated
```

Run Backend Server
```bash
# Go to project $HOME dir and run gradle
./gradlew app:run -t
```
The application will be live on: `http://localhost:8080`


## ✅ STEP 3: Add Initial Admin User from another terminal

The first user have to be added manually to the database, but dont worry we have shell script for tht too:
```bash
# Go to project $HOME dir and make script executable
chmod +x install/add_admin.sh
# Run shell script
./install/add_admin.sh
```
## ✅ STEP 4: Building and running a docker image

To run the application in docker, follow below steps:
```bash
# Go to project $HOME dir
cd DDSPermissionsManager

# Export the env varailes
source install/.env.generated

# Generate a dockerfile
./gradlew dockerfile

# Build the layers
./gradlew dockerfile

# Build the docker from generated docker image using docker image
docker compose build

# Run the docker
docker compose up
```

The application will be live on: `http://localhost:8080`

---