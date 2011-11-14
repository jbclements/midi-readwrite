#lang setup/infotab

(define name "MIDI")

(define blurb '((p "This package provides a function "
                   "that can parse MIDI files written "
                   "in the standard MIDI format, SMF "
                   "(also known as .mid).")))

(define scribblings '(("midi.scrbl" () (parsing-library))))
(define categories '(media))
(define version "2011-11-14 12:49")
(define release-notes '((p "initial release")))

;; don't compile the stuff in the contrib subdirectory.
(define compile-omit-paths '("contrib"))

;; planet-specific:
(define repositories '("4.x"))
(define primary-file "main.rkt")

#;(define homepage "http://schematics.sourceforge.net/")
#;(define url "http://schematics.sourceforge.net/")

