# Axis Solutions — Custom Traccar

Custom-branded Traccar GPS tracking with a React frontend and PostgreSQL database.

The frontend is not deployed as a separate website. The compiled files in `web/`
are copied into the Traccar image and served together with the API and WebSocket
endpoint on port 8082.

## Production architecture

- `traccar`: custom Traccar 6.14.5 image containing `traccar.xml` and `web/`
- `postgres`: PostgreSQL 16 with a persistent named volume
- Coolify proxy: HTTPS traffic to the internal Traccar port 8082
- Direct device ports: 5023, 5027 and 5055
- Persistent volumes: database, Traccar data and uploaded media

## Deploy with Coolify

### 1. Push the project to Git

Commit and push these files to the repository Coolify will use. Do not commit
the local `.env` file.

The production deployment file is:

```text
docker-compose.coolify.yml
```

### 2. Configure DNS

Create an `A` record pointing the application hostname to the public IP address
of the server running Coolify:

```text
gps.devaxis.co.zm  ->  YOUR_COOLIFY_SERVER_IP
```

Wait for DNS to resolve before expecting Coolify to issue the TLS certificate.

### 3. Open the required server ports

Allow the following in both the VPS/provider firewall and the operating system
firewall:

| Port | Protocol | Purpose |
| --- | --- | --- |
| 22 | TCP | SSH |
| 80 | TCP | HTTP and certificate validation |
| 443 | TCP | HTTPS web application |
| 5023 | TCP and UDP | GT06 / Jimi IoT devices |
| 5027 | TCP and UDP | Teltonika devices |
| 5055 | TCP | OsmAnd protocol and simulator |

Example using UFW:

```bash
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 5023/tcp
sudo ufw allow 5023/udp
sudo ufw allow 5027/tcp
sudo ufw allow 5027/udp
sudo ufw allow 5055/tcp
sudo ufw enable
```

Do not expose PostgreSQL port 5432. It is only used on the private Compose
network.

### 4. Create the Coolify resource

1. In Coolify, open the target project and environment.
2. Select **New Resource**, then select the Git repository.
3. Choose **Docker Compose** as the build pack.
4. Set **Docker Compose Location** to `/docker-compose.coolify.yml`.
5. Keep **Base Directory** as `/`.
6. Save so Coolify parses the `postgres` and `traccar` services.

### 5. Add environment variables

In the Coolify resource, open **Environment Variables** and add:

```env
TRACCAR_DB_NAME=traccar
TRACCAR_DB_USER=traccar
TRACCAR_DB_PASS=GENERATE_A_LONG_RANDOM_PASSWORD
TRACCAR_PUBLIC_URL=https://gps.devaxis.co.zm
```

Use a new random database password. The same value is automatically supplied to
PostgreSQL and Traccar; do not add it to `traccar.xml`.

### 6. Configure the domain

Open the `traccar` component in Coolify and set its domain to:

```text
https://gps.devaxis.co.zm:8082
```

The `:8082` identifies the internal container port. Users still browse to
`https://gps.devaxis.co.zm` without a port number.

Do not add a domain to the `postgres` component and do not publish port 8082 on
the host. Coolify proxies web traffic to it internally.

### 7. Deploy

Select **Deploy** and check the deployment output. PostgreSQL should become
healthy first, followed by Traccar. Traccar creates and migrates its database
schema automatically.

Open:

```text
https://gps.devaxis.co.zm
```

On a new database there is no `admin/admin` login. Register the first account;
the first registered user becomes the administrator. Do this immediately after
the first deployment, then disable public registration in the Traccar server
settings if it is not needed.

### 8. Configure backups

The `postgres_data` volume survives redeployments, but it is not a backup.

1. Open the PostgreSQL component in Coolify.
2. Open **Backups** and add a daily schedule.
3. Store a copy in S3-compatible off-server storage.
4. Test restoring a backup into a non-production database.

## Verify device connectivity

Register a device in the web interface using its IMEI or unique identifier, then
configure the physical tracker to use the Coolify server's public hostname and
the correct protocol port.

Test the OsmAnd endpoint from this repository:

```bash
TRACCAR_HOST=gps.devaxis.co.zm TRACCAR_PORT=5055 \
  ./simulate.sh 123456 -15.4230 28.2950 60 50000000 true
```

If the website works but a tracker does not connect, check:

- the VPS/provider firewall as well as UFW;
- that the tracker is using the correct TCP or UDP protocol;
- the `traccar` container logs in Coolify;
- that the device identifier matches the identifier registered in Traccar.

## Local development

Create a local environment file and start the same stack with web port 8082
published directly:

```bash
cp .env.example .env
# Set TRACCAR_PUBLIC_URL=http://localhost:8082 and choose a local password.
docker compose up --build
```

Open `http://localhost:8082`.

To rebuild the custom frontend before committing it:

```bash
cd frontend
npm ci
npm run build:release
```

## Updating Traccar

The server image version in `Dockerfile` must match the version in
`frontend/package.json`. Update both the frontend source and Docker image tag
together, rebuild `web/`, test, back up PostgreSQL, and then redeploy.

## Optional webhook

To forward events to another backend, enable `forward.type` and `forward.url` in
`traccar.xml`, commit the change and redeploy.
