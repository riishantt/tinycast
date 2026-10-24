# Image Viewer

A photo opened from Finder, or from Search Files, shows in a borderless Tinycast panel instead of
Preview. The panel opens centred on the display under the pointer, sized to the photo's shape, and
offers only the basics: zoom, and Move to Trash.

## Invariants

- **Tinycast is an `Alternate` image handler, never the default by itself.** `Info.plist` claims
  `public.image` with `LSHandlerRank` `Alternate`, so it appears under Open With and the user makes it
  the default (Get Info › Open With › Change All). Installing a build changes no one's default viewer.
- **Every file URL Launch Services hands over is a photo.** `AppCore.handleOpenURL` sends a file URL
  to `ImageViewerCoordinator.open` before any deep-link routing, which is only safe while images are
  the one document type `Info.plist` claims.
- **The window fits the photo; the photo never upscales to fit the window.** `ImageViewerFitPolicy`
  scales a photo down to at most 90% of the visible frame and shows a smaller one at actual size,
  with a 320×220pt floor so an icon still gets a window. Actual size is points at the photo's own DPI,
  so a 144-DPI Retina screenshot is half its pixels, as in Preview.
- **Decoding is off main and bounded by the display.** `ImageViewerPhoto` decodes with ImageIO in
  `Task.detached`, applying EXIF orientation, at no more than twice the display's long edge in pixels.
  That keeps a 48 MP photo from costing ~190 MB; past a 2× zoom of a full-screen fit, it softens.
  Only a multi-frame GIF loads as an `NSImage` from the file, so `NSImageView` can animate it.
- **Closing works as it does for the palette.** Esc, Space, ⌘W and losing key all close: a click on
  another app or the desktop takes key away. Everything goes through `ImageViewerCoordinator.close()`,
  which drops the panel and with it the decoded bitmap.
- **Move to Trash does not ask.** ⌘⌫ trashes the file off main and closes, as Finder and Preview do;
  the Trash is the undo. A failure is a `DialogController` notice, worded as Search Files words it.

## How it is put together

| Piece | Holds |
| --- | --- |
| `Model/ImageViewerFitPolicy.swift` | window size, point size from DPI, the zoom steps, the decode size |
| `Service/ImageViewerPhoto.swift` | the off-main ImageIO decode and its point size |
| `UI/ImageViewerCoordinator.swift` | one panel at a time, the stale-load check, Move to Trash |
| `UI/ImageViewerPanel.swift` | the borderless key panel: the chords and close-on-resign-key |
| `UI/ImageViewerCanvas.swift` | the magnifying `NSScrollView`: centring, double-click, drag to pan |
| `UI/ImageViewerView.swift` | the palette's glass and scrim behind the canvas |

Pinch and two-finger scrolling are AppKit's own, through `allowsMagnification`. ⌘+ and ⌘− (and a
bare `=` and `-`) step by 1.25× between the fit and 8×, ⌘0 is actual size, ⌘9 is the fit, and a
double-click toggles between the fit and actual size. At the fit, a drag moves the window; once
zoomed, it pans the photo.

A second photo opened while one is up replaces it in the same panel. A load still decoding when
another starts, or when the viewer closes, is cancelled and never presented.

Search Files reaches the viewer without any code of its own: opening an image there goes through
`NSWorkspace`, which hands it back to Tinycast once Tinycast is the default for that type.
