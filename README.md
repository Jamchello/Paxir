# COM3026 Coursework - Paxos Algorithm
## Introduction
> This is my implementation of the Paxos algorithm for uniform consensus detailed in Leslie Lamports paper "Paxos made simple".
> In this implementation every node is both an acceptor and a proposer.
## Assumption of eventual leader detector
> We assume that the system is crash-recovery and that it is built alongside an eventual leader elector component which provides TRUST events to the processes so they are aware of the leaders identity.
## Overview
> Once the module has been compiled in Iex you must create an upper layer process (which will be sent the DECIDE events from processes within the system once a decision has been reached) and a list of process names must also be defined in an array.
` pids = pids = Enum.map(procs, fn(p) -> Paxos.start(p, procs, upper_layer) end)
> Processes can be sent trust events manually through Iex to simulate the eventual leader detector:
` send(:global.whereis_name(:name_to_receive), {:trust, :name_to_trust})
> Proposals can be made by a process by sending them the following in Iex:
` send(:global.whereis_name(:name_to_receive), {:trust, :value_to_propose})

> Once a process has been trusted as a leader and has a proposal, abortable consensus begins and up to a minority of crashes can be tolerated. Processes which crash can be "recovered" by starting a new process with the exact same name. When a process is initialised it will check disc memory for a persisted version of the state and recover from file if it exists.

> When abortable consensus has been successful the upper layer will receive DECIDE events from the processes.

> A variety of different test cases are outlined in the tests.ex file.