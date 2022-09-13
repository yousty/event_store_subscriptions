![Run tests](https://github.com/yousty/event_store_client/workflows/Run%20tests/badge.svg?branch=master&event=push)
[![Gem Version](https://badge.fury.io/rb/event_store_client.svg)](https://badge.fury.io/rb/event_store_client)

# EventStoreSubscriptions

Extends the functionality of the [EventStoreDB ruby client](https://github.com/yousty/event_store_client) with a catch-up subscriptions manager. 

By default `event_store_client` implements thread-blocking methods to subscribe to a stream. Those are `#subscribe_to_stream` and `#subscribe_to_all`. In order to subscribe to many streams/events, you need to implement asynchronous subscriptions on your own. This gem solves this task by putting each subscription into its own thread.

The thread-based implementation has a downside: any IO operation in your subscription's handlers will block all other threads. So it is important to consider how many subscriptions you put into a single process. There is a plan to integrate Ractors instead/alongside threads to provide the option to eliminate the IO-blocking issue.

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

Use the `#create` and `#create_for_all` methods to subscribe to a stream. For the full list of available arguments see the documentation of the `EventStoreClient::GRPC::Client#subscribe_to_stream` method in the [event_store_client gem docs](https://rubydoc.info/gems/event_store_client). You may also want to check the `Catch-up subscriptions` section there as well.

### Subscribing to a specific stream

Use the `#create` method in order to subscribe to specific stream:

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

### Subscribing to the $all stream

Use the `#create_for_all` method to subscribe to the all stream:

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

You may also explicitly pass `"$all"` stream name to the `#create` method:

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

You may want to add a handler that will be executed each time a subscription gets position updates. Such updates happen when new events are added to the stream or when EventStore DB produces a checkpoint response.

#### Listening for position updates of a specific stream

A handler registered to receive position updates of a specific stream is called with the `EventStoreSubscriptions::SubscriptionRevision` class instance. It holds the current revision of the stream.

```ruby
subscriptions = EventStoreSubscriptions::Subscriptions.new(EventStoreClient.client)
subscription = subscriptions.create('some-stream', handler: proc { |r| p r })
subscription.position.register_update_hook do |position|
  puts "Current revision is #{position.revision}"
end
subscription.listen
```

#### Listening for position updates of the $all stream

A handler registered to receive position updates of the `$all` stream is called with the `EventStoreSubscriptions::SubscriptionPosition` class instance. It holds the current `commit_position` and `prepare_position` of the `$all` stream.

```ruby
subscriptions = EventStoreSubscriptions::Subscriptions.new(EventStoreClient.client)
subscription = subscriptions.create_for_all(handler: proc { |r| p r })
subscription.position.register_update_hook do |position|
  puts "Current commit/prepare positions are #{position.commit_position}/#{position.prepare_position}"
end
subscription.listen
```

### Automatic restart of failed Subscriptions

This gem provides a possibility to watch over your subscription collections and restart a subscription in case it failed. Subscriptions may fail because an exception was raised in the handler or in the position update hook. A new subscription will be started, listening from the position the failed subscription has stopped. 

Start watching over your subscriptions collection:

```ruby
subscriptions = EventStoreSubscriptions::Subscriptions.new(EventStoreClient.client)
subscriptions.create_for_all(handler: proc { |r| p r })
watcher = EventStoreSubscriptions::WatchDog.watch(subscriptions)
subscriptions.listen_all
```

### Graceful shutdown

You may want to gracefully shut down the process that handles the subscriptions. In order to do so, you should define a `Kernel.trap` handler to handle your kill signal:

```ruby
subscriptions = EventStoreSubscriptions::Subscriptions.new(EventStoreClient.client)
subscriptions.create_for_all(handler: proc { |r| p r })
watcher = EventStoreSubscriptions::WatchDog.watch(subscriptions)
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

Now just send the `TERM` signal if you want to gracefully shut down your process:

```bash
kill -TERM <pid of your process>
```

## Development

You will have to install Docker first. It is needed to run EventStore DB. You can run EventStore DB with this command:

```shell
docker-compose -f docker-compose-cluster.yml up
```

Now you can enter a dev console by running `bin/console` or run tests by running the `rspec` command.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/event_store_subscriptions. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/event_store_subscriptions/blob/master/CODE_OF_CONDUCT.md).

### Publishing new version

1. Push commit with updated `version.rb` file to the `release` branch. The new version will be automatically pushed to [rubygems](https://rubygems.org).
2. Create release on GitHub including change log.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the EventStoreSubscriptions project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/event_store_subscriptions/blob/master/CODE_OF_CONDUCT.md).
