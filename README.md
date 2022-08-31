![Run tests](https://github.com/yousty/event_store_client/workflows/Run%20tests/badge.svg?branch=master&event=push)
[![Gem Version](https://badge.fury.io/rb/event_store_client.svg)](https://badge.fury.io/rb/event_store_client)

# EventStoreSubscriptions

Welcome to your new gem! In this directory, you'll find the files you need to be able to package up your Ruby library into a gem. Put your Ruby code in the file `lib/event_store_subscriptions`. To experiment with that code, run `bin/console` for an interactive prompt.

TODO: Delete this and the text above, and describe your gem

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'event_store_subscriptions'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install event_store_subscriptions

## Usage

TODO: Write usage instructions here

## Development

You will have to install Docker first. It is needed to run EventStore DB. You can run EventStore DB with next command:

```shell
docker-compose -f docker-compose-cluster.yml up
```

Now you can enter dev console by running `bin/console` or run tests by running `rspec` command.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/event_store_subscriptions. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/event_store_subscriptions/blob/master/CODE_OF_CONDUCT.md).

### Publishing new version

1. Push commit with updated `version.rb` file to the `release` branch. The new version will be automatically pushed to [rubygems](https://rubygems.org).
2. Create release on GitHub including change log.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the EventStoreSubscriptions project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/event_store_subscriptions/blob/master/CODE_OF_CONDUCT.md).
