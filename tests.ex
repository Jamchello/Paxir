#Module containing code used to test the implemented Paxos algorithm
defmodule TestModule do
  #Basic upper later which receives the UC decide messages.
  def upper_layer do
    receive do
      {:decide, value} ->
        IO.puts "received #{inspect value}"
      upper_layer()
  end
  end
  #The following test cases each aim to address a single marking criteria from the coursework specification.
# Failure Free Scenarios
  #PASSED ([p0, p1, p2]): No failures occur and no ballots execute concurrently: 10 marks
  def no_failures() do
  p0 = :global.whereis_name(:p0)
  send(p0, {:trust, :p0})
  send(p0, {:propose, :value})
  end
  #PASSED ([p0, p1, p2]): No failures and 2 concurrent ballots: 5 marks
  def two_concurrent_ballots() do
    p0 = :global.whereis_name(:p0)
    p1 = :global.whereis_name(:p1)
    send(p0, {:trust, :p0})
    send(p1, {:trust, :p1})
    send(p0, {:propose, :p0_val})
    send(p1, {:propose, :p1_val})
  end
  #PASSED ([p0, p1, p2, p3, p4, p5]): No failures and many concurrent ballots: 5 marks
  def many_concurrent_ballots() do
    p0 = :global.whereis_name(:p0)
    p1 = :global.whereis_name(:p1)
    p2 = :global.whereis_name(:p2)
    p3 = :global.whereis_name(:p3)

    send(p0, {:trust, :p0})
    send(p1, {:trust, :p1})
    send(p2, {:trust, :p2})
    send(p3, {:trust, :p3})

    send(p0, {:propose, :p0_val})
    send(p1, {:propose, :p1_val})
    send(p2, {:propose, :p2_val})
    send(p3, {:propose, :p3_val})
  end

# Scenarios with crashes
  #PASSED ([p0, p1, p2]): One non-leader process crashes, and no ballots execute concurrently: 5 marks
  def non_leader_crash() do
    p0 = :global.whereis_name(:p0)
    p1 = :global.whereis_name(:p1)
    send(p0, {:trust, :p0})
    Process.exit(:global.whereis_name(:p1), :kill)
    send(p0, {:propose, :value})
  end
  #PASSED ([p0, p1, p2, p3, p4, p5]): A minority of non-leader processes crash, and no ballots execute concurrently: 5 marks
  def minority_non_leader_crash() do
    p0 = :global.whereis_name(:p0)
    p1 = :global.whereis_name(:p1)
    p2 = :global.whereis_name(:p2)
    send(p0, {:trust, :p0})
    Process.exit(p1, :kill)
    Process.exit(p2, :kill)
    send(p0, {:propose, :value})
    end
  #PASSED ([p0, p1, p2]): The leader of a ballot crashes, and no ballots execute concurrently: 5 marks
  def one_leader_crash() do
    p0 = :global.whereis_name(:p0)
    p1 = :global.whereis_name(:p1)

    send(p1, {:trust, :p1})
    send(p1, {:propose, :value})

    Process.exit(p1, :kill)

    send(p0, {:trust, :p0})
    send(p0, {:propose, :value2})
  end

  #PASSED ([p0, p1, p2, p3, p4, p5]): The ballot leader and some non-leaders crash; no ballots execute concurrently: 5 marks
  def minority_crash_includes_leader() do
    p0 = :global.whereis_name(:p0)
    p1 = :global.whereis_name(:p1)
    p2 = :global.whereis_name(:p2)

    send(p1, {:trust, :p1})
    send(p1, {:propose, :p1_val})
    Process.exit(p2, :kill)
    Process.exit(p1, :kill)
    
    send(p0, {:trust, :p0})
    send(p0, {:propose, :p0_val})
  end
# Scenarios with crashes & recoveries (must be performed manually in Iex because paxos is undefinied here.)
  # #PASSED ([p0, p1, p2]): Single non-leader process crashes and recovers once: 2 marks
  # def non_leader_recovery() do
  #   procs = [:p0, :p1, :p2]
  #   pids = Enum.map(procs, fn(p) -> Paxos.start(p, procs, upper_layer) end)
  #   Process.exit(:global.whereis_name(:p0), :kill)
  #   send(:global.whereis_name(:p1), {:trust, :p1})
  #   send(:global.whereis_name(:p1), {:propose, :p1_val})
  #   recovered = Paxos.start(:p0, procs, upper_layer)
  # end

  # #PASSED ([p0, p1, p2]): Multiple non-leader processes crash and recover once: 2 marks
  # def multiple_non_leaders_crash do
  #   procs = [:p0, :p1, :p2]
  #   pids = Enum.map(procs, fn(p) -> Paxos.start(p, procs, upper_layer) end)

  #   Process.exit(:global.whereis_name(:p0), :kill)
  #   Process.exit(:global.whereis_name(:p1), :kill)
  #   send(:global.whereis_name(:p2), {:trust, :p2})
  #   send(:global.whereis_name(:p2), {:propose, :p2_val})
  #   rp0 = Paxos.start(:p0, procs, upper_layer)
  #   rp1 = Paxos.start(:p1, procs, upper_layer)
  # end

  # #PASSED ([p0, p1, p2]): Multiple non-leader processes crash and recover once: 2 marks
  # def multiple_non_leaders_crash do
  #   procs = [:p0, :p1, :p2]
  #   pids = Enum.map(procs, fn(p) -> Paxos.start(p, procs, upper_layer) end)

  #   Process.exit(:global.whereis_name(:p0), :kill)
  #   Process.exit(:global.whereis_name(:p1), :kill)
  #   send(:global.whereis_name(:p2), {:trust, :p2})
  #   send(:global.whereis_name(:p2), {:propose, :p2_val})
  #   rp0 = Paxos.start(:p0, procs, upper_layer)
  #   rp1 = Paxos.start(:p1, procs, upper_layer)
  # end

  #Function used to rapidly kill a process once it has been assigneed as leader.
  def trust_and_kill() do
    p0 = :global.whereis_name(:p0)
    p1 = :global.whereis_name(:p1)
    send(p1, {:trust, :p1})
    send(p1, {:propose, :p1_val})
    Process.exit(p0, :kill)
    Process.exit(p1, :kill)
  end
end