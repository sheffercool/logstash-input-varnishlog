# encoding: utf-8
require "logstash/inputs/threadable"
require "logstash/namespace"
require "socket" # for Socket.gethostname


# Read from varnish cache's shared memory log
class LogStash::Inputs::Varnishlog < LogStash::Inputs::Threadable
  config_name "varnishlog"

  public
  def register
    require 'varnish'
    @vd = Varnish::VSM.VSM_New
    Varnish::VSL.VSL_Setup(@vd)
    Varnish::VSL.VSL_Open(@vd, 1)

  end # def register

  def run(queue)
    @q = queue
    @hostname = Socket.gethostname
    Varnish::VSL.VSL_Dispatch(@vd, self.method(:cb).to_proc, FFI::MemoryPointer.new(:pointer))
  end # def run

  private
  def cb(priv, tag, fd, len, spec, ptr, bitmap)
    begin
      str = ptr.read_string(len)
      event = LogStash::Event.new("message" => str, "host" => @hostname)
      decorate(event)
      event.set("varnish_tag", tag)
      event.set("varnish_fd", fd)
      event.set("varnish_spec", spec)
      event.set("varnish_bitmap", bitmap)
      @q << event
    rescue => e
      @logger.warn("varnishlog exception: #{e.inspect}")
    ensure
      return 0
    end
  end
  
  public
  def close
    finished
  end # def close
end # class LogStash::Inputs::Stdin
