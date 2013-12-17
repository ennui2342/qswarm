# Qswarm - stream processing for Ruby #

Qswarm is a Ruby DSL for manipulating real-time streams of messages. It defines three basic concepts - [connections](#connections), [sources](#sources), and [sinks](#sinks). Connections emit messages which sources can catch, sinking them to other connections. In this way you can construct data flows between systems and transform messages in-flight with Ruby.

Install with:

```sh
gem install qswarm
```

## Agent ##

Use the `agent` command to wrap a set of DSL commands.

```ruby
agent :bob do
  ...
end
```

Alternatively you could save each agent in a separate file and use a process manager such as [supervisord][], [god][], [bluepill][] to manage the swarm.

## Connections ##


Use `connect` to setup connections to services. Currently [Logger](#logger), [AMQP](#amqp), [XMPP](#xmpp), and [Twitter](#twitter) are supported. You can also pass an optional block which will be executed once the connection is set up.

### Logger ###

```ruby
  connect :mylog,
          :type            => :logger,
          :filename        => 'foo.log'
```

Logger is a very simple connection type which can be used to append a stream of messages to a file. It can only `sink` messages (i.e. doesn't not emit any data) and it provides no arguments to `sink`.

### AMQP ###

```ruby
  connect :messages,
          :type            => :amqp,
          :uri             => 'guest:guest@localhost:5672/',
          :exchange_type   => :headers,
          :exchange_name   => 'myexchange',
          :exchange_args   => { :durable => true },
          :queue_args      => { :auto_delete => true, :durable => true, :exclusive => true },
          :subscribe_args  => { :exclusive => false, :ack => false },
          :bind_args       => {},
          :prefetch        => 0,
          :bind            => 'foo.bar.#',
          :format          => :json
```

This sets up an AMQP connection called `:messages` using the credentials in `:uri` (user:pass@host:port/vhost) and creates the exchange if it doesn't exist already (using `:exchange_args`). If a routing key is passed with `:bind` then a queue will be created with the dotted concatenation of the agent name and the connection name, e.g. bob.messages, and bound to the exchange specified (you can pass `:uniq => true` if you want a UUID appended to the queue name to make it unique for situations such as load balancing). At the moment you can't bind a queue to an exchange without specifying a routing key in `:bind`. You can pass configuration to the binding with `:bind_args`. Similarly `:queue_args` allow you to pass configuration options to the queue creation. Defaults for *_args are as in the example.

The agent is automatically subscribed to the created queue and you can pass `:subscribe_args` to configure the subscription. If you specified `:ack` to be true then you can use `:prefetch` to specify how many messages you want to have from the queue at a time.

The `:format` argument determines what Qswarm does with the payloads it receives and how it transforms messages to be sent, see section [Payload](#payload).

AMQP sets the following headers for `source` to use as [guards](#filters-and-guards):

* `:routing_key`
* Any headers from a headers exchange will be passed verbatim

AMQP supports the following arguments to `sink`:

* `:routing_key` - the key to post the message under
* `:headers` - a Hash that will be used instead of the payload.headers for posting to headers exchanges

### XMPP ###

```ruby
  connect :hipchat,
          :type            => :xmpp,
          :jid             => '54321_123456@chat.hipchat.com',
          :real_name       => 'My bot',
          :channel         => ['54321_lounge@conf.hipchat.com', '54321_chat@conf.hipchat.com'],
          :password        => 'foobar'
```

The above example connects to an XMPP service called `:hipchat` using the JID and password provided. The `:real_name` will be used when joining groupchat rooms and for some services (like Hipchat) needs to match exactly your registered name including case. The script will automatically join the groupchat channel(s) specified in `:channel` and will use these channels list for sinks which don't specify a channel destination. XMPP support is provided using the [Blather][] library, which means that you can include Blather DSL in connect's block to implement bot behaviours. This block will execute once the connection to the XMPP server has been established (when_ready).

Currently there is no support to `source` messages from an XMPP connection (i.e. you can only talk not listen) so the Blather DSL is your only option if you want interactivity at the moment.

XMPP supports the following arguments to `sink`:

* `:channel` - an Array or String of the groupchat channel(s) to sink the message to (will join if not already present) 

### Twitter ###

```ruby
  connect :tweetstream,
          :type            => :twitter,
          :consumer_key    => 'YOURKEYHERE',
          :consumer_secret => 'YOURSECRETHERE',
          :oauth_token     => 'YOURTOKENHERE',
          :oauth_token_secret => 'YOURSECRETHERE',
          :track           => {
            :colours         => ['red', 'green', 'blue'],
            :feelings        => ['happy', 'sad'],
            :tech            => ['ruby', 'python'],
          },
          :follow          => {
            :tech            => [11987892]
          },
          :list            => {
            :flibbertigibbets     => { 'Scobleizer' => 'most-influential-in-tech' }
          }
```

A Twitter connection uses the [Tweetstream][Tweetstream gem] and [Twitter][Twitter gem] gems and requires oAuth credentials which you can get from [dev.twitter.com][Twitter auth]. There are three options that the Twitter API gives you - you can `:track` keywords in the global tweet stream using track, you can `:follow` the full stream of particular users (by twitter ID as Tweetstream doesn't let you use handles), or you can get updates from everyone included on a `:list` (this uses the REST API and the list is polled every minute).

You specify groups (:colours/:feelings/:tech/:flibbertigibbets above) to allow for easy filtering later on with [guards](#filters-and-guards). Twitter messages are always JSON so there is no `:format` option for connect.

Twitter would set the following example headers for `source` to use depending on the `:type` that generated the message.

* **:type** => 'track', **:group** => 'colours|feelings|tech', **:matches** => [red|green|blue|happy|sad|ruby|python]
* **:type** => 'follow', **:group** => 'tech', **:user_id** => 11987892
* **:type** => 'list', **:group** => 'flibbertigibbets', **:user_id** => 'Scobleizer', **:slug** => 'most-influential-in-tech'

There is currently no support to `sink` messages to a Twitter connection - i.e. you cannot Tweet.


## Payload ##

Payload is a Hash containing the following data by default:

* payload.raw
* payload.data
* payload.format (set by arguments to the originating connect)
* payload.headers

When a message is received from a connection, it is accessible in the DSL with `payload`. The `:format` option in a `connect` declares the format of messages emitted by this connection and determines processing that will be applied to the raw payload. What this means is that if the `:format` is set to JSON, `payload.data` will be set to a Ruby Hash created by `JSON.parse(payload.raw, :symbolize_names => true)`. If `:format` is :xml then `payload.data` will be set to `Nokogiri::XML(payload.raw)`. If :raw then `payload.data` will equal `payload.raw`.

Sinks can also set `:format` to define the reverse as messages are converted back from their Ruby objects for transmission. If no argument is supplied a `sink` will assume the `connect` specified value as a default.

Some connection types add `payload.headers` which will contain a Ruby Hash of relevant data.

## Filters and Guards ##

You can use `before` and `after` as filters which will execute on receipt of a message from a specified connection. They will execute before or after your `source` commands. This example creates a plain text format of a tweet, expanding twitter handles, which can then be used in all `source` blocks.

```ruby
before :tweetstream do
    @pp = "<#{payload.data[:user][:name]}/#{payload.data[:user][:screen_name]}> #{payload.data[:text]}"
    payload.data[:entities][:user_mentions].each do |u|
      @pp.gsub!(/@#{u[:screen_name]}/,"<#{u[:name]}/#{u[:screen_name]}>")
    end
  end
```

Guards (shamelessly copied from [Blather][]) allow you to put conditional execution on `before`, `after`, and `source` blocks by filtering on data passed in `payload.headers`. Please note that header values are always Strings not Symbols.

The types of guards are:

```ruby
# Hash with any value
#   Equivalent to payload.headers[:body] == 'exit'
source :messages, :body => 'exit'

# Hash with regular expression
#   Equivalent to payload.headers[:body].match /exit/
source :messages, :body => /exit/

# Hash with array
#   Equivalent to ['gone', 'forbidden'].include?(payload.headers[:name])
source :messages, :name => ['gone', 'forbidden']

# Proc
#   Calls the proc passing in payload.headers
#   Checks that the ID is modulo 3
source :messages, Proc { |header| header[:id] % 3 == 0 }

# Array
#   Use arrays with the previous types effectively turns the guard into
#   an OR statement.
#   Equivalent to payload.headers[:body] == 'foo' || payload.headers[:body] == 'baz'
source :messages, [{:body => 'foo'}, {:body => 'baz'}]
```

## Sources ##

Sources listen to messages from connections and process them using their blocks which are executed on receipt of a message. The headers available for [guards][Filters and Guards] will be dependant on the connection that sent the message. All sources that match will receive the message and execute.

```ruby
  source  :tweetstream, :type => 'follow', :user_id => 224662544 do
    if payload.data[:text].match(/A14/)
      ...
    end
  end
```

The above will listen to messages from the `:tweetstream` connection. The [guards](#filters-and-guards) will eliminate any tweet which doesn't come from a `:follow` (rather than `:track` or `:list`) and where the user doesn't match the provided ID which happens to be the Highways Agency twitter account for East of England travel news. The pattern match for A14 is done in the block because the tweet text isn't available in the headers.

## Sinks ##

Sinks publish to connections the output of their blocks. Here's an example of sinking a text message generated from a connection sending XML messages.

```ruby
    sink  :hipchat,
          :format          => :xml,
          :channels        => ['12345_errors@conf.hipchat.com'] do

      message = payload.data.at_xpath('error')['message']
      "*** ERROR: " + message[0..140] + (message.size > 140 ? ' ... ' : ' ' ) + payload.headers.to_s
    end
```

In this case the `:format` argument isn't really needed because a return payload is specified by the block, but if the block was absent Qswarm would use it to know it needed to do a `payload.data.to_xml` before sending to the connection. You can have multiple sinks in a single source block that will all process the same payload.

## Full Example ##

```ruby
agent :bob do
  connect :hipchat,
          :type            => :xmpp,
          :jid             => '54321_123456@chat.hipchat.com',
          :channel         => ['54321_lounge@conf.hipchat.com', '54321_chat@conf.hipchat.com'],
          :password        => 'foobar'

  connect :tweetstream,
          :type            => :twitter,
          :consumer_key    => 'YOURKEYHERE',
          :consumer_secret => 'YOURSECRETHERE',
          :oauth_token     => 'YOURTOKENHERE',
          :oauth_token_secret => 'YOURSECRETHERE',
          :track           => {
            :colours         => ['red', 'green', 'blue'],
            :feelings        => ['happy', 'sad'],
            :tech            => ['ruby', 'python'],
          },
          :follow          => {
            :tech            => [11987892]
          },
          :list            => {
            :flibbertigibbets     => { 'Scobleizer' => 'most-influential-in-tech' }
          }

  source  :tweetstream, :type => %w( follow list ) do
    sink  :hipchat,
          :channel => '54321_influencers@conf.hipchat.com'
  end

  source  :tweetstream, :group => 'tech' do
    sink  :hipchat,
          :channel => '54321_cool_stuff@conf.hipchat.com'
  end
end
```

More examples can be found in these blog posts:

* [Stream processing in Ruby](http://ecafe.org/blog/2013/12/13/stream-processing-in-ruby.html)

----

[supervisord]: http://supervisord.org
[god]: http://godrb.com
[bluepill]: https://github.com/bluepill-rb/bluepill
[Blather]: https://github.com/adhearsion/blather
[Tweetstream gem]: https://github.com/tweetstream/tweetstream
[Twitter gem]: https://github.com/sferik/twitter
[Twitter auth]: https://dev.twitter.com/docs/auth/tokens-devtwittercom