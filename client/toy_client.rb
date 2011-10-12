# This is a toy client sending messages to the logging infrastructure
#
require "socket"
require 'ffi-rzmq'
require "json"

DEBUG = true








######## Start internal logging to stdout #########
def INFO(msg)
    if DEBUG
        puts "INFO: " + msg
    end
end

def WARNING(msg)
    if DEBUG
        puts 'WARNING: ' + msg
    end
end

def ERROR(msg)
    if DEBUG
        puts 'ERROR: ' + msg
    end
end


######## End internal logging to stdout #########












# TODO:
# Can we add required and default arguments here?
# Rubydoc strings?  Optional stacktraces and the like would be nice
def log(transport, major, minor, kv_pairs) 
    source_object = [major, minor, kv_pairs]
    transport.send(JSON(source_object).to_s)
end

class Transport
    # This is the parent calss of transports
    def encode(json_obj)
        # This doesn't actually send to anything 
        INFO "Serializing to string"
        return json_obj.to_s
    end

    def destroy
        # Nothing to see here!
    end
end

class ZeroMQTransport < Transport
    def initialize(protocol, host, port)
        @context = ZMQ::Context.new
        # We send updates via this socket
        @publisher = @context.socket(ZMQ::PUB)
        @publisher.bind("tcp://127.0.0.1:5565")

        # TODO: we need to do a bit of handshaking instead of just
        # sleeping.  See the durapub/durasub exampes that use a sync
        # channel
    end

    def send(json_obj)
        message = encode(json_obj)
        @publisher.send_string(message)
    end

    def destroy
        @publisher.close
        @context.close
    end
end

class UDPTransport < Transport
    def initialize(host, port)
        @host = host
        @port = port
    end

    def send(json_obj)
        # huh - you don't need to specify the method name.  super just
        # calls it for you.
        msg = encode(json_obj)

        if msg.length > 512
            WARNING "Messages > 512 bytes may be lost!"
        end

        INFO "Sending UDP data to #{@host}:#{@port}"
        s = UDPSocket.new

        # This sucks - send throws :
        #   SocketERROR: send: name or service not known
        #       send at org/jruby/ext/socket/RubyUDPSocket.java:300
        # if the message is too large??  maybe this is UDP falling
        # back TCP for multipacket messages?
        flags = 0
        begin
            s.send(msg, flags, @host, @port)
            INFO "Message sent!"
        rescue SocketError => detail
            ERROR "Something went wrong. Details: [#{detail}]"
            WARNING "Message NOT sent!"
        ensure
            s.close()
        end
    end

end


def udp_main
    transport = UDPTransport.new('localhost', 2294)
    log(transport, 100, 10, {'message' => 'This is some text'})

    # Send a crazy large message
    log(transport, 100, 10, {'message' => 'blah blah' * 200000})
    INFO "Done!"
end

def zeromq_main
    # Now broadcast exactly 10 updates with pause
    transport = ZeroMQTransport.new('tcp', '127.0.0.1', 5565)
    # Note that the ZMQ client will asynchronously bind into the
    # subscriber so the first couple messages may be lost until the
    # sync code it put in
    10000.times do 
        log(transport, 100, 10, {'message' => 'This is some text'})
        INFO "Done!"
    end

    transport.destroy
end

zeromq_main()

