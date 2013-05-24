
module Ivory.Tower.Graphviz
  ( graphvizDoc
  , graphvizToFile
  ) where

import Ivory.Tower.Types
import Ivory.Tower.Channel (channelNameForEndpoint)

import System.IO
import Text.PrettyPrint.Leijen

import Data.List (nubBy,find,(\\))
import Data.Maybe (catMaybes)

-- | Write a Tower 'Assembly' to a dot file
graphvizToFile :: FilePath -> Assembly -> IO ()
graphvizToFile f asm = withFile f WriteMode $ \h -> displayIO h rendered
  where
  w = 1000000 -- don't wrap lines - dot doesnt handle multiline strings
  rendered = renderPretty 1.0 w $ graphvizDoc asm

-- | Render a Tower 'Assembly' as a 'Text.PrettyPrint.Leijen.Doc'
graphvizDoc :: Assembly -> Doc
graphvizDoc a = vsep $
  [ text "digraph {"
  , indent 4 body
  , text "}"
  ]
  where
  body = annotations <$> vsep task_ns
                     <$> vsep dpNodes
                     <$> vsep chNodes
                     <$> vsep es
  annotations = text "graph [rankdir=LR];"
            <$> text "node [shape=record];"
  ts = asm_tasks a
  task_ns = map taskNode ts
  dataports = uniqueDataports ts
  dpNodes = map dataportNode dataports
  chNodes = map channelNode ((asm_channels a) \\ dataports)
  es      = concatMap (channelEdge (asm_channels a)) (pairedEdges ts)

-- Assembly processing ---------------------------------------------------------

pairedEdges :: [TaskResult] -> [(TaskResult, TaggedChannel)]
pairedEdges ts = [ (t, c) | t <- ts, c <- taskres_taggedchs t ]

-- list of dataport records, ignoring the impl field
-- invariant: dataports created with unique freshnames (enforced by monad)
compiledChannelEq :: CompiledChannel -> CompiledChannel -> Bool
compiledChannelEq a b = (cch_name a) == (cch_name b)

uniqueDataports :: [TaskResult] -> [CompiledChannel]
uniqueDataports ts = nubBy compiledChannelEq $ concatMap selectDataports ts
  where
  selectDataports :: TaskResult-> [CompiledChannel]
  selectDataports tsk = catMaybes (map aux (taskres_taggedchs tsk))
    where
    aux (TagDataWriter _ cc) = Just cc
    aux (TagDataReader _ cc) = Just cc
    aux _ = Nothing


-- Task Node -------------------------------------------------------------------
taskNode :: TaskResult -> Doc
taskNode t =
  name <+> brackets (text "label=" <> dquotes contents) <> semi
  where
  name = text $ taskres_name t
  contents = hcat $ punctuate (text "|") fields
  fields = [ name <+> text ":: task" ]
        ++ prior ++ ssize
        ++ map periodic_field (taskres_periodic t)
        ++ map taggedch_field (taskres_taggedchs t)

  periodic_field p = text ("periodic @ " ++ (show p) ++ "ms")

  prior = case taskres_priority t of
    Just p -> [ text ("priority " ++ (show p)) ]
    Nothing -> []

  ssize = case taskres_stacksize t of
    Just s -> [ text ("stack size " ++ (show s)) ]
    Nothing -> []

  taggedch_field :: TaggedChannel -> Doc
  taggedch_field ch = angles (n ch) <+> (descr ch)
    where
    n (TagChannelEmitter  _ utr) = text (unUTChannelRef utr)
    n (TagChannelReceiver _ utr) = text (compiledChannelName
                                          (channelNameForEndpoint utr (taskres_schedule t)))
    n (TagDataReader _ cc) = text (compiledChannelName (cch_name cc))
    n (TagDataWriter _ cc) = text (compiledChannelName (cch_name cc))
    descr (TagChannelEmitter  d _) = text d <+> text "emitter"
    descr (TagChannelReceiver d _) = text d <+> text "receiver"
    descr (TagDataReader      d _) = text d <+> text "reader"
    descr (TagDataWriter      d _) = text d <+> text "writer"

-- Dataport, Channel Nodes -----------------------------------------------------

-- DataPortRecord represents just the name and type of a dataport
dataportNode :: CompiledChannel -> Doc
dataportNode d =
  name <+> brackets (text "label=" <> dquotes contents) <> semi
  where
  contents = title <+> text ("|{<source>Source|<sink>Sink}")
  name = text (compiledChannelName (cch_name d))
  title = text "DataPort ::"
             <+> escapeQuotes (drop 2 (cch_type d)) -- drop Ty prefix

-- ChannelRecord represents just the name and type of a channel
channelNode :: CompiledChannel -> Doc
channelNode c =
  name <+> brackets (text "label=" <> dquotes contents) <> semi
  where
  contents = title <+> text ("|{<source>Source|<sink>Sink}")
  name = text (compiledChannelName (cch_name c))
  title = text "Channel ::"
             <+> escapeQuotes (drop 2 (cch_type c)) -- drop Ty prefix

-- Edges -----------------------------------------------------------------------

channelEdge :: [CompiledChannel] -> (TaskResult, TaggedChannel) -> [Doc]
channelEdge cs (t,c) = map arrow edges
  where
  arrow (a,b) = a <+> text "->" <+> b <+> semi
  edges = case c of
    TagChannelEmitter  _ utref -> map chansrc (fanoutcchs utref) -- XXX fan out!
    TagChannelReceiver _ utref -> [datasink (findcch utref t)]
    TagDataWriter      _ cch   -> [datasrc cch]
    TagDataReader      _ cch   -> [datasink cch]
  -- data uses simple fully qualified names
  datasrc cch = ( qual (taskres_name t) n, qual n "source" )
    where n = compiledChannelName (cch_name cch)
  datasink cch = ( qual n "sink", qual (taskres_name t) n)
    where n = compiledChannelName (cch_name cch)

  -- channels use the ref name at the task and the fully qualified name at the
  -- connector, because source tasks don't know all of the endpoints at creation
  -- time.
  chansink cch = ( qual fullname "sink", qual (taskres_name t) (chanrefname cch))
    where fullname = compiledChannelName (cch_name cch)
  chansrc cch = ( qual (taskres_name t) (chanrefname cch), qual fullname "source" )
    where fullname = compiledChannelName (cch_name cch)
  chanrefname cch = case cch_name cch of
        ChannelName r _ -> unUTChannelRef r
        _ -> error ("impossible - dataport name should not be in " ++
                    "graphviz channel tagged edge")

  -- Find the compiled channel
  findcch :: UTChannelRef -> TaskResult -> CompiledChannel
  findcch ref taskres = maybe (error "impossible") id $ find aux cs
    where
    aux cch = (cch_name cch) ==
      (channelNameForEndpoint ref (taskres_schedule taskres))
  -- Find all compiled channels which are formed from this ref.
  fanoutcchs :: UTChannelRef -> [CompiledChannel]
  fanoutcchs ref = filter aux cs
    where
    aux cch = case cch_name cch of
       (ChannelName r _) -> r == ref
       _ -> False

-- Utility functions -----------------------------------------------------------

escapeQuotes :: String -> Doc
escapeQuotes x = text $ aux x -- I know this is probably terrible (pch)
  where
  aux ('"':ss) = '\\' : '"' : (aux ss)
  aux  (s:ss)  = s : (aux ss)
  aux [] = []

qual :: String -> String -> Doc
qual prefix name = text prefix <> colon <> text name