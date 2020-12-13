#Simple test module which will print to console any decisions received from paxos nodes.
defmodule TestModule do
  def run do
    receive do
      {:decide, value} ->
        IO.puts "received #{inspect value}"
  end
  end

  def save(pid, state) do
  {:ok, peristant_state} = File.read("states.txt")
  peristant_state = :erlang.binary_to_term(peristant_state)
  {:ok, file} = File.open("states.txt", [:write])
  IO.binwrite(file, :erlang.term_to_binary(Map.put(peristant_state, pid,state)) )

  end

  def read(proc) do
  {:ok, peristant_state} = File.read("states.txt")
  Map.get(:erlang.binary_to_term(peristant_state), proc)
  end
end