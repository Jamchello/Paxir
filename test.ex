#Simple test module which will print to console any decisions received from paxos nodes.
defmodule TestModule do
  def run do
    receive do
      {:decide, value} ->
        IO.puts "received #{inspect value}"
  end
  end
end