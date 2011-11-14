#lang racket

(require "../main.rkt"
         racket/runtime-path
         rackunit)

(define-runtime-path contrib-file
  "../contrib/lmfao-party_rock_anthem.mid")

(define parsed (midi-file-parse 
                (build-path contrib-file)))

;; regression tests...
(check-equal? (first parsed) 'multi)
(check-equal? (second parsed)
              '(ticks-per-quarter 120))
(check-equal? (length (second (third parsed)))
              2379)

