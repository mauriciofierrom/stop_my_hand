# Stop My Hand

Stop My Hand is a real-time, multiplayer online version of the Scarttegories
game.

> [!NOTE]
> This project is a work in progress and under development.

## Features

*   **User Accounts:** Users can register, log in, and manage their accounts.
*   **Friendship System:** Users can send and accept friend invitations.
*   **Real-time Gameplay:** The core of the application is a real-time game built with Phoenix LiveView.
*   **Online Status:** See when your friends are online.
*   Video conferencing via WebRTC (in progress)

## Technical Stack

*   **Backend:** Elixir, Phoenix, Ecto
*   **Database:** PostgreSQL
*   **Real-time:** Phoenix LiveView, Phoenix Channels, Phoenix Presence
*   **Frontend:** JavaScript, Tailwind CSS, esbuild
*   **Development Environment:** Nix

## Future Improvements: Soft Distribution (Exploration)

### Horde for Distributed Process Management
Explore replacing `DynamicSupervisor` with `Horde.DynamicSupervisor` and `Horde.Registry`

### Mnesia for Shared State
Investigate moving match state from MatchDriver (GenServer) memory into Mnesia to persist state independently of individual processes.

### libclustered for Node Discovery
Test automatic cluster formation in Kubernetes

## Getting Started

This project uses [Nix](https://nixos.org/) to provide a consistent development environment.

1.  **Clone the repository:**
    ```sh
    git clone <repository-url>
    cd stop_my_hand
    ```

2.  **Enter the development environment:**
    ```sh
    nix-shell
    ```
    This command will download all the necessary dependencies, including Elixir, Erlang, and PostgreSQL.

3.  **First-Time Database Setup:**
    If you are setting up the project for the first time, you need to initialize a local PostgreSQL data directory.

    ```sh
    # Initialize the database directory
    initdb -D ./db

    # Start the PostgreSQL server
    pg_ctl -D ./db -o "-k /tmp" start

    # Create the database using the mix alias
    mix ecto.create

    # Stop the server (optional)
    pg_ctl -D ./db stop
    ```

4.  **Running the Application:**
    To run the application, you need to have the PostgreSQL server running.

    ```sh
    # Start the PostgreSQL server if it's not running
    pg_ctl -D ./db -o "-k /tmp" start

    # Install dependencies, migrate and seed the database
    mix setup

    # Start the Phoenix server
    mix phx.server
    ```
    You can now visit [`localhost:4000`](http://localhost:4000) from your browser.

## Testing

To run the tests:

```sh
MIX_ENV=test mix test
```

To watch for changes and run tests automatically:

```sh
MIX_ENV=test mix test.watch
```

## Localization

To manage the localization files:

```sh
# Extract translatable terms from the source code
mix gettext.extract

# Merge the new terms into the existing language files
mix gettext.merge priv/gettext --locale es
```
