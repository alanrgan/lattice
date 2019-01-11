# lattice

A simple Chord-based in-memory distributed key-value store. 

## Installation

Requires Crystal 0.27.0 and Docker.

To build the lattice docker image, run `make build`.

## Configuration

In the provided `docker-compose.yml` file, configure hosts as follows:

```yaml
<CLIENT_NAME>:
    image: lattice
    volumes:
    - /PATH/TO/CONFIG:/lattice/lattice.conf.yml
    networks:
      <STATIC_NETWORK_ID>:
        ipv4_address: <STATIC_IP_ADDRESS>
    tty: true
    depends_on:
      - <SEED_SERVICE_ID>
```

where:
- `<CLIENT_NAME>` is a unique identifier for a host container
- `/PATH/TO/CONFIG` is the path to the lattice.conf.yml file for the node
- `<STATIC_NETWORK_ID>` is ID of the static network containing the nodes
- `<SEED_SERVICE_ID>` is the container name of any seed node, which must be launched before other services.

The corresponding `lattice.conf.yml` file for the above node would look as follows:

```yaml
local:
    address: <STATIC_IP_ADDRESS>
known_hosts:
    - { address: <SEED_IP> }
    - { address: <SEED_2_IP> }
```

Multiple seeds can be specified.

## Usage

Start the application with `make run`. An interactive prompt will be displayed, through which the following commands can be run:

- `SET <KEY> <VALUE>`
- `GET <KEY>`
- `OWNERS <KEY>` - lists the addresses of the nodes that store the key locally
- `LIST_LOCAL` - list all keys that the current node stores

## Contributing

1. Fork it (<https://github.com/your-github-user/lattice/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## Contributors

- [alanrgan](https://github.com/alanrgan) Alan Gan - creator, maintainer
