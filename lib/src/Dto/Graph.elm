module Dto.Graph exposing (Graph, findNodesInCycles)

import Dict exposing (Dict)
import Set exposing (Set)


type alias Graph =
    Dict String (Set String)


findNodesInCycles : Graph -> Set String
findNodesInCycles graph =
    initialState graph
        |> forEachRoot (\root -> depthFirstSearchCycles root root)
        |> .found


depthFirstSearchCycles : String -> String -> State -> State
depthFirstSearchCycles root node state =
    state
        |> stackPush node
        |> forEachNeighborOf node
            (\neighbor state_ ->
                if neighbor == root then
                    foundCycle state_

                else if inStack node state then
                    state_

                else
                    depthFirstSearchCycles root neighbor state_
            )
        |> stackPop


type alias State =
    { found : Set String
    , graph : Graph
    , stack : List String
    }


initialState : Graph -> State
initialState graph =
    { graph = graph
    , found = Set.empty
    , stack = []
    }


forEachRoot : (String -> State -> State) -> State -> State
forEachRoot f state =
    case nextRoot state of
        Just root ->
            f root state
                |> removeRoot root
                |> forEachRoot f

        Nothing ->
            state


forEachNeighborOf : String -> (String -> State -> State) -> State -> State
forEachNeighborOf node f state =
    let
        rec neighbors state_ =
            case neighbors of
                neighbor :: nextNeighbors ->
                    f neighbor state_
                        |> rec nextNeighbors

                [] ->
                    state_
    in
    rec (getNeighbors node state) state


nextRoot : State -> Maybe String
nextRoot s =
    s.graph |> Dict.keys |> List.head


removeRoot : String -> State -> State
removeRoot n s =
    { s | graph = Dict.remove n s.graph }


getNeighbors : String -> State -> List String
getNeighbors node s =
    s.graph
        |> Dict.get node
        |> Maybe.withDefault Set.empty
        |> Set.toList


stackPush : String -> State -> State
stackPush n s =
    { s | stack = n :: s.stack }


stackPop : State -> State
stackPop s =
    { s | stack = List.drop 1 s.stack }


foundCycle : State -> State
foundCycle s =
    { s | found = List.foldl Set.insert s.found s.stack }


inStack : String -> State -> Bool
inStack n s =
    List.member n s.stack
