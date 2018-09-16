# Changelog

## Unreleased

## 0.6.2 (2018-09-16)

### Changed

- Make setup of exchanges/queues/bindings async, so that application doesn't crash if rabbit is unavailable

## 0.6.1 (2018-04-12)

### Changed

- Hibernate processes that deal with large binaries to prevent unbounded growth

## 0.6.0 (2018-04-12)

### Changed

- Log reasons for failures like disconnect, etc
- Namespace process names, to allow multiple instances of the same adapter to run at once
- Add and use child_spec/1 functions
- Replace subscriber runner with `Task`

## 0.5.0 (2018-04-12)

- Unreleased

## 0.4.6 (2018-02-21)

### Fixed

- Allow `:from` to not be specified for queue. Needed for defining bindings with direct and fanout exchanges.

## 0.4.5 (2018-01-12)

### Changed

- Allow `:from` to not be specified for queue. Needed for defining bindings with direct and fanout exchanges.

## 0.4.4 (2018-01-22)

- No notable changes

## 0.4.3 (2018-01-22)

### Changed

- Added lots of logging for up/down events on connections, channels, subscribers, etc

## 0.4.2 (2017-09-15)

### Changed

- Allow specifying global options at the adapter level (e.g. `:prefetch_count`)

## 0.4.1 (2017-04-02)

### Changed

- Use official amqp library instead of forked version

## 0.4.0 (2017-02-21)

### Updated

- Updated to support conduit 0.8.0

## 0.3.1 (2017-01-12)

### Fixes

- Fixes deprecation warnings for newer versions of elixir

## 0.3.0 (2017-01-02)

### Fixes

- Requires conduit 0.7.0, instead of just allowing it

## 0.2.0 (2017-01-01)

### Updated

- Changed to support conduit 0.7.0, which changed adapter API

## 0.1.3 (2016-12-16)

### Fixes

- URL can be passed for connection instead of just individual components

## 0.1.2 (2016-12-15)

- No notable changes

## 0.1.1 (2016-12-14)

- No notable changes

## 0.1.0 (2016-12-12)

- Initial version
