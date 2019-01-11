.PHONY: clean, build

clean:
	docker images -f "dangling=true" -q | xargs docker rmi

build:
	docker build -t lattice .

run:
	docker-compose up -d && docker attach lattice_seed_1