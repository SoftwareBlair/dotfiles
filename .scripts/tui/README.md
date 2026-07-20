# Setup TUI (Bubble Tea)

Go terminal UI for **dotfiles-setup**. Architecture overview: [docs/architecture.md](../../docs/architecture.md).

## Build

```bash
cd .scripts/tui
go build -o ../bin/dotfiles-setup .
```

## Run

```bash
../setup.sh --tui
../setup.sh --tui -n
./dotfiles-setup --catalog testdata/catalog_default_and_blair.json --dry-run
```

## Tests

```bash
./test.sh          # go test ./... + catalog export smoke
go test ./...
```

See [docs/contributing.md](../../docs/contributing.md) for expected coverage (wizard steps, profile preview → confirm, dry-run, migrate, engine argv).
