class Ssh::StreamBuffer
  def initialize(interval: 1.second)
    @buffer = []
    @mutex = Mutex.new
    @interval = interval
    @running = true
    @block = nil
  end

  def write(data)
    @mutex.synchronize { @buffer << data }
  end

  def start(&block)
    @block = block
    @timer = create_timer(&block)
  end

  def stop
    @running = false
    @timer&.kill
    flush { |data| @block.call(data) } if @block && block_given?
  end

  private

  def create_timer
    Thread.new do
      while @running
        sleep @interval
        flush { |data| yield(data) if block_given? }
      end
    end
  end

  def flush
    current_data = nil
    @mutex.synchronize do
      if @buffer.any?
        current_data = @buffer
        @buffer = []
      end
    end
    yield(current_data) if current_data && block_given?
  end
end
