# Building Skybeam on the Server

Due to cross-platform build issues with Elixir 1.16 and Hex when building for linux/amd64 from a different architecture, skybeam should be built directly on the server.

## Quick Build on Server

### Option 1: Clone and Build

```bash
# SSH into the server
ssh deploy@164.90.132.64

# Clone the repository (or use existing checkout)
git clone <your-repo-url> /path/to/news
cd /path/to/news

# Login to Docker Hub
docker login -u librenews
# Enter your Docker Hub access token when prompted

# Build and push
docker build -f docker/skybeam/Dockerfile --target production -t librenews/skybeam:latest .
docker push librenews/skybeam:latest
```

### Option 2: Use SCP to Transfer Files

```bash
# From your local machine, copy the necessary files
scp -r docker/skybeam deploy@164.90.132.64:/tmp/skybeam-build/
scp skybeam/mix.exs skybeam/mix.lock skybeam/config skybeam/lib skybeam/assets skybeam/priv deploy@164.90.132.64:/tmp/skybeam-build/ -r

# Then on the server
ssh deploy@164.90.132.64
cd /tmp/skybeam-build
docker login -u librenews
docker build -f docker/skybeam/Dockerfile --target production -t librenews/skybeam:latest .
docker push librenews/skybeam:latest
```

### Option 3: Use the Build Script

If you've copied the project to the server:

```bash
export REGISTRY_PASSWORD="your_docker_hub_token"
chmod +x scripts/build-skybeam-on-server.sh
./scripts/build-skybeam-on-server.sh
```

## Why Build on Server?

The Elixir/Hex build process has issues when cross-compiling for linux/amd64 from macOS (especially ARM). Building natively on the server (which is already linux/amd64) avoids these compilation conflicts.

## After Building

Once the image is pushed, you can deploy it with Kamal:

```bash
kamal accessory boot skybeam -c config/deploy/kamal.yml
```

