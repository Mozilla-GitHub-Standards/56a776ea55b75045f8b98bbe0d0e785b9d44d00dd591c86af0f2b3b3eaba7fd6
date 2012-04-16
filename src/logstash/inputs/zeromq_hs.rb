require "logstash/inputs/base"
require "logstash/namespace"
require "timeout"

# Read events over a 0MQ SUB socket.
#
# You need to have the 0mq 2.1.x library installed to be able to use
# this input plugin.
#
# The default settings will create a subscriber binding to tcp://127.0.0.1:2120 
# waiting for connecting publishers.
#
class LogStash::Inputs::ZeroMQHandshake < LogStash::Inputs::Base

  config_name "zeromq_hs"
  plugin_status "experimental"

  # 0mq socket address to connect or bind to
  config :address, :validate => :string, :default => "tcp://127.0.0.1:2120"

  # 0mq topic (Used with ZMQ_SUBSCRIBE, see http://api.zeromq.org/2-1:zmq-setsockopt 
  # for 'ZMQ_SUBSCRIBE: Establish message filter')
  config :queue, :validate => :string, :default => "" # default all

  # wether to bind ("server") or connect ("client") to the socket
  config :mode, :validate => [ "server", "client"], :default => "client"

  @source = "0mq_#{@address}/#{@queue}"

  public
  def register
    require "ffi-rzmq"
    require "logstash/util/zeromq"
    self.class.send(:include, LogStash::Util::ZeroMQ)
    @subscriber = context.socket(ZMQ::REP)
    setup(@subscriber, @address)
  end # def register

  def teardown
    error_check(@subscriber.close, "while closing the zmq socket")
  end # def teardown

  def server?
    @mode == "server"
  end # def server?

  def run(output_queue)
    begin
      loop do
        puts ("Got: [" + @subscriber.recv() + "]")
        @subscriber.send('')
      end
    rescue => e
      @logger.debug("ZMQ Error", :subscriber => @subscriber,
                    :exception => e, :backtrace => e.backtrace)
    rescue Timeout::Error
      @logger.debug("Read timeout", subscriber => @subscriber)
    end # begin
  end # def run
end # class LogStash::Inputs::ZeroMQHandshake
