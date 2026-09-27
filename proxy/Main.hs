-----------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
-----------------------------------------------------------------------------
-- |
-- A tiny native (non-wasm) CORS proxy in front of api.adsb.lol.
--
-- adsb.lol has real, free, live global aircraft data - but sends no CORS
-- headers, so the browser blocks a direct @fetch@ from our page. This
-- proxy fetches server-side (not subject to CORS at all) and re-serves
-- the JSON body with @Access-Control-Allow-Origin: *@ added.
--
-- Run it (from the project's __default__ devShell, not @.#wasm@ - this is
-- an ordinary native executable, not part of the wasm app):
--
-- > nix develop --command cabal run adsb-proxy
--
-- Then, alongside @make serve@: @GET http:\/\/localhost:8790\/flights?lat=..&lon=..&radius=..@.
-----------------------------------------------------------------------------
module Main (main) where
-----------------------------------------------------------------------------
import Control.Exception (SomeException, try)
import Control.Monad (join)
import qualified Data.ByteString.Char8 as BC
import qualified Data.ByteString.Lazy as LBS
import qualified Network.HTTP.Client as HTTP
import qualified Network.HTTP.Client.TLS as HTTP
import Network.HTTP.Types (Status, hContentType, status200, status400, status502)
import qualified Network.Wai as Wai
import Network.Wai.Handler.Warp (run)
-----------------------------------------------------------------------------
port :: Int
port = 8790
-----------------------------------------------------------------------------
main :: IO ()
main = do
  manager <- HTTP.newManager HTTP.tlsManagerSettings
  putStrLn ("adsb-proxy: forwarding api.adsb.lol, listening on http://localhost:" ++ show port)
  run port (app manager)
-----------------------------------------------------------------------------
app :: HTTP.Manager -> Wai.Application
app manager req respond =
  case (Wai.rawPathInfo req, param "lat", param "lon", param "radius") of
    ("/flights", Just lat, Just lon, radius) -> do
      result <- fetchFlights manager lat lon (maybe "250" id radius)
      respond $ case result of
        Right body -> jsonResponse status200 body
        Left err   -> jsonResponse status502 (LBS.fromStrict (BC.pack err))
    _ -> respond (jsonResponse status400
           "{\"error\":\"usage: /flights?lat=..&lon=..&radius=.. (radius in nm, default 250)\"}")
  where
    qs = Wai.queryString req
    param name = join (lookup name qs)
-----------------------------------------------------------------------------
fetchFlights :: HTTP.Manager -> BC.ByteString -> BC.ByteString -> BC.ByteString -> IO (Either String LBS.ByteString)
fetchFlights manager lat lon radius = do
  let url = "https://api.adsb.lol/v2/point/" ++ BC.unpack lat ++ "/" ++ BC.unpack lon ++ "/" ++ BC.unpack radius
  parsed <- try (HTTP.parseRequest url) :: IO (Either SomeException HTTP.Request)
  case parsed of
    Left e -> pure (Left (show e))
    Right baseReq -> do
      let req = baseReq
            { HTTP.requestHeaders = [("User-Agent", "miso-cesium-demo (github.com/chandler-barlow/cesium-hs)")] }
      resp <- try (HTTP.httpLbs req manager) :: IO (Either SomeException (HTTP.Response LBS.ByteString))
      pure (either (Left . show) (Right . HTTP.responseBody) resp)
-----------------------------------------------------------------------------
jsonResponse :: Status -> LBS.ByteString -> Wai.Response
jsonResponse status body =
  Wai.responseLBS status
    [ (hContentType, "application/json")
    , ("Access-Control-Allow-Origin", "*")
    ]
    body
-----------------------------------------------------------------------------
