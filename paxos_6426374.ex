#ToDo:
#-Create test cases, make sure passes all of them, document in readMe & report.
#-Complete detailed comments
#-Clean up code a little
#-Check with Prof Chockler if naming convention is okay.
defmodule Paxos do

 def start(name, processes, upper_layer) do
        pid = spawn(Paxos, :init, [name, processes, upper_layer])
        # :global.unregister_name(name)
        case :global.re_register_name(name, pid) do
            :yes -> pid  
            :no  -> :error
        end
        IO.puts "registered #{name}"
        pid
    end


def init(name, processes, upper_layer) do 
        Process.sleep(10)
        rank = for {p, r} <- Enum.zip(processes, 0..(length(processes) - 1)), 
                    into: %{}, do: {p, r}
        state = if File.exists?("#{to_string(name)}.txt") == true do
        IO.puts("#{name} has been recovered.")
        beb_broadcast({:restored,name}, processes)
        read(name)
        else
        File.write("#{to_string(name)}.txt",:erlang.term_to_binary(%{}))
        %{ 
            name: name, 
            processes: processes,
            upper_layer: upper_layer,
            rank: rank,
            my_rank: rank[name],

            value: nil,
            proposal: nil,
            status: "waiting",
            leader: nil,
            gap: length(processes),
            myBallot: rank[name],
            previousVotes: %MapSet{},
            votes: %MapSet{},
            currentBallot: -1,
            a_ballot: -1,
            a_Value: nil,
        }
        end
        save(name, state)
        run(state)
    end

 def run(state) do
        
        state = receive do
            {:trust, p} -> 
                IO.puts("#{inspect state.name}: trust #{inspect p}")
                send(self(), {:internal_event})
                %{state |leader: p}
            #UC propose indication from the upper layer.
            {:propose, val} ->
                IO.puts("#{inspect state.name}: proposes #{inspect val}")
                send(self(), {:internal_event})
                %{state | proposal: val}
            #Handling message received by acceptors from the leader during prepare phase
            {:prepare, b, p} ->
                state = if b > state.currentBallot do
                send(p, {:prepared, b, state.a_ballot, state.a_Value, state.name})
                IO.puts("Prepared for ballot #{inspect b}")
                %{state| currentBallot: b}
                else
                IO.puts("Rejected ballot #{inspect b}")
                send(p, {:nack, b})
                state
                end
                state
            #Handling message revieved by leader from acceptors indicating they are prepared.
            {:prepared, b, aB,aV,p} ->
                state = if b == state.myBallot and state.status == "preparing" do
                send(self(), {:internal_event})
                %{state| previousVotes: MapSet.put(state.previousVotes, [aB, aV, p])}
                else
                state
                end
                state
            #Message sent by leader to acceptors when the number of prepared nodes is a majority
            {:accept, b,v, p} ->
                state = if b >= state.currentBallot and b >state.a_ballot do
                send(p,{:accepted, b, state.name})
                %{state|currentBallot: b, a_ballot: b, a_Value: v}
                else
                send(p, {:nack, b})
                state
                end
                state
            #Message received by leader from acceptor when they accept proposal.
            {:accepted, b, p} ->
                if state.status == "polling" and b == state.myBallot do
                send(self(), {:internal_event})
                %{state| votes: MapSet.put(state.votes,p)}
                else
                state
                end
            #Message received acceptors from leader instructing them to deliver the accepted proposal
            {:decide, v} ->
                state = if state.status != "delivered" do
                IO.puts("#{state.name}: UC delivers message #{inspect v}")
                send(state.upper_layer, {:decide, v})
                %{state| status: "delivered"}
                else
                state
                end
                state
            #In the case that a nack is sent to leader from acceptors during either phase, start a new round of abortable consensus.
            {:nack, b} ->
                state = if b == state.myBallot and (state.status == "polling" or state.status == "preparing")  do
                IO.puts("Received a nack for ballot ##{inspect b}, current status: #{state.status}")
                send(self(), {:internal_event})
                %{state| status: "waiting", votes: %MapSet{}, previousVotes: %MapSet{}}
                else
                state
                end
                state
            {:restored, p} ->
                state = cond do
                state.status == "waiting" ->
                    state
                state.status == "preparing" and not MapSet.member?(state.previousVotes,p) ->
                    send(:global.whereis_name(p),{:prepare, state.myBallot, self()})
                    state
                state.status == "polling" and not MapSet.member?(state.votes,p) ->
                    send(:global.whereis_name(p),{:accept, state.myBallot, state.value, self()})
                    state
                state.status == "delivered" ->
                    send(:global.whereis_name(p),{:decide, state.value})
                    state
                end
                state
            # if state.status == "preparing" and MapSet.member?(state.previousVotes,p_name) do
            # send(p,{:prepare, state.myBallot})
            # else if 
            {:internal_event} ->
                check_internal_events(state)
        end
        save(state.name, state)
        run(state)
    end

    #Handles any internal events carried out by the leader.
    def check_internal_events(state) do
        #When node is leader, has a proposal ready and has not delivered: begin prepare phase
        state = if to_string(state.name) == to_string(state.leader) and state.proposal != nil and state.status == "waiting" do
            #Creating a unique, incrementing ballot number based on the number of processes in system and the processes unique rank number.
            beb_broadcast({:prepare, (state.myBallot + state.gap), self()}, state.processes)
            %{state|status: "preparing", myBallot: (state.myBallot + state.gap)}
            else
            state
            end
        #Upon a quorum of prepared acceptors,
        #if there exists a value already accepted by quorum, take this value (from the vote with highest ballot number that is not nil)
        #Otherwise, use own proposal for accept phase.
        state = if MapSet.size(state.previousVotes) > (state.gap/2) and state.status == "preparing" and to_string(state.name) == to_string(state.leader)do
            IO.puts("#{inspect state.name}:  Received Quorum of votes for ballot number #{state.myBallot}")
            temp = List.last(Enum.filter(Enum.sort(state.previousVotes), fn([_,v,_]) -> v != nil end))
            [_, val,_] = if temp == nil do
            [nil,state.proposal, nil]
            else
            temp
            end
            beb_broadcast({:accept, state.myBallot, val , self()}, state.processes)
            IO.puts("#{state.name}: polling for value #{inspect val}")
            %{state| status: "polling", votes: %MapSet{}, value: val}
            else
            state
            end
        #Upon a quorum of accepted votes, decide on the value from this ballot.
        state = if MapSet.size(state.votes) > (state.gap/2) and state.status == "polling" and to_string(state.name) == to_string(state.leader) do
            beb_broadcast({:decide, state.value}, state.processes)
            state
            else
            state
            end
            state
    end
    # Send message m point-to-point to process p
    defp unicast(m, p) do
        case :global.whereis_name(p) do
                pid when is_pid(pid) -> send(pid, m)
                :undefined -> :ok
        end
    end
    # Implementation of Best Effort Broadcast - iterate through all processes and pl send the message.
    defp beb_broadcast(m, dest), do: for p <- dest, do: unicast(m, p)

    defp save(proc, state) do
    {:ok, peristant_state} = File.read("states.txt")
    peristant_state = :erlang.binary_to_term(peristant_state)
    {:ok, file} = File.open("#{to_string(proc)}.txt", [:write])
    IO.binwrite(file, :erlang.term_to_binary(Map.put(peristant_state, proc,state)) )
    end

    defp read(proc) do
    {:ok, peristant_state} = File.read("#{to_string(proc)}.txt")
    Map.get(:erlang.binary_to_term(peristant_state), proc)
    end
end