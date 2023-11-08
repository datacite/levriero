#Guide to running Levriero entirely locally

In order to enable Levriero to access the Lupo API locally we need both Lupo and Levriero to run within the same docker network. 

The network is defined in the Lupo **docker-compose.network.yml** and is called **public**.

Levriero joins this network through the identifier **lupo_public**.

## Steps
1. Start the Lupo container by executing `docker compose -f docker-compose.network.yml up`

2. Start the Levriero container by executing `docker compose -f docker-compose.network.yml up`