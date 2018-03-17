module Elm exposing (Module(..), Function(..), Arg(..), Expr(..), renderElmModule)


type Module
    = Module String (List Function)


type Function
    = Function String (List Arg) String Expr


type Arg
    = Primitive String String
    | Record (List ( String, String ))


type Expr
    = Ifs (List Expr)
    | If ( Expr, Expr )
    | Expr String


renderElmModule : Module -> String
renderElmModule (Module name body) =
    let
        renderedBody =
            List.map renderElmFunction body
    in
        (("module " ++ name ++ " exposing (..)") :: renderedBody)
            |> String.join "\n\n\n"


renderElmFunction : Function -> String
renderElmFunction (Function name args returnType body) =
    let
        renderedArgs =
            ((List.map renderElmType args) ++ [ returnType ])
                |> String.join " -> "

        annotation =
            name ++ " : " ++ renderedArgs

        definition =
            (name :: (List.map renderElmParam args) ++ [ "=" ])
                |> String.join " "
    in
        [ annotation, definition, indent (renderElmExpr body) ]
            |> String.join "\n"


renderElmType : Arg -> String
renderElmType arg =
    case arg of
        Primitive typeName _ ->
            typeName

        Record types ->
            let
                renderTypes =
                    List.map
                        (\( typeName, argName ) ->
                            argName ++ " : " ++ typeName
                        )
                        >> String.join ", "
            in
                "{ " ++ renderTypes types ++ " }"


renderElmParam : Arg -> String
renderElmParam arg =
    case arg of
        Primitive _ param ->
            param

        Record types ->
            let
                renderParams =
                    List.map Tuple.second
                        >> String.join ", "
            in
                "{ " ++ renderParams types ++ " }"


renderElmExpr : Expr -> String
renderElmExpr expr =
    case expr of
        Expr body ->
            body

        Ifs alternatives ->
            let
                renderedAlternatives =
                    alternatives
                        |> List.map renderElmExpr
            in
                [ "if False then\n"
                    ++ (indent "\"\"")
                ]
                    ++ renderedAlternatives
                    ++ [ "else\n" ++ (indent "\"\"") ]
                    |> String.join "\n"

        If ( condition, expression ) ->
            "else if "
                ++ (renderElmExpr condition)
                ++ " then\n"
                ++ (indent (renderElmExpr expression))


indent : String -> String
indent lines =
    String.lines lines
        |> List.map
            (\l ->
                if String.length l > 0 then
                    "    " ++ l
                else
                    ""
            )
        |> String.join "\n"
