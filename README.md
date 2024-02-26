# OneNet Deployment

- Edit `.env`

    Change `KEYCLOAK_AUTH_URL_PROD`, `KEYCLOAK_URL_PROD` and `ISSUER_URI` to point to your Keycloak instance.

- Edit `analytics.env`

    Change `ALLOWED_HOSTS` to allow your machine's IP address or the domain pointing to the dashboard.

- Build the necessary docker images. Refer to the README.md of each component:

    + [Frontend](https://github.com/ubitech/onenet-dashboard-frontend)
    + [Backend](https://github.com/ubitech/onenet-dashboard-backend)
    + [Analytics](https://github.com/ubitech/onenet-dashboard-analytics)

- Start the services:

    ```
    docker-compose up -d
    ```

## Notes

- The production related variables are set in `.env` file.
- This starts backend, frontend, keycloak, analytics, db as Docker containers communicating.

## Troubleshooting

If you run by a message "keycloak user already exists" when the container is starting OR the keycloak container does not start at all, you have two choices:
- In [docker-compose.yml](./docker-compose.yml) comment out the `KEYCLOAK_USER` and `KEYCLOAK_PASSWORD` lines like so:

    ```
    environment:
    # - KEYCLOAK_USER=${KEYCLOAK_ADMIN_USERNAME}
    # - KEYCLOAK_PASSWORD=${KEYCLOAK_ADMIN_PASSWORD}
    ```

    Then start the container. It should start normally. Finally, revert the changes to `docker-compose.yml`.

OR

- Run `docker compose down -v` destroying the volumes. The next time up, the keycloak configuration will be imported from scratch via the *-realm.json that is used on the import. NOTE this will destroy all database entries and data.

This is common problem with keycloak and happens if container is stopped before initialized completely, or forcefully stopped.
