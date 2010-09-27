module SparseQueueHelper
  def most_recent_in_queue(sparse_queue, time)
    sparse_queue[sparse_queue.keys.select {|tick| tick <= time }.sort.last] || 0
  end
end