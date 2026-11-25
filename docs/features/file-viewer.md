# File Viewer

A photo or document opened from Finder, or from Search Files, shows in a borderless Tinycast panel
instead of Preview, TextEdit or an office suite. The panel opens centred on the display under the
pointer and offers only the basics: zoom, Open in another app, and Move to Trash. It never edits.

## Invariants

- **Tinycast is an `Alternate` handler, never the default by itself.** `Info.plist` claims its types
  with `LSHandlerRank` `Alternate`, so it appears under Open With and the user makes it the default
  (Get Info › Open With › Change All). Installing a build changes no one's default viewer.
- **`Info.plist` names types, never `public.data` or `public.content`**, which would offer Tinycast for
  archives and everything else it cannot show. `FileViewerTests` checks.
- **Every file URL Launch Services hands over is a file to show.** `AppCore.handleOpenURL` sends a file
  URL to `FileViewerCoordinator.open` before any deep-link routing, which is only safe while
  `Info.plist` claims nothing but viewable files.
- **`FileViewerKind` decides what draws a file.** An image is a photo; a PDF is WebKit's; RTF, HTML, CSV, a contact card
  and a calendar event are drawn by Quick Look; anything else whose bytes are UTF-8 is text, whatever
  its extension; the rest is Quick Look's. Text over 8 MB goes to Quick Look, which reads only as much
  as it draws.
- **The window fits the photo; the photo never upscales to fit the window.** `ImageViewerFitPolicy`
  scales a photo down to at most 90% of the visible frame and shows a smaller one at actual size,
  with a 320×220pt floor so an icon still gets a window. Actual size is points at the photo's own DPI,
  so a 144-DPI Retina screenshot is half its pixels, as in Preview.
- **A document's window takes the shape its kind usually has.** Quick Look reports no page size, so
  `FileViewerDocumentShape` picks: a tall page, a wider sheet, or a 16:9 slide. A PDF's first page
  picks for it.
- **PDFs draw in WebKit, not PDFKit.** A `PDFView` runs Vision's text recognition on every page inside
  Tinycast and keeps its models, 70–140 MB with no switch to turn it off; WebKit draws in a process that
  exits with the view. JavaScript is off, nothing persists, and a link opens in the browser.
- **A locked PDF gets every bare key but Esc.** WebKit asks for the password inside the page, so
  `takesTyping` has `FileViewerPanel` leave Space, `=` and `-` to it.
- **Decoding is off main and bounded by the display.** `ImageViewerPhoto` decodes with ImageIO, inside
  `FileViewerContent`'s `Task.detached`, applying EXIF orientation, at no more than twice the display's
  long edge in pixels. That keeps a 48 MP photo from costing ~190 MB; past a 2× zoom of a full-screen
  fit, it softens. Only a multi-frame GIF loads as an `NSImage` from the file, so `NSImageView` can
  animate it.
- **A still photo reaches its layer as an `IOSurface`, never a `CGImage`.** On macOS 27 the pixels of a
  `CGImage` a layer has shown are never freed, even once the layer, its window and the image are gone,
  which cost a whole decoded photo on every open.
- **Closing works as it does for the palette.** Esc, Space, ⌘W and losing key all close: a click on
  another app or the desktop takes key away. Everything goes through `FileViewerCoordinator.close()`,
  which drops the panel and, once it is off screen, closes the surface. `QLPreviewView` holds its
  decoder and web process until that call.
- **Move to Trash does not ask.** ⌘⌫ trashes the file off main and closes, as Finder and Preview do;
  the Trash is the undo. A failure is a `DialogController` notice, worded as Search Files words it.

## How it is put together

| Piece | Holds |
| --- | --- |
| `Model/FileViewerKind.swift` | photo, PDF, text or document, from the type and the bytes |
| `Model/FileViewerDocumentShape.swift` | the window size for a page, a sheet or slides |
| `Model/ImageViewerFitPolicy.swift` | a photo's window size, point size, zoom steps, decode size |
| `Service/FileViewerContent.swift` | the off-main read that makes a file ready to show |
| `Service/ImageViewerPhoto.swift` | the ImageIO decode and its point size |
| `UI/FileViewerCoordinator.swift` | one panel at a time, the stale-load check, Open in, Move to Trash |
| `UI/FileViewerPanel.swift` | the borderless key panel: the chords and close-on-resign-key |
| `UI/FileViewerSurface.swift` | what the panel hosts, and what its zoom chords do to it |
| `UI/ImageViewerCanvas.swift` | photos: the magnifying `NSScrollView`, double-click, drag to pan |
| `UI/FileViewerPDFSurface.swift` | PDFs: a `WKWebView` at the window's width |
| `UI/FileViewerTextSurface.swift` | text and source: a selectable text view whose zoom is its type size |
| `UI/FileViewerDocumentSurface.swift` | everything else: `QLPreviewView`, widened and zoomed |
| `UI/FileViewerView.swift` | the palette's glass behind the surface |

⌘+ and ⌘− (and a bare `=` and `-`) zoom by 1.25× steps, ⌘0 is actual size, ⌘9 is the fit. On a photo
a double-click toggles between the fit and actual size; at the fit, a drag moves the window; once
zoomed, it pans. On a document ⌘0 and ⌘9 are both the fit.

⌘O closes the viewer and opens a PDF in the default browser, and anything else in the first other app
that can, which is how a document Tinycast is the default for gets edited. Any build of Tinycast with
this bundle identifier is skipped.

### Quick Look's views

`QLPreviewView` has no zoom or load API, so `FileViewerDocumentSurface` reaches the public view inside:

| Files | Quick Look draws | Zoom |
| --- | --- | --- |
| Word, Excel, CSV, HTML | a `WKWebView` in process | `pageZoom` |
| RTF, RTFD, ODT | an `NSTextView` in a scroll view | magnification, with the width narrowed so lines rewrap |
| PowerPoint | a remote PDF view | none; the arrow keys and scrolling turn the slides |
| Pages, Numbers, Keynote | the preview saved in the file | none |

A Word page sits in a 625pt column with fixed edges, so a zoom would only clip. `widen` replaces the
column's constraints with ones to the window's edges and starts at the zoom that fills it.

OpenDocument sheets and slides and EPUB draw as an icon, so `Info.plist` does not claim them.

A second file opened while one is up replaces it in the same panel. A load still running when another
starts, or when the viewer closes, is cancelled and never presented.

Search Files reaches the viewer without any code of its own: opening a file there goes through
`NSWorkspace`, which hands it back to Tinycast once Tinycast is the default for that type.
