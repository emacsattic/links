;;; links.el --- links browser integration for GNU Emacs

;; $Id: links.el,v 1.3 2003/12/13 04:51:03 burton Exp $

;; Copyright (C) 2000-2003 Free Software Foundation, Inc.
;; Copyright (C) 2000-2003 Kevin A. Burton (burton@openprivacy.org)

;; Author: Kevin A. Burton (burton@openprivacy.org)
;; Maintainer: Kevin A. Burton (burton@openprivacy.org)
;; Location: http://relativity.yi.org
;; Keywords: 
;; Version: 1.0.0

;; This file is [not yet] part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify it under
;; the terms of the GNU General Public License as published by the Free Software
;; Foundation; either version 2 of the License, or any later version.
;;
;; This program is distributed in the hope that it will be useful, but WITHOUT
;; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
;; FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
;; details.
;;
;; You should have received a copy of the GNU General Public License along with
;; this program; if not, write to the Free Software Foundation, Inc., 59 Temple
;; Place - Suite 330, Boston, MA 02111-1307, USA.

;;; Commentary:

;; NOTE: If you enjoy this software, please consider a donation to the EFF
;; (http://www.eff.org)

;; This package provides integration for the 'links' browser with Emacs
;; (http://links.sourceforge.net).  Links is a great browser, much better than
;; 'lynx' (IMO).  It supports frames and tables which are basically a
;; requirement now that HTML 4.0 is pretty much everywhere..
;;
;; The integration here is important especially when compared to W3.  W3 has
;; performance problems when rendering tables and frames.  links.el and links
;; does not have this problem and in fact is blazingly fast.
;;
;; links.el supports the following features.
;;
;; - uses customization for all important variables.
;;
;; - links-browse-url supports two types of behavior
;;
;;   - browse within xterm
;;   -  browse within buffer
;;
;; - support for launching links within an xterm.  This can be done with
;;
;; - specify geomoetry, width and height,  for the xterm
;;
;; - supports 'dump' integration so that we can save to a *links* buffer
;; directly within emacs.
;;
;; - ability to jump from the links buffer to a links xterm.

;;; History:
;;
;; - Thu Jan 17 2002 03:12 PM (burton@openprivacy.org): ability to "view source"
;; (I can probably steal this from lynx.el)
;;
;; Wed Jan 16 2002 05:16 PM (burton@openprivacy.org): C-c C-x is now bound to
;; links-browse-buffer-url-within-xterm
;;
;; Wed Jan 16 2002 05:13 PM (burton@openprivacy.org): Now using a `links-mode'
;; so that we can bind keys.  This is just a derivitive of `text-mode'.

;;; TODO:
;;
;; - reload (links-reload-buffer)... should only work within links-mode
;;
;; - ability to support running links within a Emacs based TERM.  This would
;; have the benefits of being internal to Emacs but would be slightly slower.
;;
;;   - support plugable terminal emulators (term)
;;;;
;; Links browse type comparison
;;
;;                               +----------------+-------------------------+-----------------+
;;                               |  within xterm  |  within emacs 'term'    |  within buffer  |
;; +-----------------------------+----------------+-------------------------+-----------------+
;; | Speed                       |     FAST       | SLOW (due to rendering) |      FAST       |
;; +-----------------------------+----------------+-------------------------+-----------------+
;; | Interactive                 |     yes        |         yes             |       no        |
;; +-----------------------------+----------------+-------------------------+-----------------+
;; | 'View Source' within Emacs  |     no         |         no              |       yes       |
;; +-----------------------------+----------------+-------------------------+-----------------+
;; | copy/paste within Emacs     |     no         |         no              |       yes       |
;; +-----------------------------+----------------+-------------------------+-----------------+

;;; Code:

(defcustom links-browse-type (list "within xterm")
  "Type of browsing metaphor.  Within an xterm or within a buffer."
  :group 'links
  :type '(list
          (radio-button-choice
           (item "within xterm")
           (item "within buffer"))))

(defcustom links-xterm-geom "100x60+0+0" "Width of launch xterms."
  :group 'links
  :type 'string)

(defvar links-browse-buffer-name "*links*"
  "Buffer name used for browsing links within a buffer.")

(defvar links-browse-source-buffer-name "*links-source*"
  "Buffer name used for browsing links source within a buffer.")

(defvar links-browse-buffer-url nil "Used to store the URL for the currently visited links URL.")
(make-variable-buffer-local 'links-browse-buffer-url)

(defcustom links-command-name "links" "Command to invoke links."
  :type 'string
  :group 'links)

(defun links-browse-url(url)
  "Browse the given URL within the 'links' browser."
  (interactive
   (list
    (read-string "URL: ")))

  (let((type (nth 0 links-browse-type)))

    (if (string-equal type "within xterm")
        (links-browse-url-within-xterm url)
      (if (string-equal type "within buffer")
          (links-browse-url-within-buffer url)
        (error "Unable to handle browse type: %s" type)))))

(defun links-browse-url-within-xterm(url)
  "Browse the given URL within the 'links' browser under a dedicated xterm."
  (interactive
   (list
    (read-string "URL: ")))

  (start-process links-command-name nil "xterm" "-geom" links-xterm-geom "-e" links-command-name url))

(defun links-browse-url-within-buffer(url &optional buffer-name view-source)
  "Browse the given URL within the 'links' browser under a dedicated Emacs
buffer.  Note that in a lot of situations this may not be ideal.  For HTML
documents that use frames or large tables the output may be distorted within an
Emacs buffer.  It is also not possible to 'browse' within the buffer - you can
not jump to any new links.

The following parameters are accepted:

- `buffer-name'  If non-nil, the buffer name to display the result in.

- `view-source' If non-nil, the source will be displayed instead of the rendered
  output.
"
  (interactive
   (list
    (read-string "URL: ")))

  (when (null buffer-name)
    (setq buffer-name links-browse-buffer-name))
  
  (let(buffer)

    (setq buffer (get-buffer-create buffer-name))

    (save-excursion

      (set-buffer buffer)

      (erase-buffer))

    ;;needs to be a synchronous process so that the output doesn't scroll
    (if view-source 
        (call-process links-command-name nil buffer nil "-source" url)
      (call-process links-command-name nil buffer nil "-dump" url))

    (show-buffer (selected-window) buffer)

    (set-window-point (selected-window) (point-min))

    ;;final buffer setup
    (save-excursion

      (set-buffer buffer)

      (links-mode)
      
      ;;keep this here so that it can be buffer local.
      (setq links-browse-buffer-url url)

      (links-header-line-format url))))

(defun links-header-line-format(url)
  "Create a `header-line-format' which can display the URL."

  (let((url-title "URL: "))
       
    (put-text-property 0 4 'face 'bold url-title)
      
    (setq header-line-format (concat url-title
                                     url))))

(defun links-browse-buffer-url-within-xterm()
  "Browse the links buffer URL within an xterm.  This is very handy because once
  in an xterm we can link to other documents, use history, goto other sites,
  etc."
  (interactive)

  (assert (equal major-mode 'links-mode)
          nil "Not within links-mode.")

  (if links-browse-buffer-url
      (links-browse-url-within-xterm links-browse-buffer-url)
    (error "No buffer URL to browse")))

(defun links-browse-buffer-view-source()
  "Browse the links buffer URL within an xterm.  This is very handy because once
  in an xterm we can link to other documents, use history, goto other sites,
  etc."
  (interactive)

  (assert (equal major-mode 'links-mode)
          nil "Not within links-mode.")

  (links-browse-url-within-buffer links-browse-buffer-url links-browse-source-buffer-name t)

  ;;the source buffer should ALWAYS be HTML.

  (save-excursion

    (set-buffer links-browse-source-buffer-name)
    
    (html-mode)))

(defun browse-url-links(url &optional new-window)
  "`browse-url' compatible version of links-browse-url"
  (interactive
   (list
    (read-string "URL: ")))

  (links-browse-url url))

(define-derived-mode links-mode text-mode "Links" "Major mode for viewing links buffers.")

(define-key links-mode-map [?\C-c?\C-x] 'links-browse-buffer-url-within-xterm)
(define-key links-mode-map [?\C-c?\C-s] 'links-browse-buffer-view-source)

(provide 'links)

;;; links.el ends here