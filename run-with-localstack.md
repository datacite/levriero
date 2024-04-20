## Guide to run Levriero with local dependencies

This is a simple guide on how to run Levriero (Event Data) locally. The local setup 
includes LocalStack (AWS emulation) and Lupo.

With this setup you will be able to access the Lupo API endpoints and well as access AWS
services running locally within a container.

#### Source Code
1. LocalStack (http://this.will.be.something.soon)
2. Lupo (https://github.com/datacite/lupo)
3. Levriero (https://github.com/datacite/levriero)

#### Steps
1. Start up the LocalStack container `docker compose up`
2. Start up the Lupo container `docker compose -f docker-compose.localstack.yml up`
2. Start up the Levriero container `docker compose -f docker-compose.localstack.yml up`