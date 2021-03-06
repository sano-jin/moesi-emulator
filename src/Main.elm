module Main exposing (..)

import Browser
import Html exposing (Html, button, div, text, select, option, table, tr, td, tbody, th, node)
import Html.Attributes exposing (value, selected, class, href, rel)
import Html.Events exposing (onClick, onInput)

main =
    Browser.sandbox { init = init, update = update, view = view }

-- Model
type ReadOrWrite
    = Read 
    | Write

type alias PE = { op : ReadOrWrite, index : Int } 
      
type alias Model = 
    { pe_list : List PE 
    , pe_n : Int
    }
    
init : Model
init =
    { pe_list = [ { op = Read, index = 0 }
                , { op = Read, index = 2 }
                , { op = Write, index = 1 }
                , { op = Read, index = 3 }
                ]
    , pe_n = 4 }

-- Upddate        
type Msg
    = SelectPE Int String
    | FlipRW Int
    | AddPE
    | RemovePE Int
    | AddStep
    | RemoveStep Int
        
update : Msg -> Model -> Model
update msg model =
     case msg of
         SelectPE step i ->
             case String.toInt i of
                 Just j -> 
                     { model | pe_list =
                           List.indexedMap
                               (\step_ pe -> if step == step_ then { pe | index = j } else pe)
                               model.pe_list
                     }
                     
                 Nothing -> model
                            
         FlipRW i ->
             let flip pe = case pe.op of
                               Read -> { pe | op = Write }
                               Write -> { pe | op = Read }
             in
                 { model |
                   pe_list =
                       List.indexedMap
                           (\j pe -> if i == j then flip pe else pe)
                           model.pe_list
                 }
                 
         AddPE ->
             { model | pe_n = model.pe_n + 1 }

         RemovePE i ->
             if model.pe_n <= 1 || i < 0 || model.pe_n <= i then model
             else
                 { model |
                   pe_n = model.pe_n - 1
                 , pe_list = List.map
                             (\pe -> if pe.index < i then pe
                                     else if pe.index == i then { pe | index = 0 }
                                          else { pe | index = pe.index - 1 }
                             )
                             model.pe_list
                 }                  

         AddStep ->
             { model | pe_list = model.pe_list ++ [ { op = Read, index = 0 } ] }

         RemoveStep i ->
             let indexedFilter f =
                     let indexedFilter_ j list = 
                             case list of
                                 [] -> []
                                 h :: t -> if f j then h :: indexedFilter_ (j + 1) t
                                           else indexedFilter_ (j + 1) t
                     in indexedFilter_ 0
             in
                 { model | pe_list = indexedFilter (\j -> i /= j) model.pe_list }
    
-- View
view : Model -> Html Msg
view model =
    div []
        [ model |> peListToLL |> moesiListListtoTable
        ]

type MOESI
    = M | O | E | S | I

createList : Int -> (Int -> a) -> List a
createList n fun =
    let createList_ i =
            if i < n then fun i :: createList_ (i + 1)
            else []
    in createList_ 0
             
peStateToRow :
    Int -> PE -> (List MOESI, MOESI, Int) -> (List MOESI, MOESI, Int)

peStateToRow pe_n pe (prev_row, prev_state, prev_i) =
    case pe.op of
        Write -> (createList
                      pe_n
                      (\i -> if i == pe.index then M
                            else I
                      )
                 , M, pe.index)
                 
        Read ->
            case prev_state of
                I -> (createList
                          pe_n
                          (\i -> if i == pe.index then E
                                else I
                          )
                     , E, pe.index)
                
                M -> 
                    if pe.index == prev_i then (prev_row, M, prev_i)
                    else 
                        (List.indexedMap
                            (\i s -> if i == pe.index then S
                                     else if i == prev_i then O
                                          else s
                            )
                             prev_row
                        , O, pe.index)
                        
                O -> (List.indexedMap
                          (\i s -> if i == pe.index && s /= O then S
                                  else s
                          )
                          prev_row
                        , O, pe.index)

                _ ->
                    if prev_state == E && pe.index == prev_i then (prev_row, E, prev_i)
                    else 
                        (List.indexedMap
                            (\i s -> if i == pe.index || s == E then S
                                    else s
                            )
                            prev_row
                        , S, pe.index)

                        
peListToLL_ : Int -> List PE -> (List MOESI, MOESI, Int) -> List (List MOESI, PE)

peListToLL_ pe_n pe_list prev =
    case pe_list of
        [] -> []
        h :: t -> let (row, state, i) = peStateToRow pe_n h prev in
                  (row, h) :: peListToLL_ pe_n t (row, state, i)

                      
peListToLL : Model -> (List (List MOESI, PE), Int)

peListToLL model =
    let init_row = List.repeat model.pe_n I in
    ((init_row, { op = Read, index = 0 })
     :: peListToLL_ model.pe_n model.pe_list (init_row, I, 0), model.pe_n)

css path =
    node "link" [ rel "stylesheet", href path ] []
        
moesiListListtoTable : (List (List MOESI, PE), Int) -> Html Msg

moesiListListtoTable (moesi_list_list, pe_n) =
    table [ class "emulator" ] [ tbody [] <|
                   ( tr [] <|
                         th [] [] ::
                         (List.map
                              (\i -> th [] [ text <| "PE" ++ String.fromInt i] )
                              (List.range 0 (pe_n - 1))
                         ) ++ [ th [ class "append" ] [ button [ onClick AddPE ] [ text "+" ] ] ]
                   ) ::
                   (List.indexedMap (\row_i (row, pe) ->
                                  tr [] <|
                                         let peTd = td [] [
                                                     select [ onInput <| SelectPE (row_i - 1) ]
                                                         (List.range 0 (pe_n - 1)
                                                         |> List.map (intToOption pe.index)
                                                         )
                                                    , button
                                                         [ class <| case pe.op of
                                                                       Read -> "read"
                                                                       Write -> "write"
                                                          , onClick <| FlipRW (row_i - 1) ]
                                                         [ text <| case pe.op of
                                                                       Read -> "Read"
                                                                       Write -> "Write"
                                                         ]
                                                    ] in
                                         let steps = 
                                                 List.map
                                                     (\x ->
                                                          let str = case x of
                                                                        M -> "M"
                                                                        O -> "O"
                                                                        E -> "E"
                                                                        S -> "S"
                                                                        I -> "I"
                                                          in
                                                              td [] [ text str ]
                                                     ) row
                                         in
                                             if 0 < row_i then
                                                 peTd :: steps ++ [ td [ class "close" ] [ button [ onClick <| RemoveStep (row_i - 1)] [ text "x" ] ] ]
                                             else
                                                 (td [] [ text "init" ]) :: steps 
                                    ) moesi_list_list
                   ) ++ [ tr [] ( td [ class "append" ] [ button [ onClick AddStep ] [ text "+" ] ] :: (
                                 List.range 0 (pe_n - 1) |>
                                      List.map (\i -> td [ class "close" ] [
                                                       button [ onClick <| RemovePE i] [ text "x" ]
                                                      ]
                                               )
                                     )
                                )
                                
                        ]
             ]




intToOption : Int -> Int ->  Html Msg
intToOption i v =
  option [ selected <| i == v, value (String.fromInt v) ] [ text ("PE " ++ String.fromInt v) ]
