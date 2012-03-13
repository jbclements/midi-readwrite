#lang racket

(require "../main.rkt"
         racket/runtime-path
         rackunit)

(define-runtime-path contrib-file
  "../contrib/lmfao-party_rock_anthem.mid")

(define parsed (midi-file-parse 
                (build-path contrib-file)))

;; regression tests...
(check-equal? (MIDIFile-format parsed) 'multi)
(check-equal? (MIDIFile-division parsed)
              (TicksPerQuarter 120))
(check-equal? (length (second (MIDIFile-tracks parsed)))
              2379)

