# Sure Finance -- Makefile
# Atlas targets for repo documentation generation

atlas-generate:
	python3 scripts/atlas/generate_atlas.py --write

atlas-check:
	python3 scripts/atlas/generate_atlas.py --check
