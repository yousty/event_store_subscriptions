## [Unreleased]

## [2.0.0] - 2023-01-06

**Breaking changes**:
 - Update `event_store_client` to 3.0.0. See `event_store_client` changelog for details.

## [1.2.0] - 2022-12-23

Update `event_store_client` to 2.3.0

## [1.2.0-beta] - 2022-12-20

Update `event_store_client` to 2.3.0-beta2

## [1.1.4] - 2022-11-21

Update `event_store_client` to 2.1.x

## [1.1.3] - 2022-11-01

Fix `EventStoreSubscriptions::WatchDog.watch` method to correctly handle `restart_terminator` argument

## [1.1.2] - 2022-10-31

Calculate processed events number more accurately

## [1.1.1] - 2022-10-28

Fix restarting of subscriptions

## [1.1.0] - 2022-10-18

- Improve API atomicity
- Rework the way how subscriptions get restarted
- Implement `EventStoreSubscriptions::Subscription#restart`

## [1.0.0] - 2022-10-03

- Initial release
