![Run tests](https://github.com/yousty/event_store_client/workflows/Run%20tests/badge.svg?branch=master&event=push)
[![Gem Version](https://badge.fury.io/rb/event_store_client.svg)](https://badge.fury.io/rb/event_store_client)

# EventStoreSubscriptions

Implements EventStore DB Catch-up Subscriptions manager. 

By default `event_store_client` implements thread-blocking methods to subscribe to stream. Those are `#subscribe_to_stream` and `#subscribe_to_all`. Thus, in order to subscribe to many streams/events, you would need to implement async subscriptions by your own. This gem solves this task by putting each Subscription into its own Thread.

Thread-based implementation has its own downsides - any IO operation in your Subscriptions' handlers will block all other Threads. Thus, it is up to you how many Subscriptions to put into a single process. There is a plan to integrate Ractors instead/alongside Threads to provide the option to eliminate IO-blocking issue.

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

Use `#create` and `#create_for_all` methods to subscribe to a stream. For the full list of available arguments - see the documentation by `EventStoreClient::GRPC::Client#subscribe_to_stream` method in the [event_store_client gem docs](https://rubydoc.info/gems/event_store_client). You may also want to check the `Catch-up subscriptions` section there as well.

### Subscribing to the specific stream

In order to subscribe to specific stream - use `#create` method:

```ruby
subscriptions = EventStoreSubscriptions::Subscriptions.new(EventStoreClient.client)
handler = proc do |resp|
  if resp.success?
    do_something_with_resp(resp.success) # retrieve an event
  else # resp.failure? => true
    handle_failure(resp.failure)
  end
end
subscriptions.create('some-stream', handler: handler)
subscriptions.listen_all
```

You may provide any object which responds to `#call` as a handler:

```ruby
class SomeStreamHandler
  def call(resp)
    if resp.success?
      do_something_with_resp(resp.success) # retrieve an event
    else # resp.failure? => true
      handle_failure(resp.failure)
    end
  end
end
subscriptions = EventStoreSubscriptions::Subscriptions.new(EventStoreClient.client)
subscriptions.create('some-stream', handler: SomeStreamHandler.new)
subscriptions.listen_all
```

### Subscribing to $all stream

In order to subscribe to specific stream - use `#create_for_all` method:

```ruby
subscriptions = EventStoreSubscriptions::Subscriptions.new(EventStoreClient.client)
handler = proc do |resp|
  if resp.success?
    do_something_with_resp(resp.success) # retrieve an event
  else # resp.failure? => true
    handle_failure(resp.failure)
  end
end
subscriptions.create_for_all(handler: handler)
subscriptions.listen_all
```

You may also explicitly pass `"$all"` stream name to `#create` method:

```ruby
subscriptions = EventStoreSubscriptions::Subscriptions.new(EventStoreClient.client)
handler = proc do |resp|
  if resp.success?
    do_something_with_resp(resp.success) # retrieve an event
  else # resp.failure? => true
    handle_failure(resp.failure)
  end
end
subscriptions.create('$all', handler: handler)
subscriptions.listen_all
```

### Handling Subscription position updates

You may want to add a handler that will be executed each time a Subscription gets position updates. Such updates happen when new event is added to the stream or when EventStore DB produces a checkpoint response.

#### Listening for position updates of specific stream

Handler, registered to receive updates of position of a specific stream is called with `EventStoreSubscriptions::SubscriptionRevision` class instance. It holds current revision of stream.

```ruby
subscriptions = EventStoreSubscriptions::Subscriptions.new(EventStoreClient.client)
subscription = subscriptions.create('some-stream', handler: proc { |r| p r })
subscription.position.register_update_hook do |position|
  puts "Current revision is #{position.revision}"
end
subscription.listen
```

#### Listening for position updates of $all stream

Handler, registered to receive updates of position of a `$all` stream is called with `EventStoreSubscriptions::SubscriptionPosition` class instance. It holds current `commit_position` and `prepare_position` of `$all` stream.

```ruby
subscriptions = EventStoreSubscriptions::Subscriptions.new(EventStoreClient.client)
subscription = subscriptions.create_for_all(handler: proc { |r| p r })
subscription.position.register_update_hook do |position|
  puts "Current commit/prepare positions are #{position.commit_position}/#{position.prepare_position}"
end
subscription.listen
```

### Automatic restart of failed Subscriptions

This gem provides a possibility to watch over your Subscriptions collections and restart a Subscription in case it failed. Subscription may fail because an exception was raised in either its handler or in position update hook. New Subscription will start from the position the failed Subscription has stopped. 

Start watching over your Subscriptions collection:

```ruby
subscriptions = EventStoreSubscriptions::Subscriptions.new(EventStoreClient.client)
subscriptions.create_for_all(handler: proc { |r| p r })
watcher = EventStoreSubscriptions::WatchDog.new(subscriptions)
watcher.watch
subscriptions.listen_all
```

### Graceful shutdown

You may want to gracefully shut down your process that handles your Subscriptions. In order to do so, you should define `Kernel.trap` handler to handle your kill signal.

```ruby
subscriptions = EventStoreSubscriptions::Subscriptions.new(EventStoreClient.client)
subscriptions.create_for_all(handler: proc { |r| p r })
watcher = EventStoreSubscriptions::WatchDog.new(subscriptions)
watcher.watch
subscriptions.listen_all

Kernel.trap('TERM') do
  # Because the implementation uses Mutex - wrap it into Thread to bypass the limitations of
  # Kernel#trap
  Thread.new do
    # Initiate graceful shutdown
    watcher.unwatch.wait_for_finish
    subscriptions.stop_all.each(&:wait_for_finish)
  end.join
  exit
end

logger = Logger.new('subscriptions.log')
# Wait while Subscriptions are working
loop do
  sleep 1  
  # You can put here whatever you want. For example - tracking the status of your subscriptions
  logger.info "Subscriptions number: #{subscriptions.subscriptions.size}"
  subscriptions.subscriptions.each do |subscription|
    logger.info "Subscription state: #{subscription.state}"
    logger.info "Subscription statistic: #{subscription.statistic.inspect}"
  end
end
```

Now, when you want to gracefully shut down your process - just send `TERM` signal:

```bash
kill -TERM <pid of your process>
```

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
