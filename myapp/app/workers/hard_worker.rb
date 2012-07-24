class HardWorker
  include Adam::Worker
  adam_options :timeout => 20, :backtrace => 5

  def perform(name)
    puts "I'm a worker, yay #{name}"
  end
end
