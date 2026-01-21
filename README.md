# StopMyHand

To start your Phoenix server:

  * Run `mix setup` to install and setup dependencies
  * Start the nix-provided PostgreSQL `pg_ctl -D ./db -o "-k /tmp" start`
  * Start Phoenix endpoint with `mix phx.server` or inside IEx with `iex -S mix phx.server`

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Test

To run the tests use:

`MIX_ENV=test mix test`

or to watch changes use

`MIX_ENV=test mix test.watch`

## Generate locales

```
mix extract
mix gettext.merge priv/gettext --locale es
```
