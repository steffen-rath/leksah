--
-- | Module for saving, restoring and editing preferences
-- 

module Ghf.Preferences (
    readPrefs
,   writePrefs
--,   applyPrefs
,   editPrefs

,   prefsDescription
) where

import Text.ParserCombinators.Parsec hiding (Parser)
import qualified Text.ParserCombinators.Parsec.Token as P
import Text.ParserCombinators.Parsec.Language(emptyDef)
import qualified Text.PrettyPrint.HughesPJ as PP
import Control.Monad(foldM)
import Graphics.UI.Gtk hiding (afterToggleOverwrite,Focus)
import Graphics.UI.Gtk.SourceView
import Control.Monad.Reader
import Data.Maybe(isJust)
import qualified Data.Map as Map
import Data.Map(Map,(!))
import Data.IORef

import Debug.Trace

import Ghf.Core
import Ghf.Editor
import Ghf.View
import Ghf.Keymap
import Ghf.Menu(actions,makeMenu,menuDescription)


defaultPrefs = Prefs {
        showLineNumbers     =   True
    ,   rightMargin         =   Just 100
    ,   tabWidth            =   4
    ,   sourceCandy         =  Just("Default")
    ,   keymapName          =  "Default" 
    ,   defaultSize         =  (1024,800)}

type Comment            =   String
type Name               =   String

data FieldDescription alpha =  FD {
        name                ::  Name
    ,   comment             ::  Comment
    ,   fieldPrinter        ::  alpha -> PP.Doc
    ,   fieldParser         ::  alpha -> CharParser () alpha
    ,   fieldEditor         ::  IORef alpha -> IO (Widget, alpha -> IO(), alpha -> IO(alpha))
    ,   fieldApplicator     ::  alpha -> alpha -> GhfAction
}

type Getter alpha beta  =   alpha -> beta
type Setter alpha beta  =   beta -> alpha -> alpha
type Printer beta       =   beta -> PP.Doc
type Parser beta        =   CharParser () beta

data EditorEvent        =   Changed | Focus
    deriving (Eq,Ord,Show,Enum)

type Injector beta      =   beta -> IO()
type Extractor beta     =   IO(beta)
type Notifier beta      =   IO () -> IO ()
type EditorRes beta     =   (Widget, Injector beta, Extractor beta,
                                Map EditorEvent (Notifier beta))
type Editor beta        =   Name -> IO(EditorRes beta)
type Applicator beta    =   beta -> GhfAction

type MkFieldDescription alpha beta =
              String ->                         --name
              String ->                         --comment
              (Printer beta) ->                
              (Parser beta) ->
              (Getter alpha beta) ->            
              (Setter alpha beta) ->            
              (Editor beta) ->
              (Applicator beta) ->
              FieldDescription alpha

field :: Eq beta => MkFieldDescription alpha beta
field name comment printer parser getter setter editor applicator =
    FD  name 
        comment
        (\ dat -> (PP.text name PP.<> PP.colon)
                PP.$$ (PP.nest 15 (printer (getter dat)))
                PP.$$ (PP.nest 5 (if null comment 
                                        then PP.empty 
                                        else PP.text $"--" ++ comment)))
        (\ dat -> try (do
            symbol name
            colon
            val <- parser
            return (setter val dat)))
        (\ refDat -> do
            dat <- readIORef refDat
            (widget, inj,ext,noti) <- editor name
            inj (getter dat)
            (noti ! Changed) (do
                 putStrLn "changed"
                 oldDat <- readIORef refDat
                 newState <- ext
                 let newDat = setter newState oldDat
                 --inj (getter newDat)
                 writeIORef refDat newDat
                 return ())
            return (widget,
                    (\a -> inj (getter a)), 
                    (\a -> do {b <- ext; return (setter b a)})))
        (\ newDat oldDat -> do
            let newField = getter newDat
            let oldField = getter oldDat
            if newField == oldField
                then return ()
                else applicator newField)

prefsDescription :: [FieldDescription Prefs]
prefsDescription = [
        field "Show line numbers"
            "(True/False)" 
            (PP.text . show)
            boolParser
            showLineNumbers
            (\ b a -> a{showLineNumbers = b})
            boolEditor
            (\b -> do
                buffers <- allBuffers
                mapM_ (\buf -> lift$sourceViewSetShowLineNumbers (sourceView buf) b) buffers)
    ,   field "Right margin"
            "Size or 0 for no right margin"
            (\a -> (PP.text . show) (case a of Nothing -> 0; Just i -> i))
            (do i <- intParser
                return (if i == 0 then Nothing else Just i))
            rightMargin
            (\b a -> a{rightMargin = b})
            (maybeEditor (intEditor 0.0 200.0 5.0))
            (\b -> do
                buffers <- allBuffers
                mapM_ (\buf -> case b of
                                Just n -> do
                                    lift $sourceViewSetMargin (sourceView buf) n
                                    lift $sourceViewSetShowMargin (sourceView buf) True
                                Nothing -> lift $sourceViewSetShowMargin (sourceView buf) False)
                                                buffers)
    ,   field "Tab width" ""
            (PP.text . show)
            intParser
            tabWidth
            (\b a -> a{tabWidth = b})
            (intEditor 0.0 20.0 1.0)
            (\i -> do
                buffers <- allBuffers
                mapM_ (\buf -> lift $sourceViewSetTabsWidth (sourceView buf) i) buffers)
    ,   field "Source candy"
                "Empty for do not use or the name of a candy file in a config dir)"
            (\a -> PP.text (case a of Nothing -> ""; Just s -> s)) 
            (do id <- identifier
                return (if null id then Nothing else Just (id)))
            sourceCandy (\b a -> a{sourceCandy = b})
            (maybeEditor stringEditor)
            (\cs -> case cs of
                        Nothing -> do 
                            setCandyState False
                            editCandy
                        Just name -> do
                            setCandyState True
                            editCandy)
    ,   field "Name of the keymap"  "The name of a keymap file in a config dir"
            PP.text
            identifier
            keymapName
            (\b a -> a{keymapName = b})
            stringEditor
            (\ a -> return ())
    ,   field "Window default size"
            "Default size of the main ghf window specified as pair (int,int)" 
            (PP.text.show) 
            (pairParser intParser)
            defaultSize (\(c,d) a -> a{defaultSize = (c,d)})
            (pairEditor (intEditor 0.0 3000.0 25.0)(intEditor 0.0 3000.0 25.0))
            (\a -> return ()) ]


-- ------------------------------------------------------------
-- * Parsing
-- ------------------------------------------------------------

readPrefs :: FileName -> IO Prefs
readPrefs fn = do
    res <- parseFromFile (prefsParser defaultPrefs prefsDescription) fn
    case res of
        Left pe -> error $"Error reading prefs file " ++ show fn ++ " " ++ show pe
        Right r -> return r  

prefsStyle  :: P.LanguageDef st
prefsStyle  = emptyDef                      
                { P.commentStart   = "{-"
                , P.commentEnd     = "-}"
                , P.commentLine    = "--"
                }      

lexer = P.makeTokenParser prefsStyle
lexeme = P.lexeme lexer
whiteSpace = P.whiteSpace lexer
hexadecimal = P.hexadecimal lexer
symbol = P.symbol lexer
identifier = P.identifier lexer
colon = P.colon lexer
integer = P.integer lexer

prefsParser :: Prefs -> [FieldDescription Prefs] -> CharParser () Prefs
prefsParser def descriptions = 
    let parsersF = map fieldParser descriptions in do     
        whiteSpace
        res <- applyFieldParsers def parsersF
        return res
        <?> "prefs parser" 

applyFieldParsers :: Prefs -> [Prefs -> CharParser () (Prefs)] -> CharParser () Prefs
applyFieldParsers prefs parseF = do
    let parsers = map (\a -> a prefs) parseF
    newprefs <- choice parsers
    whiteSpace
    applyFieldParsers newprefs parseF
    <|> do
    eof
    return (prefs)
    <?> "field parser"

boolParser :: CharParser () Bool
boolParser = do
    (symbol "True" <|> symbol "true")
    return True
    <|> do
    (symbol "False"<|> symbol "false")
    return False
    <?> "bool parser"

pairParser :: CharParser () alpha -> CharParser () (alpha,alpha) 
pairParser p2 = do
    char '('    
    v1 <- p2
    char ','
    v2 <- p2
    char ')'
    return (v1,v2)
    <?> "pair parser"

intParser :: CharParser () Int
intParser = do
    i <- integer
    return (fromIntegral i)

-- ------------------------------------------------------------
-- * Printing
-- ------------------------------------------------------------

writePrefs :: FilePath -> Prefs -> IO ()
writePrefs fpath prefs = writeFile fpath (showPrefs prefs prefsDescription)

showPrefs :: a -> [FieldDescription a] -> String
showPrefs prefs prefsDesc = PP.render $
    foldl (\ doc (FD _ _ printer _ _ _) -> doc PP.$+$ printer prefs) PP.empty prefsDesc 

-- ------------------------------------------------------------
-- * Editing
-- ------------------------------------------------------------

editPrefs :: GhfAction
editPrefs = do
    ghfR <- ask
    p <- readGhf prefs
    res <- lift $editPrefs' p prefsDescription ghfR
    lift $putStrLn $show res

editPrefs' :: Prefs -> [FieldDescription Prefs] -> GhfRef -> IO ()
editPrefs' prefs prefsDesc ghfR = do
    prefsRef   <- newIORef prefs
    lastAppliedPrefsRef <- newIORef prefs
    dialog  <- windowNew
    vb      <- vBoxNew False 12
    bb      <- hButtonBoxNew
    apply   <- buttonNewFromStock "gtk-apply"
    restore <- buttonNewFromStock "gtk-restore"
    ok      <- buttonNewFromStock "gtk-ok"
    cancel  <- buttonNewFromStock "gtk-cancel"
    boxPackStart bb apply PackNatural 0
    boxPackStart bb restore PackNatural 0
    boxPackStart bb ok PackNatural 0
    boxPackStart bb cancel PackNatural 0
    resList <- mapM (\ (FD _ _ _ _ editorF _) -> editorF prefsRef) prefsDesc
    let widgets =   map (\ (widget,_,_) -> widget) resList
    let setInjs =   map (\ (_,setInj,_) -> setInj) resList 
    let getExts =   map (\ (_,_,getExt) -> getExt) resList 
    mapM_ (\ sb -> boxPackStart vb sb PackNatural 12) widgets
    ok `onClicked` (do
        newPrefs <- readIORef prefsRef
        lastAppliedPrefs <- readIORef lastAppliedPrefsRef
        mapM_ (\ (FD _ _ _ _ _ applyF) -> runReaderT (applyF newPrefs lastAppliedPrefs) ghfR) prefsDesc
        writePrefs "config/Default.prefs" newPrefs
        runReaderT (modifyGhf_ (\ghf -> return (ghf{prefs = newPrefs}))) ghfR
        widgetDestroy dialog)
    apply `onClicked` (do
        newPrefs <- readIORef prefsRef
        lastAppliedPrefs <- readIORef lastAppliedPrefsRef
        mapM_ (\ (FD _ _ _ _ _ applyF) -> runReaderT (applyF newPrefs lastAppliedPrefs) ghfR) prefsDesc
        writeIORef lastAppliedPrefsRef newPrefs)
    restore `onClicked` (do
        lastAppliedPrefs <- readIORef lastAppliedPrefsRef
        mapM_ (\ (FD _ _ _ _ _ applyF) -> runReaderT (applyF prefs lastAppliedPrefs) ghfR) prefsDesc
        mapM_ (\ setInj -> setInj prefs) setInjs
        writeIORef lastAppliedPrefsRef prefs)
    cancel `onClicked` (do
        lastAppliedPrefs <- readIORef lastAppliedPrefsRef
        mapM_ (\ (FD _ _ _ _ _ applyF) -> runReaderT (applyF prefs lastAppliedPrefs) ghfR) prefsDesc
        widgetDestroy dialog)
    boxPackStart vb bb PackNatural 0
    containerAdd dialog vb
    widgetShowAll dialog    
    return ()

boolEditor :: Editor Bool
boolEditor label = do
    frame   <-  frameNew
    frameSetShadowType frame ShadowNone
    button   <-  checkButtonNewWithLabel label
    containerAdd frame button
    let injector = toggleButtonSetActive button
    let extractor = toggleButtonGetActive button
    let changeNotifier f = do button `onClicked` f; return ()
    let focusNotifier f = do
        button `onFocusIn` (\ _ -> do f; return False)
        return ()
    let notifiers = Map.fromList [(Changed,changeNotifier),(Focus,focusNotifier)]
    return ((castToWidget) frame, injector, extractor, notifiers)

stringEditor :: Editor String
stringEditor label = do
    frame   <-  frameNew
    frameSetShadowType frame ShadowNone
    frameSetLabel frame label
    entry   <-  entryNew
    containerAdd frame entry
    let injector = entrySetText entry
    let extractor = entryGetText entry
    let changeNotifier f =  do
        entry `onFocusOut` (\ _ -> do f; return False)
        return ()
    let focusNotifier f = do
        entry `onFocusIn` (\ _ -> do f; return False)
        return ()
    let notifiers = Map.fromList [(Changed,changeNotifier),(Focus,focusNotifier)]
    return ((castToWidget) frame, injector, extractor, notifiers)

intEditor :: Double -> Double -> Double -> Editor Int
intEditor min max step label = do
    frame   <-  frameNew
    frameSetShadowType frame ShadowNone
    frameSetLabel frame label
    spin <- spinButtonNewWithRange min max step
    containerAdd frame spin
    let injector = (\v -> spinButtonSetValue spin (fromIntegral v))
    let extractor = (do
        newNum <- spinButtonGetValue spin
        return (truncate newNum))
    let changeNotifier f =  do
        spin `onFocusOut` (\ e -> do f; return False)
        return ()
    let focusNotifier f = do
        spin `onFocusIn` (\ _ -> do f; return False)
        return ()
    let notifiers = Map.fromList [(Changed,changeNotifier),(Focus,focusNotifier)]
    return ((castToWidget) frame, injector, extractor, notifiers)

maybeEditor :: Editor beta -> Editor (Maybe beta)
maybeEditor childEditor label = do
    frame   <-  frameNew
    frameSetLabel frame label
    (boolFrame,inj1,ext1,not1) <- boolEditor  ""
    (justFrame,inj2,ext2,not2) <- childEditor ""
    let injector = (\v -> case v of
                            Nothing -> do
                              widgetSetSensitivity justFrame False
                              inj1 False
                            Just v  -> do
                              widgetSetSensitivity justFrame True
                              inj1 True 
                              inj2 v)
    let extractor = do
        bool <- ext1
        if bool
            then do
                value <- ext2
                return (Just value)
            else 
                return Nothing
    vBox <- vBoxNew False 1
    boxPackStart vBox boolFrame PackNatural 0
    boxPackStart vBox justFrame PackNatural 0
    containerAdd frame vBox    
    let changeNotifier f = do (not1 ! Changed)  f; (not2 ! Changed) f
    let focusNotifier f = do (not1 ! Focus) f; (not2 ! Focus) f
    (not1 ! Changed)
        (do bool <- ext1
            widgetSetSensitivity justFrame bool)
    let notifiers = Map.fromList [(Changed,changeNotifier),(Focus,focusNotifier)]
    return ((castToWidget) frame, injector, extractor, notifiers)

pairEditor :: Editor alpha -> Editor beta -> Editor (alpha,beta)
pairEditor fstEd sndEd label = do
    frame   <-  frameNew
    frameSetLabel frame label
    (fstFrame,inj1,ext1,not1) <- fstEd ""
    (sndFrame,inj2,ext2,not2) <- sndEd ""
    hBox <- hBoxNew False 1
    boxPackStart hBox fstFrame PackGrow 0
    boxPackStart hBox sndFrame PackGrow 0
    containerAdd frame hBox
    let injector = (\(f,s) -> do inj1 f; inj2 s)
    let extractor = do
        f <- ext1
        s <- ext2
        return (f,s)
    let changeNotifier f = do (not1 ! Changed)  f; (not2 ! Changed) f
    let focusNotifier f = do (not1 ! Focus) f; (not2 ! Focus) f
    let notifiers = Map.fromList [(Changed,changeNotifier),(Focus,focusNotifier)]
    return ((castToWidget) frame, injector, extractor, notifiers)

genericEditor :: (Show beta, Read beta) => Editor beta
genericEditor label = do
    frame   <-  frameNew
    frameSetShadowType frame ShadowNone
    frameSetLabel frame label
    entry   <-  entryNew
    containerAdd frame entry
    let injector = (\t -> entrySetText entry (show t))
    let extractor = do r <- entryGetText entry; return (read r)
    let changeNotifier f =  do
        entry `onFocusOut` (\ _ -> do f; return False)
        return ()
    let focusNotifier f = do
        entry `onFocusIn` (\ _ -> do f; return False)
        return ()
    let notifiers = Map.fromList [(Changed,changeNotifier),(Focus,focusNotifier)]
    return ((castToWidget) frame, injector, extractor, notifiers)
