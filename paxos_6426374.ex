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
        pid_to_rank = for p <- processes, into: %{}, do: {:global.whereis_name(p), rank[p]}

        state = %{ 
            name: name, 
            processes: processes,
            upper_layer: upper_layer,
            rank: rank,
            my_rank: rank[name],
            pid_to_rank: pid_to_rank,

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
            # delivered: (for _ <- 1..length(processes), do: false),
            # broadcast: false
        }
        # start_failure_detector(Map.keys(pid_to_rank))
        run(state)
    end

 def run(state) do
        
        state = receive do

            # {:DOWN, _, :process, pid, _} ->
            #     IO.puts("#{inspect state.name}: rank #{inspect state.pid_to_rank[pid]} detected")
            #     send(self(), {:internal_event})
            #     %{state | detected_ranks: MapSet.put(state.detected_ranks, 
            #         state.pid_to_rank[pid])}

            {:trust, p} -> 
                IO.puts("#{inspect state.name}: trust #{inspect p}")
                send(self(), {:internal_event})
                %{state |leader: p}
            {:decide, v} ->
                state = if state.status != "delivered" do
                IO.puts("#{state.name}: UC delivers message #{inspect v}")
                # send(state.upper_layer)
                %{state| status: "delivered"}
                else
                state
                end
                state
            {:prepare, b, p} ->
                state = if b > state.currentBallot do
                send(p, {:prepared, b, state.a_ballot, state.a_Value, self()})
                IO.puts("Preparing for ballot #{inspect b}")
                %{state| currentBallot: b}
                else
                IO.puts("Rejected ballot #{inspect b}")
                send(p, {:nack, b})
                state
                end
                state
            {:prepared, b, aB,aV,p} ->
                state = if b == state.myBallot and state.status == "preparing" do
                send(self(), {:internal_event})
                %{state| previousVotes: MapSet.put(state.previousVotes, [aB, aV, p])}
                else
                state
                end
                state
            {:accept, b,v, p} ->
                state = if b >= state.currentBallot and b >state.a_ballot do
                send(p,{:accepted, b, self()})
                %{state|currentBallot: b, a_ballot: b, a_Value: v}
                else
                send(p, {:nack, b})
                state
                end
                state
            {:accepted, b, p} ->
                if state.status == "polling" and b == state.myBallot do
                send(self(), {:internal_event})
                %{state| votes: MapSet.put(state.votes,p)}
                else
                state
                end
            {:nack, b} ->
                if b == state.myBallot and (state.status == "polling" or state.status == "preparing")  do
                %{state| status: "waiting", votes: %MapSet{}, previousVotes: %MapSet{}}
                else
                state
                end
                state

            # {:decided, v, p} ->
            #     IO.puts("#{inspect state.name}: decided received #{inspect v}")
            #     r = state.rank[p]
            #     {proposal, proposer} = if r < state.my_rank and r > state.proposer, 
            #         do: {v, r}, else: {state.proposal, state.proposer}
            #     delivered = List.replace_at(state.delivered, r, true)
            #     send(self(), {:internal_event})
            #     %{state | proposal: proposal, proposer: proposer, delivered: delivered}

            {:propose, val} ->
                IO.puts("#{inspect state.name}: proposes #{inspect val}")
                send(self(), {:internal_event})
                %{state | proposal: val}

            {:internal_event} ->
                check_internal_events(state)
        end
        run(state)
    end

    def check_internal_events(state) do

        # if state.name == :p1 do
        #     IO.puts(inspect(state))
        # end

        # state = if state.round == state.my_rank and state.proposal != nil and not state.broadcast do
        #     IO.puts("#{inspect state.name}: coordinator of round #{inspect state.round}, proposal=#{inspect state.proposal}")
        #     state = %{state | broadcast: true}
        #     # if state.name == :p0, do: Process.exit(self(), :kill)
        #     beb_broadcast({:decided, state.proposal, state.name}, state.processes)
        #     send(self(), {:decide, state.proposal})
        #     send(self(), {:internal_event})
        #     state
        # else
        #     state
        # end

        # state = if (state.round in state.detected_ranks) or Enum.at(state.delivered, state.round) do
        #     IO.puts("#{inspect state.name}: advance to round #{inspect state.round + 1}")
        #     send(self(), {:internal_event})
        #     %{state | round: state.round + 1}
        # else
        #     state
        # end
        state = if MapSet.size(state.votes) > (state.gap/2) and state.status == "polling" do
        beb_broadcast({:decide, state.value}, state.processes)
        state
        else
        state
        end

        state = if to_string(state.name) == to_string(state.leader) and state.proposal != nil and state.status == "waiting" do
            beb_broadcast({:prepare, (state.myBallot + state.gap), self()}, state.processes)
            %{state|status: "preparing", myBallot: (state.myBallot + state.gap)}
            else
            state
            end
        state = if MapSet.size(state.previousVotes) > (state.gap/2) and state.status == "preparing" do
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
        state
    end
    # Send message m point-to-point to process p
    defp unicast(m, p) do
        case :global.whereis_name(p) do
                pid when is_pid(pid) -> send(pid, m)
                :undefined -> :ok
        end
    end
    defp beb_broadcast(m, dest), do: for p <- dest, do: unicast(m, p)
end