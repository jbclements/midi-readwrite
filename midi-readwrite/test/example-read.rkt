#lang racket

(require "../main.rkt"
         racket/runtime-path
         rackunit)

;; boy, these tests are pathetic....

(define-runtime-path contrib-file
  "../contrib/lmfao-party_rock_anthem.mid")

(define-runtime-path bach-file
  "../contrib/bwv772.mid")

(define parsed (midi-file-parse 
                (build-path contrib-file)))

;; regression tests...
(check-equal? (MIDIFile-format parsed) 'multi)
(check-equal? (MIDIFile-division parsed)
              (TicksPerQuarter 120))
(check-equal? (length (second (MIDIFile-tracks parsed)))
              2379)

(check-equal? (length (MIDIFile->notelist parsed))
              5506)
(check-equal? (length (MIDIFile->notelist (midi-file-parse
                                           bach-file)))
              474)

;; test for midi events being correctly assigned channel numbers in the full range 0 to 15
(check-equal? (ChannelMessage-channel (cadr (list-ref (list-ref (MIDIFile-tracks parsed) 14) 1))) 9)