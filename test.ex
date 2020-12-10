#Simple test module which will print to console any decisions received from paxos nodes.
defmodule TestModule do
  def run do
    receive do
      {:decide, value, sender} ->
        IO.puts "received #{inspect value} from #{inspect sender}"
  end
  end
end